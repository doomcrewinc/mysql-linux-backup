#!/bin/bash

################################################################
##
##   MySQL Dump, Compress, Ship to S3
##   Written By: doomcrewinc
##   Last Update: 23 Sept, 2023
##
################################################################

export PATH=/bin:/usr/bin:/usr/local/bin
TODAY=$(date +"%d%b%Y")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BACKUP=${DATABASE_NAME}-${ENVIRONMENT}-${NOW}.sql.gz
################################################################
################## Update below values  ########################

DB_BACKUP_PATH='/backup/dbbackup'
BACKUP_RETAIN_DAYS=30   ## Number of days to keep local backup copy

#################################################################

mkdir -p ${DB_BACKUP_PATH}/${TODAY}/
echo "Backup started for database - ${DATABASE_NAME}"
## dump the database, then highly compress it in a parallel fashion
case $ENVIRONMENT in
    prod)
        mysqldump -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${DATABASE_NAME} | pigz > ${DB_BACKUP_PATH}/${TODAY}/${DATABASE_NAME}-${ENVIRONMENT}-${NOW}.sql.gz
        mysqldump -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${DATABASE_NAME} > /tmp/prod-latest.sql
        aws s3 cp ${DB_BACKUP_PATH}/${TODAY}/${DATABASE_NAME}-${ENVIRONMENT}-${NOW}.sql.gz s3://${SQL_BACKUP_BUCKET}/${ENVIRONMENT}/ -sse AES256
        aws s3api put-object-tagging --bucket ${SQL_BACKUP_BUCKET} --key $BACKUP --tagging '{"TagSet": [{ "Key": "ENVIRONMENT", "Value": "${ENVIRONMENT}" }, { "Key": "DATE", "Value": "${NOW}" }]}'
        ;;
    *)
        mysqldump -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${DATABASE_NAME} | pigz > ${DB_BACKUP_PATH}/${TODAY}/${DATABASE_NAME}-${ENVIRONMENT}-${NOW}.sql.gz
        aws s3 cp ${DB_BACKUP_PATH}/${TODAY}/${DATABASE_NAME}-${ENVIRONMENT}-${NOW}.sql.gz s3://${SQL_BACKUP_BUCKET}/${ENVIRONMENT}/ -sse AES256
        aws s3api put-object-tagging --bucket ${SQL_BACKUP_BUCKET} --key $BACKUP --tagging '{"TagSet": [{ "Key": "ENVIRONMENT", "Value": "${ENVIRONMENT}" }, { "Key": "DATE", "Value": "${NOW}" }]}'
        mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${ONDECK-DATABASE_NAME} < /tmp/prod-latest.sql
        ;;
esac

if [ $? -eq 0 ]; then
  echo "Database backup successfully completed"
else
  echo "Error found during backup"
fi


##### Remove backups older than {BACKUP_RETAIN_DAYS} days  #####

DBDELDATE=$(date +"%Y-%m-%dT%H:%M:%SZ" --date="${BACKUP_RETAIN_DAYS} days ago")

if [ ! -z ${DB_BACKUP_PATH} ]; then
      cd ${DB_BACKUP_PATH} || exit
      if [ ! -z ${DBDELDATE} ] && [ -d ${DBDELDATE} ]; then
            rm -rf ${DBDELDATE}
      fi
fi

### End of script ####