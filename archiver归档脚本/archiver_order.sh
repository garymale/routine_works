#!/bin/bash
MYSQL_S_HOST=bcex.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com
MYSQL_D_HOST=bcex.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com
MYSQL_S_PASSWD='cY6^$QXS3u#XF&uO'
MYSQL_D_PASSWD='cY6^$QXS3u#XF&uO'
SOURCE_TAB=order
#dest_table=order
SLAVE03=bcex-read-003.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com
SLAVE04=bcex-read-004.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com

LAST_DAY=30
UP_DATA=`date +"%Y-%m-%d 00:00:00" -d "${LAST_DAY} days ago"`

API_LAST_DAY=1
API_UP_DATA=`date +"%Y-%m-%d 00:00:00" -d "${API_LAST_DAY} days ago"`
# pt-archiver路径

PTAR="/usr/bin/pt-archiver"

#--commit-each：控制事务大小，每次提取、归档就提交。禁用--txn-size
#--ignore：insert语句加入ignore
#--dry-run：打印查询并退出而不做任何事情
#--[no]version-check：不检查版本号
#--[no]check-charset：不检查字符集
#--[no]check-columns：不检查列顺序，数据类型等
#--low-priority-delete：每个delete语句加入LOW_PRIORITY
#--low-priority-insert：每隔insert和replace语句加入LOW_PRIORITY
#--no-delete：不要删除存档的行，默认会删除

SLAVE_LAG_01="u=root,p=${MYSQL_S_PASSWD},h=${SLAVE03},P=3306"
SLAVE_LAG_02="u=root,p=${MYSQL_S_PASSWD},h=${SLAVE04},P=3306"

DAY_TIME=`date +"%F"`


# 日志目录
LOG_PATH="./logs"
if [ ! -d ${LOG_PATH} ];then
    mkdir ${LOG_PATH} -p
fi

LOG_FILE="${LOG_PATH}/archiver_order_${DAY_TIME}.log"
API_LOG_FILE="${LOG_PATH}/api_archiver_order_${DAY_TIME}.log"

COUNT_LOG="${LOG_PATH}/archiver_order_history.log"

#所有用户归档30天前订单；

function ALL_END_ORDER() {
echo "#################################所有用户${LAST_DAY}天前订单开始归档#################################" | tee -a ${COUNT_LOG}
for((i=0;i<32;i++));
do
    NOW_TIME=`date +"%F %T"`

    DEST_TAB=order_history_${i}

    MYSQL_S_CMD="h=${MYSQL_S_HOST},P=3306,u=root,p=${MYSQL_S_PASSWD},D=bcex,t=${SOURCE_TAB}"
    MYSQL_D_CMD="h=${MYSQL_D_HOST},P=3306,u=root,p=${MYSQL_D_PASSWD},D=bcex,t=${DEST_TAB}"

    #SQL_CMD= " updated_at < ${UP_DATA} AND org_id = 10 AND user_id MOD 32 = ${i} AND status IN (0,3) "

    ${PTAR} --source ${MYSQL_S_CMD} --dest ${MYSQL_D_CMD} --no-check-charset --no-check-columns --no-version-check \
            --where " updated_at < '${UP_DATA}' AND org_id = 10 AND user_id MOD 32 = ${i} AND status IN (0,3) " --progress 100000 --limit 1000 --commit-each  \
            --bulk-insert --ignore --low-priority-insert --bulk-delete --statistics --no-delete --max-lag=1  \
            --check-slave-lag ${SLAVE_LAG_01} --check-slave-lag ${SLAVE_LAG_02} --why-quit | tee -a ${LOG_FILE}

    if [ $? -eq 0 ]; then

    INSERT_COUNT=`grep "INSERT" ${LOG_FILE} | tail -n1 |awk '{print $2}'`

    COUNT=`expr ${INSERT_COUNT} + 0`

    echo -e "[${NOW_TIME}] [INFO] ${SOURCE_TAB}表的 updated_at < ${UP_DATA}的数据导入${DEST_TAB}表${COUNT}条！" | tee -a ${COUNT_LOG}


    fi

done

echo "#################################所有用户${LAST_DAY}天前订单本次归档完成#################################" | tee -a ${COUNT_LOG}

}

#API用户归档1天前订单
function API_END_ORDER() {

echo "#################################API用户${API_LAST_DAY}天前订单开始归档#################################" | tee -a ${COUNT_LOG}

for((i=0;i<32;i++));
do
    NOW_TIME=`date +"%F %T"`

    DEST_TAB=order_history_${i}

    MYSQL_S_CMD="h=${MYSQL_S_HOST},P=3306,u=root,p=${MYSQL_S_PASSWD},D=bcex,t=${SOURCE_TAB}"
    MYSQL_D_CMD="h=${MYSQL_D_HOST},P=3306,u=root,p=${MYSQL_D_PASSWD},D=bcex,t=${DEST_TAB}"

    USER_ID=`mysql -uroot -p${MYSQL_S_PASSWD} -h${MYSQL_S_HOST} bcex -N -e " SELECT GROUP_CONCAT(DISTINCT user_id) FROM api_market_apply WHERE status = 1 AND user_id MOD 32 = ${i}"`

    ${PTAR} --source ${MYSQL_S_CMD} --dest ${MYSQL_D_CMD} --no-check-charset --no-check-columns --no-version-check \
            --where " updated_at < '${API_UP_DATA}' AND org_id = 10 AND user_id IN ( ${USER_ID} ) AND status IN (0,3) " --progress 100000 --limit 1000 --commit-each  \
            --bulk-insert --ignore --low-priority-insert --bulk-delete --statistics --no-delete --max-lag=1  \
            --check-slave-lag ${SLAVE_LAG_01} --check-slave-lag ${SLAVE_LAG_02} --why-quit | tee -a ${API_LOG_FILE}


    if [ $? -eq 0 ]; then

    INSERT_COUNT=`grep "INSERT" ${API_LOG_FILE} | tail -n1 |awk '{print $2}'`

    COUNT=`expr ${INSERT_COUNT} + 0`

    echo -e "[${NOW_TIME}] [INFO] ${SOURCE_TAB}表API用户updated_at < ${API_UP_DATA}的数据导入${DEST_TAB}表${COUNT}条！" | tee -a ${COUNT_LOG}

    fi
done

echo "#################################API用户${API_LAST_DAY}天前订单归档完成#################################" | tee -a ${COUNT_LOG}

}

ALL_END_ORDER

API_END_ORDER