#!/bin/bash

SOURCE_ADDRESS=bcex.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com
DEST_ADDRESS=bcex-backup.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com
SOURCE_PASSWD='cY6^$QXS3u#XF&uO'
DEST_PASSWD='O7a02kjQnUBVQV8m'
SOURCE_TABLE=asset_user_locked
DEST_TABLE=asset_user_locked
SLAVE03=bcex-read-003.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com
SLAVE04=bcex-read-004.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com

DAY_TIME=`date +"%F"`

CREATED_DATA=`date +"%Y-%m-%d 00:00:00" -d '30 days ago'`

CREATED_ID=`mysql -u root -p${SOURCE_PASSWD} -h${SOURCE_ADDRESS} bcex -e "SELECT id FROM ${SOURCE_TABLE} WHERE created_at < '${CREATED_DATA}' ORDER BY id DESC LIMIT 1"`

CREATED_ID=`echo $CREATED_ID | gawk '{print $2}'`


MYSQL_S_CMD="h=${SOURCE_ADDRESS},P=3306,u=root,p=${SOURCE_PASSWD},D=bcex,t=${SOURCE_TABLE}"
MYSQL_D_CMD="h=${DEST_ADDRESS},P=3306,u=root,p=${DEST_PASSWD},D=bcex,t=${DEST_TABLE}"

# 日志目录

LOG_PATH="./logs"
if [ ! -d ${LOG_PATH} ];then
    mkdir ${LOG_PATH} -p
fi

LOG_FILE="${LOG_PATH}/archiver_user_locked_${DAY_TIME}.log"

LOCK_LOG="${LOG_PATH}/archiver_user_locked_history.log"

# pt-archiver路径

PTAR="/usr/bin/pt-archiver"


START_TIME=`date "+%Y-%m-%d %H:%M:%S" -d "+8 hour"`

${PTAR} --source ${MYSQL_S_CMD} --dest ${MYSQL_D_CMD} --no-check-charset --where "balance = 0 AND id < ${CREATED_ID}" --progress 100000 --limit=1000 --commit-each --bulk-insert --bulk-delete --statistics --no-delete --max-lag=1 --check-slave-lag u=root,p=${SOURCE_PASSWD},h=${SLAVE03},P=3306 --check-slave-lag u=root,p=${SOURCE_PASSWD},h=${SLAVE04},P=3306  > ${LOG_FILE}


${PTAR} --source ${MYSQL_S_CMD} --dest ${MYSQL_D_CMD} --no-check-charset --where "balance = 0 AND  id < ${CREATED_ID}"  --progress 100000 --limit 1000 --commit-each --bulk-insert --bulk-delete --statistics --max-lag=1 --check-slave-lag u=root,p=${SOURCE_PASSWD},h=${SLAVE03},P=3306 --check-slave-lag u=root,p=${SOURCE_PASSWD},h=${SLAVE04},P=3306 >> ${LOG_FILE}

END_TIME=`date "+%Y-%m-%d %H:%M:%S" -d "+8 hour"`

INSERT_NUM=`grep "INSERT" ${LOG_FILE} | head -n1 |awk '{print $2}'`

DELETE_NUM=`grep "DELETE" ${LOG_FILE} | tail -n1 |awk '{print $2}'`

echo -e  "${START_TIME}开始归档${SOURCE_TABLE}表数据！\n归档条件：created_at小于${CREATED_DATA}.\n统计：备份数据为${INSERT_NUM}条,清除数据为${DELETE_NUM}条.\n${END_TIME}数据归档完成!\n " >> ${LOCK_LOG}