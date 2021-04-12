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
    echo "Waiting for "$DB_CONTAINER_NAME" database connection..."
    sleep 4
done

echo "set mysql config ..."
echo "
bind-address	= 0.0.0.0" >> $MYSQL_D_CONFIG_FILE_PATH

echo "
server-id=2" >> $MYSQL_CONFIG_FILE_PATH

echo "restart docker container..."
docker container restart $DB_CONTAINER_NAME
sleep 5

echo "define master variables for slave and restart..."
start_slave_stmt="stop slave;CHANGE MASTER TO MASTER_HOST='"$IP"',MASTER_PORT="$PORT",MASTER_USER='"$REPLICATE_USER"',MASTER_PASSWORD='"$REPLICATE_USER_PASS"',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
start_slave_cmd='export MYSQL_PWD='$ROOT_PASS'; mysql -u root -e "'
start_slave_cmd+="$start_slave_stmt"
start_slave_cmd+='"'
docker exec $DB_CONTAINER_NAME sh -c "$start_slave_cmd"

echo "get slave status"
docker exec $DB_CONTAINER_NAME sh -c "export MYSQL_PWD='$ROOT_PASS'; mysql -u root -e 'SHOW SLAVE STATUS \G'"

echo "Done."