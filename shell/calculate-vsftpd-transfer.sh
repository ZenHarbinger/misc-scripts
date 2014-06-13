#!/bin/sh
# calculate amount transferred in KB and GB for a given vsftpd user
# usage ./calculate-vsftp-transfer.sh $username
# assumes the following log format options for vsftpd
# xferlog_enable=YES
# dual_log_enable=YES
# log_ftp_protocol=YES

username=$1
log_location="/var/log/vsftpd.log"

calculate_kb_transfer()
{   # grab the user amount
    cat $log_location | grep $username | grep "OK DOWNLOAD" | grep bytes \
    | awk -F "," '{print $3}' | sed 's/ bytes//' | awk '{s+=$1} END {print s}'
}

calculate_gb_transfer()
{   # calculate kb to gb (kb/(1024*1024) or (kb/(1024^2)
    kb_transfer=$(calculate_kb_transfer)
    echo "(($kb_transfer) / (1024*1024))" | bc
}

calculate_transfer_total()
{   # generate summary
    kb_transfer=$(calculate_kb_transfer)
    gb_transfer=$(calculate_gb_transfer)
    echo "                                      "
    echo "======================================"	
    echo "Total Download for user $username"
    echo "--------------------------------------"
    echo "Kilobytes :: $kb_transfer"
    echo "Gigabytes :: $gb_transfer"
    echo "======================================"
}

calculate_transfer_total
