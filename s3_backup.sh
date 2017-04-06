set -eo pipefail

export GZIP=-9

mongo_path="/opt/mongobackup/"

date_b=$(date -u "+%F-%H%M%S")

file="backup-$date_b.tar.gz"

aws_path="/awscluster/"

mongodump  --gzip --out $mongo_path/tmp/

tar -C $mongo_path/tmp/ -zcvf $mongo_path/tmp/$file $mongo_path/tmp/* --exclude="*.tar.gz"

find $mongo_path/tmp/* ! -name '*.tar.gz' -type d -exec rm -rf {} +

cd $mongo_path

mv tmp/backup* storage/

oldest_file=$(find $mongo_path/storage/ -type f | sort | head -n 1)

split -n 4 $oldest_file "$mongo_path/tmp/$file-part-"

acl="x-amz-acl:public-read"

content_type="application/x-compressed-tar"

for part in $(ls $mongo_path/tmp/ | grep "part")
do
        date=$(date +"%a, %d %b %Y %T %z")
        string="PUT\n\n$content_type\n$date\n$acl\n/$bucket$aws_path$part"
        signature=$(echo -en "${string}" | openssl sha1 -hmac "${AWS_SECRET_KEY}" -binary | base64)

	curl -X PUT -T "$mongo_path/tmp/$part" \
  	-H "Host: $bucket.s3.amazonaws.com" \
  	-H "Date: $date" \
  	-H "Content-Type: $content_type" \
  	-H $acl \
  	-H "Authorization: AWS ${AWS_ACCESS_KEY}:$signature" \
  	"https://$bucket.s3.amazonaws.com$aws_path$part"

  		if [ $(echo $?) < /dev/null ]; then
    		    echo SUCCESS
  		else
    		    echo FAIL
    		    exit 1
    	      	fi
done

ls -1t $mongo_path/storage/  | tail -n +4  | xargs rm -rf
find $mongo_path/tmp/ -type f -print -delete