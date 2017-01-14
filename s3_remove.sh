#!/bin/bash

# Usage: ./deleteOld "bucketname" "30 days"

lessdate="60 days"
for i in $(s3cmd ls s3:// | awk {'print $3'});
do
s3cmd ls $i | while read -r line;
  do
    createDate=`echo $line|awk {'print $1" "$2'}`
    createDate=`date -d"$createDate" +%s`
    olderThan=`date -d"-$lessdate" +%s`
    if [[ $createDate -lt $olderThan ]]
      then
        fileName=`echo $line|awk {'print $4'}`
        echo $fileName
        if [[ $fileName != "" ]]
          then
            s3cmd del "$fileName"
        fi
    fi
  done;
done;