#!/bin/sh
#!/bin/bash

#Version : 2.2
#Purpose : Backup_script
#Author  : MyDBOPS

set -x
###################################################################################################################
                                                #Config Details
###################################################################################################################
echo "start at `date +'%d-%b-%Y %H:%M:%S'`"

#config_file=/path/to/config.txt
source "/etc/xtrabackup.conf"


  bdate=`date +'%d-%b-%Y'`
  type=`date +'%A'`
  bkday=`date +'%a'`
  date=`date +'%d-%b'`
  date1=`date +'%Wth-Week'`
  date2=`date +'%W'`
  year=`date +'%Y'`
  fold_date=`date +'%d-%b-%a'`
  chk_time=`date +'%a-%H:%M'`
  bktime=`date +'%d-%a-%H_%M'`

retn_back=`expr $retention_backups + 1`

echo "Started : `date +'%d-%b-%Y %H:%M:%S'`" > $date_list/back_details.txt
echo "Host : $host_ip" >> $date_list/back_details.txt
echo "Client : $client" >> $date_list/back_details.txt
echo "SSH_Config : hyperoffice_slave" >> $date_list/back_details.txt
echo "Back_Method : Hot" >> $date_list/back_details.txt


#Remove old files
rm -r $mail/*.txt
rm -r $mail/*.html
rm -r $sub/xtrabackup_slave_info
rm -r $sub/xtrabackup_info


###################################################################################################################
                                                #Backup of data
###################################################################################################################

#Backup of data

#if [[ "$type" == $back_day ]];
if [[ "$type" == $back_day && $chk_time == $back_time ]];
then
back_type="Full Backup"
echo "Backup_Type : Full" >> $date_list/back_details.txt
echo "Full backup"

#Check if folder exists
fld_prsnt=$(ls $backup_path | grep -w $date1 | head -n1)
if [[ $date1 == $fld_prsnt ]]; then
#folder exists so, move the folder
mv $backup_path/$fld_prsnt $backup_path/$fld_prsnt-$bktime
/bin/mkdir $backup_path/$date1
/bin/mkdir $backup_path/$date1/incremental
else
/bin/mkdir $backup_path/$date1
/bin/mkdir $backup_path/$date1/incremental
fi


drop=$(ls -lrth $backup_path | grep Week | awk '{print $9}' | wc -l)
if [[ $drop -ge $retn_back ]] ;
then
ls -lrth $backup_path/ | grep Week | awk '{print $9}' | head -n1 > $date_list/remove.txt
else
echo "No old files"
fi

# Backup database
#$xtra_path --user=$user --password=$password --defaults-file=$cnf --socket=$socket  --no-lock --compress --compress-threads=4  --slave-info --export $backup_path/$date1/full_backup-$fold_date  --no-timestamp 1>$logs/full_xtra.log 2>>$logs/full_xtra.err

#added for xtrabackup_history
$xtra_path --login-path=mydbops_backup  --compress --compress-threads=8  --history=$date1 --slave-info --export $backup_path/$date1/full_backup-$fold_date  --no-timestamp 1>$logs/full_xtra.log 2>$logs/full_xtra.err

echo "$backup_path/$date1" > $date_list/list.txt
echo "$backup_path/$date1/incremental" > $date_list/week_path.txt
echo "$backup_path/$date1/full_backup-$fold_date" > $date_list/week.txt

#added for xtrabackup_history
echo "$date1" > $date_list/inc_history.txt

#Get the status
back_status=$(cat $logs/full_xtra.err | tail -n1 | awk '{print $3}')
if [[ "$back_status" == completed ]]; then
echo "Backup_Status : Success" >> $date_list/back_details.txt
else
echo "Backup_Status : Failed" >> $date_list/back_details.txt
fi
#Get the backup size
du -sh $backup_path/$date1/full_backup-$fold_date > $sub/file_size.txt
backupsize=$(cat $sub/file_size.txt | awk '{print $1}')
echo "Backup_Size : $backupsize" >> $date_list/back_details.txt
#Get the backup file
backup_file=$(cat $sub/file_size.txt | awk '{print $2}')
echo "Backup_Path : $backup_file" >> $date_list/back_details.txt
echo "Error_log_path : $logs/full_xtra.err" >> $date_list/back_details.txt

#Get the binary log details
#Decompress slave info file
#/usr/bin/qpress -dT8 $backup_path/$date1/full_backup-$fold_date/xtrabackup_slave_info.qp $sub/xtrabackup_slave_info

/usr/bin/qpress -d $backup_path/$date1/full_backup-$fold_date/xtrabackup_info.qp $sub/

tail $logs/full_xtra.err | grep 'MySQL slave binlog position' > $sub/xtrabackup_slave_info

log_file=$(cat $sub/xtrabackup_slave_info | awk '{print $9}' | sed  "s/'//g" | sed 's/,//g')
log_pos=$(cat $sub/xtrabackup_slave_info | awk '{print $11}' | sed "s/'//g")

echo "Binlog_file : $log_file" >> $date_list/back_details.txt
echo "Binlog_pos : $log_pos" >> $date_list/back_details.txt

#drop=$(cat $sub/detail.txt | head -n1)

if [[ "$back_status" == completed ]];
then
echo "completed"
else
echo "remove the uncompleted backup"
rm -rf $backup_path/$date1
fi

#For incremental take lsn number
#cat $logs/full_xtra.err | tail -n15 | grep -w 'Transaction log' | awk '{print $6}' | sed 's/(//' | sed 's/)//' > $sub/lsn_no.txt
cat $backup_path/$date1/full_backup-$fold_date/xtrabackup_checkpoints | grep -w to_lsn | awk '{print $3}' > $sub_path/lsn_no.txt

#To get archived backups

        if [[ $drop -ge $retn_back ]] ;
        then
        remove_file=$(cat $date_list/remove.txt)
                du -sh $backup_path/$remove_file > $sub/old_file.txt
        arch_file=$(cat $sub/old_file.txt | awk '{print $2}')
        arch_size=$(cat $sub/old_file.txt | awk '{print $1}')
                                        if [[ "$back_status" == completed ]];
                                        then
										echo "Purge_Backup : $arch_file"  >> $date_list/back_details.txt
                                        rm -rf $backup_path/$remove_file
					 #to purge old track changed pages
					 track_lsn=$(cat $sub/lsn_no.txt)
					 $mysql_path --login-path=$back_user -e "purge changed_page_bitmaps before $track_lsn;"
                                        else
                                        echo "Backup not completed"
                                        fi
        else
        echo "No files to be archived"
        fi

else

back_type="Incremental Backup"
echo "Backup_Type : Incremental" >> $date_list/back_details.txt
echo "Incremental backup"


lsn_number=$(cat $sub/lsn_no.txt)
bk_path=$(cat $date_list/week_path.txt)
inc_hist_date=$(cat $date_list/inc_history.txt)

#Get the binary log details

# Backup database
#$xtra_path --user=$user --password=$password --defaults-file=$cnf --socket=$socket   --incremental --incremental-lsn=$lsn_number  $bk_path/inc_backup-$fold_date_$bktime --no-lock --compress --compress-threads=4 --slave-info --no-timestamp 1> $logs/inc_xtra.log 2>>$logs/inc_xtra.err

#$xtra_path --user=$user --password=$password --slave-info --history=inc_backup-$fold_date_$bktime --incremental-history-name=$inc_hist_date --incremental --incremental-lsn=$lsn_number  $bk_path/inc_backup-$fold_date_$bktime  --compress --compress-threads=4 --no-timestamp 1> $logs/inc_xtra.log 2>$logs/inc_xtra.err

$xtra_path --login-path=mydbops_backup  --slave-info --history=inc_backup-$fold_date_$bktime --incremental --incremental-lsn=$lsn_number  $bk_path/inc_backup-$fold_date_$bktime  --compress --compress-threads=4 --no-timestamp 1> $logs/inc_xtra.log 2>$logs/inc_xtra.err

#Get the status
back_status=$(cat $logs/inc_xtra.err | tail -n1 | awk '{print $3}')
if [[ "$back_status" == completed ]]; then
echo "Backup_Status : Success" >> $date_list/back_details.txt
else
echo "Backup_Status : Failed" >> $date_list/back_details.txt
fi
#Get the backup size
du -sh $bk_path/inc_backup-$fold_date_$bktime > $sub/file_size.txt
backupsize=$(cat $sub/file_size.txt | awk '{print $1}')
echo "Backup_Size : $backupsize" >> $date_list/back_details.txt
#Get the backup file
backup_file=$(cat $sub/file_size.txt | awk '{print $2}')
echo "Backup_Path : $backup_file" >> $date_list/back_details.txt
echo "Error_log_path : $logs/inc_xtra.err" >> $date_list/back_details.txt

#Get the binary log details
#Decompress slave info file
#/usr/bin/qpress -dT8 $bk_path/inc_backup-$fold_date_$bktime/xtrabackup_slave_info.qp $sub/xtrabackup_slave_info

/usr/bin/qpress -d $bk_path/inc_backup-$fold_date_$bktime/xtrabackup_info.qp $sub/

tail $logs/inc_xtra.err | grep 'MySQL slave binlog position' > $sub/xtrabackup_slave_info

log_file=$(cat $sub/xtrabackup_slave_info | awk '{print $9}' | sed  "s/'//g" | sed 's/,//g')
log_pos=$(cat $sub/xtrabackup_slave_info | awk '{print $11}' | sed "s/'//g")

echo "Binlog_file : $log_file" >> $date_list/back_details.txt
echo "Binlog_pos : $log_pos" >> $date_list/back_details.txt

if [[ "$back_status" == completed ]];
then
cat $bk_path/inc_backup-$fold_date_$bktime/xtrabackup_checkpoints | grep to_lsn | awk '{print $3}' > $sub/lsn_no.txt
lsn=$(cat $sub/lsn_no.txt)
echo $lsn
#cat $logs/inc_xtra.err | tail -n15 | grep -w 'Transaction log' | awk '{print $6}' | sed 's/(//' | sed 's/)//' > $sub/lsn_no.txt
else
rm -rf $bk_path/inc_backup-$fold_date_$bktime
fi

#To get available backups

#Available backups

du -sh $backup_path/*/full* > $mail/full_back.txt

echo "<tr><td nowrap='' colspan="2"><b><center>Full Backup</center></b></td></tr> " > $mail/avb_back.txt
cat $mail/full_back.txt | awk '{print $2 " - " $1}' | sed 's/.*/<tr><td>&<\/td><\/tr>/' | sed 's/ - /<\/td><td>/' >> $mail/avb_back.txt

echo "<tr><td nowrap='' colspan="2"><b><center>Incremental Backup</center></b></td></tr>" >> $mail/avb_back.txt

for  i in `ls -lth $bk_path/ | grep inc | sort -Mr | awk '{print $9}'`
do
du -sh $bk_path/$i >> $mail/back_order.txt
done

cat $mail/back_order.txt | awk '{print $2 " - " $1}' | sed 's/.*/<tr><td>&<\/td><\/tr>/' | sed 's/ - /<\/td><td>/' >> $mail/avb_back.txt
avb_inc_backup=$(cat $mail/avb_back.txt)

fi


###################################################################################################################

if [[ "$back_status" == completed ]];
then
status="Success"
color="green"
else
status="Failure"
color="red"
fi

###################################################################################################################
                                        #Sending mails
###################################################################################################################


if [[ "$back_status" == completed ]];
then
echo  "FROM: '$client Backup' <backup@$server>" >> $mail/table.html
echo  "TO: $receiver" >> $mail/table.html
echo  "SUBJECT: MySQL Hot Backup on $bdate ($server) is $status" >> $mail/table.html
echo  "Content-type: text/html" >> $mail/table.html
echo  "<html><body>" >> $mail/table.html
echo  "Hi Team,<br><br>" >> $mail/table.html
echo  "MySQL Backup on $server ($host_ip) is <b><font color='$color'>$status.</font></b><br>" >> $mail/table.html
echo  "<br><center><b>Binary log details</b></center><br>" >> $mail/table.html
echo  "<table border='1' width='400px' align='center' cellpadding='0' cellspacing='0'><tr align='center'><th><font color='blue'>Binlog File</th><th><font color='blue'>Binlog Position</th></tr><tr><td>$log_file</td><td>$log_pos</td></tr></table>" >> $mail/table.html
echo  "Backup Type : <b>$back_type</b><br>" >> $mail/table.html
        if [[ $back_type == "Full Backup" ]];
        then
                echo  "<br><center><b>Full Backup size for today</b></center><br>" >> $mail/table.html
                echo  "<table border='1' width='400px' align='center' cellpadding='0' cellspacing='0'><tr align='center'><th><font color='blue'>Backup File-Full Path</th><th><font color='blue'>File size</th></tr><tr><td>$backup_file</td><td>$backupsize</td></tr></table><br>" >> $mail/table.html
                                if [[ $drop -ge 2 ]]; then
                echo  "<br><center><b>Archieved backups</b></center><br>" >> $mail/table.html
                echo  "<table border='1' width='400px' align='center'  cellpadding='0' cellspacing='0'><tr align='center'><th><font color='blue'>File name</th><th><font color='blue'>File size</th></tr><tr><td>$arch_file</td><td>$arch_size</td></tr></table><br>" >> $mail/table.html
                                fi
        else

                echo  "<br><center><b>Incremental backup size for today</b></center><br>" >> $mail/table.html
                echo  "<table border='1' width='400px' align='center' cellpadding='0' cellspacing='0'><tr align='center'><th><font color='blue'>Backup File-Full Path</th><th><font color='blue'>File size</th></tr><tr><td>$backup_file</td><td>$backupsize</td></tr></table><br>" >> $mail/table.html

                echo  "<center><b>Available backups</b></center><br>" >> $mail/table.html
                echo  "<center><table border='1' width='400px'  cellpadding='0' cellspacing='0'><tr align='center'><th><font color='blue'>File Name</th><th><font color='blue'>File Size</th></tr>$avb_inc_backup</table></center>" >> $mail/table.html
        fi

echo  "</body></html>" >> $mail/table.html
        if [[ $rem_mail == yes ]]; then
        cat $mail/table.html | ssh $mail_user@$mail_host "$sendmail -i -t"
        else
        cat $mail/table.html | $sendmail -i -t
        fi

else
echo  "FROM: '$client Backup' <backup@$server>" >> $mail/table.html
echo  "TO: $receiver_new" >> $mail/table.html
echo  "SUBJECT: MySQL Hot Backup on $bdate ($server) is $status" >> $mail/table.html
echo  "Content-type: text/html" >> $mail/table.html
echo  "<html><body>" >> $mail/table.html
echo  "Hi Team,<br><br>" >> $mail/table.html
echo  "MySQL Backup on $server is <b><font color='$color'>$status</font></b><br>" >> $mail/table.html
echo  "Please check the error log $error_log" >> $mail/table.html
echo  "</body></html>" >> $mail/table.html
        if [[ $rem_mail == yes ]]; then
        cat $mail/table.html | ssh $mail_user@$mail_host "$sendmail -i -t"
        else
        cat $mail/table.html | $sendmail -i -t
        fi
fi


echo "Ended : `date +'%d-%b-%Y %H:%M:%S'`" >> $date_list/back_details.txt

########################section to update backup status to monitor server########################

host=$(cat $date_list/back_details.txt | grep -w  Host | awk '{print $3}')
client=$(cat $date_list/back_details.txt | grep -w  Client | awk '{print $3}')
config_name=$(cat $date_list/back_details.txt | grep -w  SSH_Config | awk '{print $3}')
back_method=$(cat $date_list/back_details.txt | grep -w  Back_Method | awk '{print $3}')
back_type=$(cat $date_list/back_details.txt | grep -w  Backup_Type | awk '{print $3}')
backup_status=$(cat $date_list/back_details.txt | grep -w  Backup_Status | awk '{print $3}')
back_size=$(cat $date_list/back_details.txt | grep -w  Backup_Size | awk '{print $3}')
back_path=$(cat $date_list/back_details.txt | grep -w  Backup_Path | awk '{print $3}')
bin_file=$(cat $date_list/back_details.txt | grep -w  Binlog_file | awk '{print $3}')
bin_pos=$(cat $date_list/back_details.txt | grep -w  Binlog_pos | awk '{print $3}')
purged_back=$(cat $date_list/back_details.txt | grep -w  Purge_Backup | awk '{print $3}')
err_path=$(cat $date_list/back_details.txt | grep -w  Error_log_path | awk '{print $3}')

started=$(cat $sub/xtrabackup_info | grep -w  start_time | awk '{print $3" "$4}')
ended=$(cat $sub/xtrabackup_info | grep -w  end_time | awk '{print $3" "$4}')
back_tool=$(cat $sub/xtrabackup_info | grep -w  tool_name | awk '{print $3}')
frm_lsn=$(cat $sub/xtrabackup_info | grep -w  innodb_from_lsn | awk '{print $3}')
to_lsn=$(cat $sub/xtrabackup_info | grep -w  innodb_to_lsn | awk '{print $3}')
compr=$(cat $sub/xtrabackup_info | grep -w  compressed | awk '{print $3}')

if [[ $compr == 'compressed' ]]; then
compress="yes"
else
compress="yes"
fi
encr=$(cat $sub/xtrabackup_info | grep -w  encrypted | awk '{print $3}')
if [[ $encr == 'N' ]]; then
encrypt="no"
else
encrypt="yes"
fi
gtid=$(cat $sub/xtrabackup_info | grep -w  uuid | awk '{print $3}')

if [[ "$back_status" == completed ]];
then
back_log="No logs"
else
back_log=$(cat $sub/back_error)
fi


#/usr/bin/mysql --login-path=backup_poll -e "insert into mydbops_monitor.BACKUP_ALERT (Host,Client,Backup_Method,Backup_Type,Backup_Status,Start_Time,End_Time,Backup_path,Backup_Size,moddate) values ('$host','$client','$back_method','$back_type','$back_status','$started','$ended','$back_path','$back_size',now());"

/usr/bin/mysql --login-path=backup_poll -e "insert into mydbops_monitor.BACKUP_ALERT (Client,Host,Config_Name,Backup_Method,Backup_Type,Backup_Tool,Backup_Status,Backup_path,Backup_Size,Binlog_File,Binlog_Pos,gtid,Start_Time,End_Time,From_lsn,To_lsn,Compressed,moddate,encryption,log_file,Error_log,Purged_Backup,mount_usage) values ('$client','$host','$config_name','$back_method','$back_type','$back_tool','$backup_status','$back_path','$back_size','$bin_file','$bin_pos','$gtid','$started','$ended','$frm_lsn','$to_lsn','$compress',now(),'$encrypt','$err_path','$back_log','$purged_back','$mnt_usage');"


###################################################################################################################

echo "end at `date +'%d-%b-%Y %H:%M:%S'`"

###################################################################################################################
