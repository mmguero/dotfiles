#!/bin/sh
BASE_URL=http://archive.org/details/
BASE_HEADER=something-$(date -u +%s)
ls $1/*.jpg
echo Making the bucket...
s3cmd mb s3://$BASE_HEADER
echo Sleeping...#sometimes it takes a moment to be processed on their end
sleep 20
echo Uploading files...
for file in `ls $1`
do
        s3cmd put $1/$file s3://$BASE_HEADER/$file
done
echo $BASE_URL$BASE_HEADER
