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

PTAR="/usr/bin/pt-archiver"

SLAVE_LAG_01="u=root,p=${MYSQL_S_PASSWD},h=${SLAVE03},P=3306"
SLAVE_LAG_02="u=root,p=${MYSQL_S_PASSWD},h=${SLAVE04},P=3306"


for((i=0;i<32;i++));
do
    NOW_TIME=`date +"%F %T"`

    DEST_TAB=order_history_${i}

    MYSQL_S_CMD="h=${MYSQL_S_HOST},P=3306,u=root,p=${MYSQL_S_PASSWD},D=bcex,t=${SOURCE_TAB}"
    MYSQL_D_CMD="h=${MYSQL_D_HOST},P=3306,u=root,p=${MYSQL_D_PASSWD},D=bcex,t=${DEST_TAB}"

    USER_ID=`mysql -uroot -p${MYSQL_S_PASSWD} -h${MYSQL_S_HOST} bcex -N -e " SELECT GROUP_CONCAT(DISTINCT user_id) FROM api_market_apply WHERE status = 1 AND user_id MOD 32 = ${i}"`

    ${PTAR} --source ${MYSQL_S_CMD} --dest ${MYSQL_D_CMD} --no-check-charset --no-check-columns --no-version-check \
            --where " updated_at < '${UP_DATA}' AND org_id = 10 AND user_id IN ( ${USER_ID} ) AND status IN (0,3) " --progress 100000 --limit 1000 --commit-each  \
            --bulk-insert --ignore --low-priority-insert --bulk-delete --statistics --no-delete --max-lag=1  \
            --check-slave-lag ${SLAVE_LAG_01} --check-slave-lag ${SLAVE_LAG_02} --why-quit --dry-run

done
