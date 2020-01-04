#!/bin/bash

source_address=bcex.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com
dest_address=bcex-backup.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com
source_passwd='cY6^$QXS3u#XF&uO'
dest_passwd='O7a02kjQnUBVQV8m'
source_table=order
dest_table=order
slave03=bcex-read-003.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com
slave04=bcex-read-004.cnhbjn4dkymy.ap-northeast-2.rds.amazonaws.com

updated_data=`date +"%Y-%m-%d 00:00:00" -d '30 days ago'`

echo "${source_table}表归档开始！" >> archiver_history.log

for i in 105518 105517 782961 904968 782953 791989
do
start_time=`date "+%Y-%m-%d %H:%M:%S" -d "+8 hour"`

	pt-archiver --source h=${source_address},P=3306,u=root,p=${source_passwd},D=bcex,t=${source_table} --dest h=${dest_address},P=3306,u=root,p=${dest_passwd},D=bcex,t=${dest_table} --charset=UTF8  --where "  updated_at < '${updated_data}'  AND org_id = 10 AND user_id = ${i} AND status IN (0,3)"   --progress 1000 --limit 1000 --commit-each  --bulk-insert --bulk-delete --statistics --no-delete --max-lag=1 --check-slave-lag u=root,p=${source_passwd},h=${slave03},P=3306 --check-slave-lag u=root,p=${source_passwd},h=${slave04},P=3306 > archiver_order.log

	sleep 1

	pt-archiver --source h=${source_address},P=3306,u=root,p=${source_passwd},D=bcex,t=${source_table} --dest h=${dest_address},P=3306,u=root,p=${dest_passwd},D=bcex,t=${dest_table} --charset=UTF8  --where "  updated_at < '${updated_data}'  AND org_id = 10 AND user_id = ${i} AND status IN (0,3)"   --progress 1000 --limit 1000 --commit-each  --bulk-insert --bulk-delete --statistics --max-lag=1 --check-slave-lag u=root,p=${source_passwd},h=${slave03},P=3306 --check-slave-lag u=root,p=${source_passwd},h=${slave04},P=3306 >> archiver_order.log

end_time=`date "+%Y-%m-%d %H:%M:%S" -d "+8 hour"`

insert_num=`grep "INSERT" archiver_order.log | head -n1 |awk '{print $2}'`

delete_num=`grep "DELETE" archiver_order.log | tail -n1 |awk '{print $2}'`

echo -e  "${start_time}开始归档${source_table}表用户ID${i}数据！\n归档条件：updated_at小于${updated_data}.\n统计：备份数据为${insert_num}条,清除数据为${delete_num}条.\n${end_time}数据归档完成!\n " >> archiver_history.log

done

echo "${source_table}表归档完成！" >> archiver_history.log
