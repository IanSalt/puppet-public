#!/bin/bash

export JAVA_HOME=/usr/lib/jvm/jre
export EC2_HOME=/opt/aws/apitools/ec2
export PATH=/usr/local/sbin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/aws/bin:/root/bin
export HOME=/root

. /etc/build_custom_config

if [ $# -ne 2 ]
then
	echo "Error: Needs Site and DB Name as an argument"
	exit 1
else
	site=$1
	dbName=$2
fi

weekStamp=$(date '+%Y%V')
dayStamp=$(date '+%Y%V%u')
bucketRegion=eu-west-2
backupDir=/var/lib/siteBackups/${site}
mkdir -p ${backupDir}
dbBackup=${backupDir}/${dbName}.${dayStamp}.sql.gz
siteBackup=${backupDir}/${site}.${dayStamp}.gz
listedIncrementalFile=${backupDir}/${site}.${weekStamp}.snar

cd /var/www
date '+%Y%m%d %H:%M:%S Starting Site Backup'
tar -zc --listed-incremental=${listedIncrementalFile} -f ${siteBackup} ${site}
if [ $? -ne 0 ]
then
    date '+%Y%m%d %H:%M:%S Site Backup Failed'
    exit 1
fi

date '+%Y%m%d %H:%M:%S Starting DB Backup'
mysqldump ${dbName} | gzip -c > ${dbBackup}
if [ $? -ne 0 ]
then
    date '+%Y%m%d %H:%M:%S DB Backup Failed'
    exit 1
fi

date '+%Y%m%d %H:%M:%S Starting AWS Sync'
aws --region ${bucketRegion} s3 sync ${backupDir} s3://mys3bucket.backups/wordpress/${ENVIRONMENT}/${site}/ >/dev/null 2>&1
if [ $? -ne 0 ]
then
    date '+%Y%m%d %H:%M:%S Transfer to AWS Failed'
    exit 1
else
    date '+%Y%m%d %H:%M:%S Finished Backups'
fi
echo -e "\n\n"

