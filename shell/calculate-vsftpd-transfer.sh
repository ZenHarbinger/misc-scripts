#!/bin/sh
# calculate amount transferred in KB and GB for a given vsftpd user
# calculate the average transfer rate across all transfers (after normalized by vsftpd)
# usage ./calculate-vsftp-transfer.sh $username
# assumes the following log format options for vsftpd
# xferlog_enable=YES
# dual_log_enable=YES
# log_ftp_protocol=YES

username=$1
log_location="/var/log/vsftpd.log"

calculate_byte_transfer()
{   # grab the user amount
    cat $log_location | grep $username | grep "OK DOWNLOAD" | grep bytes \
    | awk -F "," '{print $3}' | sed 's/ bytes//' | awk '{s+=$1} END {print s}'
}

calculate_gb_transfer()
{   # calculate bytes to gb (1 gb = 1073741824 bytes)
    byte_transfer=$(calculate_byte_transfer)
    echo "$byte_transfer / 1073741824" | bc
}

calculate_transfer_average()
{   # gather total mount of transfers
    transfer_count=`cat $log_location | grep $username | grep "OK DOWNLOAD" | grep bytes \
    | awk -F "," '{print $NF}' | sed 's/Kbyte\/sec//' | wc -l`
    transfer_speed_sum=`cat $log_location | grep $username | grep "OK DOWNLOAD" | grep bytes \
    | awk -F "," '{print $NF}' | sed 's/Kbyte\/sec//' | awk '{s+=$1} END {print s}'`
    echo "$transfer_speed_sum / $transfer_count" | bc
}    

calculate_transfer_total()
{   # generate summary
    byte_transfer=$(calculate_byte_transfer)
    gb_transfer=$(calculate_gb_transfer)
    avg_transfer=$(calculate_transfer_average)
    echo "                                      "
    echo "======================================"	
    echo "Download Stats for User $username"
    echo "--------------------------------------"
    echo "Bytes        :: $byte_transfer"
    echo "Gigabytes    :: $gb_transfer"
    echo "Average Rate :: $avg_transfer KB/sec" 
    echo "======================================"
}

calculate_transfer_total
