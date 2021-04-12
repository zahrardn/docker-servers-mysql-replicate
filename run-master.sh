#!/bin/bash

source ./env

read  -p "Did you set env variables first?[yes/no]" CONTINUE

if [ $CONTINUE != 'yes' ] 
then
    echo "Set variables first..."
    exit 0
fi

echo "check db connection..."
until docker exec $DB_CONTAINER_NAME sh -c 'export MYSQL_PWD='$ROOT_PASS'; mysql -u root -e ";"'
do
    echo "Waiting for $DB_CONTAINER_NAME database connection..."
    sleep 4
done

cp $MYSQL_CONFIG_FILE_PATH $MYSQL_CONFIG_FILE_PATH"_master_bkp"
echo "set mysql config ..."
echo "
server-id=1
log_bin=mysql-bin
log_error=mysql-bin.err
binlog_do_db='$DB_NAME'
" >> $MYSQL_CONFIG_FILE_PATH

echo "restart docker container..."
    docker container restart $DB_CONTAINER_NAME
    sleep 5

echo "create replicate user with replicate grant..."
priv_stmt='GRANT REPLICATION SLAVE ON *.* TO "'$REPLICATE_USER'"@"%" IDENTIFIED BY "'$REPLICATE_USER_PASS'"; FLUSH PRIVILEGES;'
docker exec $DB_CONTAINER_NAME sh -c "export MYSQL_PWD="$ROOT_PASS"; mysql -u root -e '$priv_stmt'"

echo "get log and pos from output..."
MS_STATUS=`docker exec $DB_CONTAINER_NAME sh -c 'export MYSQL_PWD='$ROOT_PASS'; mysql -u root -e "SHOW MASTER STATUS"'`

CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`

if [ ! -z $CURRENT_LOG ]
then
    echo "
    CURRENT_LOG="$CURRENT_LOG >> "./env"
    echo "
    CURRENT_POS="$CURRENT_POS >> "./env"
    
    rm $MYSQL_CONFIG_FILE_PATH"_master_bkp"

else
    cp $MYSQL_CONFIG_FILE_PATH"_master_bkp" $MYSQL_CONFIG_FILE_PATH 
    rm $MYSQL_CONFIG_FILE_PATH"_master_bkp"
    echo "Error Occured..."
fi

echo "DONE."