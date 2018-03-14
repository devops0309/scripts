#!/bin/bash
############################################################################################################################
#   Name                :  Security-T&E.sh			Alias:System testing & Evaluation                                      #
#   Purpose             :  Script for system Testing and Evaluation 	Infrastructure  								   #
#   Author				:       	        	      ver 1.1                                                              #
############################################################################################################################
# Modifications
# 

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
#Set Env Variables
NOW=$(date +"Time:%H-%M-%S-DAY:%d-%m-%Y")
Red='\033[1;31m'
Green='\033[1;32m'
Black='\033[0;30m'
LOG_DIR="/tmp/sec-te"
LOG_FILE="$LOG_DIR/sec-te.log"
TEMP_DIR="/tmp/"
pam_file="/etc/pam.d/common-auth"

# Verifying Directories
if [ ! -d $LOG_DIR ]; then
mkdir $LOG_DIR
echo "$LOG_DIR log directory doesn't exists , directory created" 
fi
if [ ! -d $TEMP_DIR ]; then
mkdir $TEMP_DIR
echo "$TEMP_DIR temp directory doesn't exists , directory created"
fi

#Network Information
IPADDR=`/sbin/ifconfig|grep -i "inet addr:"|grep -v "inet addr:127.0.0.1"|awk -F ':' '{print$2}'|awk '{print$1}'`
OS=`cat /etc/*release | head -1 | awk {'print $1'}`

#Updating Report File
> $LOG_FILE
echo "Security T&E Report" >> $LOG_FILE
echo "=============================================" >> $LOG_FILE
echo "SYSTEM DETAILS :" >> $LOG_FILE
echo "IP address: $IPADDR" >> $LOG_FILE
echo "$OS" >> $LOG_FILE
echo "=============================================" >> $LOG_FILE
#Check OS Type & Version

#1Update repository & remove non-existent packages
echo "Updating Repository & Purging obsolete packages... Please wait."
sudo apt update 
sudo apt -y dist-upgrade 
sudo apt -y autoremove 
sudo apt clean 
sudo apt purge -y $(dpkg -l | awk '/^rc/ { print $2 }') 
echo "  - Packages up-to-date\t\t\t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE

#2 Install rsync if not installed
pkg_status=`dpkg-query -l rsync | tail -1 | awk {'print $1'}`
if [ "$pkg_status" = "ii" ];then
	{
		#sudo apt-get install rsync -y
		echo "  - Rsync\t\t\t\t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE
	}
else
	{
		echo "  - Rsync\t\t\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
	}
fi

#3 Password Aging Policy set
sudo cat /etc/passwd | grep "bash" | cut -d : -f 1 | tail -n +3 > /tmp/list_user.txt
while IFS= read -r var
do
  sudo chage -M 90 $var
done < /tmp/list_user.txt
echo "  - Password Aging Policy for users. \t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE

#4 Locking User Accounts After Login Failures
if [ -f "$pam_file" ]
then
    cat $pam_file | grep -i "unlock_time*" >> /dev/null
	if [ $? -ne '0' ];then
    	echo "auth    required       pam_faillock.so preauth silent audit deny=3 unlock_time=600" >> $pam_file
    	echo "auth    [default=die]  pam_faillock.so authfail audit deny=3 unlock_time=600" >> $pam_file
    fi
    echo "  - Locking User Accounts After 3 Login Failures.\t      [ ${Green}OK ${Black}]" >> $LOG_FILE
fi

#5 Restricting Use of Previous Passwords
if [ -f "$pam_file" ]
then
    cat $pam_file | grep -i "remember*" >> /dev/null
	if [ $? -ne '0' ];then
    	echo "password sufficient pam_unix.so use_authtok md5 shadow remember=13" >> $pam_file
    fi
    echo "  - Restricting use of previous passwords.\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE
fi

# Verify No Accounts Have Empty Passwords?
#sudo getent shadow | grep '^[^:]*:.\?:' | cut -d: -f1

#6 Fail2Ban
pkg_status=`dpkg-query -l fail2ban | tail -1 | awk {'print $1'}`
if [ "$pkg_status" = "ii" ];then
	{
		#sudo apt-get install fail2ban -y
		echo "  - Fail2ban Configured.\t\t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE
	}
else
	{
		echo "  - Fail2ban Configured.\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
	}
fi

#7 Disable USB Devices
usb_file="/etc/modprobe.d/blacklist.conf"
if [ -f "$usb_file" ]
then
    cat $usb_file | grep "usb-storage" >> /dev/null
	if [ $? -ne '1' ];then
    	echo "  - Blacklist usb-storage\t\t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE
    else
    	echo "  - Blacklist usb-storage\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
    fi
else
	echo "  - Backlist usb-storage\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
fi

#8 Disable Thunderbolt & Firewire Devices
firwire_file="/etc/modprobe.d/blacklist-firewire.conf"
if [ -f "$firwire_file" ]
then
    cat $firwire_file | grep "firewire-core" >> /dev/null
	if [ $? -ne '1' ];then
    	 echo "  - Backlist firewire-core\t\t\t\t      [${Green}OK ${Black}]" >> $LOG_FILE
    fi
    echo "  - Backlist firewire-core\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
else
	echo "  - Backlist firewire-core\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
fi

#9 Install auditd
pkg_status=`dpkg-query -l auditd | tail -1 | awk {'print $1'}`
if [ "$pkg_status" = "ii" ];then
	{
		#sudo apt-get install auditd -y
		echo "  - Auditd Installed\t\t\t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE
	}
else
	{
		echo "  - Auditd Installed \t\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
	}
fi

#10 Check Diskspace
df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | while read output;
do
  echo $output >> LOG_FILE
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1  )
  partition=$(echo $output | awk '{ print $2 }' )
  if [ $usep -ge 80 ]; then
    echo "  - Disk Space \t\t\t\t\t\t\t  [ ${Red}WARNING ${Black}]" >> $LOG_FILE
    #mail -s "Alert: Almost out of disk space $usep%" you@somewhere.com  
  fi
done
echo "  - Disk Space \t\t\t\t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE

#11 Backup
echo "  - Backup of server.\t\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE

#12 NGINX
service=nginx
if [ $(ps -ef | grep -v grep | grep $service | wc -l) > 0 ];
then
	echo "  - NGINX SERVICE \t\t\t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE
else
	echo "  - NGINX SERVICE \t\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
fi

#13 Apache
service=apache2
if [ $(ps -ef | grep -v grep | grep $service | wc -l) > 0 ];
then
	echo "  - Apache SERVICE \t\t\t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE
else
	echo "  - Apache SERVICE \t\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
fi

#14 MYSQL
UP=$(pgrep mysql | wc -l);
if [ "$UP" -ne 1 ];
then
        echo "  - MySQL SERVICE\t\t\t\t\t      [ ${Red}WARNING ${Black}]" >> $LOG_FILE
else
        echo "  - MYSQL SERVICE\t\t\t\t\t      [ ${Green}OK ${Black}]" >> $LOG_FILE
fi

#12 ADD Lynis - System Check
pkg_status=`dpkg-query -l lynis | tail -1 | awk {'print $1'}`
if [ "$pkg_status" != "ii" ];then
	{
		sudo apt-get install lynis -y
		#echo " -  Lynis" >> $LOG_FILE
		#echo "Lynis Report:" >> $LOG_FILE
	}
fi
echo ""
echo "====Running System Scan now. Please wait.===="
sudo lynis audit system --quick | grep -i "OK" >> $LOG_FILE
sudo lynis audit system --quick | grep "WARNING\|DISABLED" >> $LOG_FILE
echo "Security Training & Evaluation is completed. Please check the report: $LOG_FILE"



