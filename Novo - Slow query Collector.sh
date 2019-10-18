 #!/bin/bash


set -x

query_path="/home/mydbops/slow_queries/sub"
path="/home/mydbops/slow_queries"
#receiver="ponsuresh@mydbops.com"
receiver="devops@novopay.in,dba-group@mydbops.com"
mail_user="mydbops"
mail_host="172.20.2.194"
mail_path="/usr/sbin/sendmail"
mail_user="mydbops"
pt_path=$(which pt-query-digest)


da=$(date +%Y-%m-%d)
dat=$(date +%Y%m%d)
prev=`date -d '-1 day' '+%Y%m%d'`
#log_path=/data/log/mysql-slow.log-$dat
log_path=/data/log/mysql-slow.log-$prev

echo "FROM: 'Slow_Queries' <slowqueries@mydbops.com>" > /tmp/data.html
echo "TO: $receiver"  >> /tmp/data.html
echo "SUBJECT: Slow_Queries for Novopay AWS DB-3 at $da" >> /tmp/data.html
echo "Content-type: text/html" >> /tmp/data.html
echo "<html><body>" >> /tmp/data.html
echo  "Hi Team,<br><br> Slow_Queries for Novopay <font color='green'> DB-1 </font>.<br><br>Kindly verify it.<br><br><br>">>  /tmp/data.html

#cat $con | grep shard | awk '{ print $2 }' > $sub_path/client.txt
client_list="db1"


for client in $client_list
do

#echo "<br><font color='darkgreen'><b>Shard name</b> :</font color> $client<br>" >> /tmp/data.html
#echo "<br>" >> /tmp/data.html

rm -rf $path/*.txt

file=`which pt-query-digest`

#ssh $client "$file $log_path" > $sub_path/test.txt

$pt_path $log_path > $query_path/test.txt

cat $query_path/test.txt | grep Query | grep -v 'Query size' | grep -v 'Query_time distribution' | grep -v 'Rank Query ID' | awk '{print $2, $3}' | sed 's/://g' | awk '{print $2}' > $query_path/final.txt
cc=$(($(cat $query_path/final.txt | wc -l)-1))
u=$(cat $query_path/final.txt | head -n $cc)
l=$(cat $query_path/final.txt | tail -n $cc)
for (( k=1; k<=$cc; k++ ))
do 
i=$(echo "$u" | head -n$k | tail -n1)
j=$(echo "$l" | head -n$k | tail -n1)
echo "/Query $i:/,/Query $j:/" > $path/file_new.txt
cmd=`cat $path/file_new.txt`

awk "$cmd" $query_path/test.txt  > $path/final.txt

 
less $path/final.txt | egrep "# Databases" | awk '{print $3,$4,$5,$6,$7,$8}' >> $path/database.txt
db_name=$(less $path/final.txt | egrep "# Databases" | awk '{print $3,$4,$5,$6,$7,$8}')

less $path/final.txt | egrep "# Count" | awk '{print $4}' >> $path/count.txt
count_num=$(less $path/final.txt | egrep "# Count" | awk '{print $4}')

less $path/final.txt | egrep "# Exec time" | awk '{print $9}' >> $path/exe_time.txt
exe_time_count=$(less $path/final.txt | egrep "# Exec time" | awk '{print $9}')

less $path/final.txt | egrep "# Avg time" | awk '{print $8}' >> $path/avg_time.txt
avg_time_count=$(less $path/final.txt | egrep "# Exec time" | awk '{print $8}')

less $path/final.txt | egrep "# Rows examine" | awk '{print $7}' >> $path/rows_examine.txt
rows_ex_count=$(less $path/final.txt | egrep "# Rows examine" | awk '{print $7}')

less $path/final.txt | egrep "# Rows sent" | awk '{print $7}' >> $path/rows_sent.txt
rows_sent_count=$(less $path/final.txt | egrep "# Rows sent" | awk '{print $7}')

egrep -i 'select|insert|update|DELETE|Commit|Quit|BEGIN|mysql-connector|SET|SHOW COLLATION|SHOW WARNINGS|SHOW GLOBAL STATUS|SHOW VARIABLES LIKE' $path/final.txt > $path/query_123.txt
qry=$(less $path/query_123.txt)



echo "<font color='blue'><b>Database :</b></font color> $db_name <br>" >>  /tmp/data.html
echo "<font color='blue'><b>Count :</b></font color> $count_num <br>" >>  /tmp/data.html
echo "<font color='blue'><b>Exe_Time :</b></font color> $exe_time_count <br>" >>  /tmp/data.html
echo "<font color='blue'><b>Avg_Time :</b></font color> $avg_time_count <br>" >>  /tmp/data.html
echo "<font color='blue'><b>rows_examine :</b></font color> $rows_ex_count <br>" >>  /tmp/data.html
echo "<font color='blue'><b>rows_sent :</b></font color> $rows_sent_count <br>" >>  /tmp/data.html
echo "<font color='blue'><b>Query :</b></font color> $qry <br>" >> /tmp/data.html
echo "<br><br>" >>  /tmp/data.html

done


nu=$(cat $path/database.txt | wc -l)

done
cat /tmp/data.html | /usr/sbin/sendmail $receiver

#cat /tmp/data.html | ssh $mail_user@$mail_host "$mail_path $receiver"
