# replica set backup

set -eo pipefail

export GZIP=-9

mongo_path="/opt/mongobackup/"

date_b=$(date -u "+%F-%H%M%S")

file="backup-$date_b.tar.gz"

mongodump  --gzip --out $mongo_path/tmp/

tar -C $mongo_path/tmp/ -zcvf $mongo_path/tmp/$file $mongo_path/tmp/* --exclude="*.tar.gz"

find $mongo_path/tmp/* ! -name '*.tar.gz' -type d -exec rm -rf {} +

cd $mongo_path

mv tmp/backup* storage/

oldest_file=$(find $mongo_path/storage/ -type f | sort | head -n 1)

aws s3 cp $oldest_file s3://bitpoolmongobackup/awscluster/

cd $mongo_path/storage && ls -1t  | tail -n +4  | xargs rm -rf

find $mongo_path/tmp/ -type f -print -delete

#config server backup

sudo service mongod-configsrv stop

configdb_path="/data/bitpool-cluster_config_115"

date_b=$(date -u "+%F-%H%M%S")

file_c="backup-configdb-$date_b.tar.gz"

sudo -u mongodb tar cvzf /opt/mongobackup/$file_c $configdb_path

aws s3 cp /opt/mongobackup/$file_c s3://bitpoolmongobackup/awscluster/

sudo -u mongodb rm -rf  /opt/mongobackup/$file_c

sudo service mongod-configsrv start