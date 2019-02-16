
#!/bin/bash

#-------------------------------------------------------------------------#
# Flags:        -r = delete data from old run                             #
#-------------------------------------------------------------------------#
# Returncodes:  0 = everything okay                                       #
#               1 = finished cleanup run                                  #
#               2 = wrong user or wrong settings for $HOME                #
#               3 = log directory does not exist                          #
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Definition of global variables                                          #
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Definition of reusable functions                                        #
#-------------------------------------------------------------------------#

CLEAN_LOG=/tmp/clean.log
TIME_STAMP=`date +'%Y%m%d%H%M'`
ACT_LOGS=/tmp/ACTLOGS$TIME_STAMP.tar
SAP_LOG=/tmp/SAPLOGS$TIME_STAMP.txt
CLEAR_LOG=/tmp/clean_disk_$TIME_STAMP.log
IS_INSTANCE_NAME=default

typeset -i USED_SPACE_START=0
USED_SPACE_START=`df -k . | tail -1 | awk '{print $3}'`

if [[ -n $1 && "$1" == "-r" ]]
then
    clear
    echo " Cleaning up /tmp!"
    rm /tmp/ACTLOGS*.tar.gz
    rm /tmp/clean_disk_*.log
    ls -ltr /tmp
    echo " Finished!"
    exit 1
fi

touch $CLEAR_LOG

clear

echo " This is clean_disk.sh, version 0.94" | tee -a $CLEAR_LOG
echo " Actual timestamp "`date +'%Y%m%d%H%M'` | tee -a $CLEAR_LOG

# Check home directory
#echo $HOME

if [[  -d "$HOME" && "$HOME" = /opt/w[dqpxt]is??? ]]
then
    cd $HOME
    echo
    echo " Checking in HOME directory "$HOME | tee -a $CLEAR_LOG
else
    echo
    echo " Wrong user or home directory!" | tee -a $CLEAR_LOG
    echo " Home directory is set to:      "$HOME | tee -a $CLEAR_LOG
    echo " Home directory should be like: /opt/w[dqp]isXXX" | tee -a $CLEAR_LOG
    echo " Script will be canceled!" | tee -a $CLEAR_LOG
    exit 2
fi

# Check and delete core dumps
echo " 1. Checking for coredumps!" | tee -a $CLEAR_LOG

typeset -i i=0
while read CORE_DUMPS[$i]
do
    i=i+1
done <<EOM
`find $HOME -name core -type f -print`
EOM

if [[ -z `echo ${CORE_DUMPS[*]}` ]]
then
    echo " No core dump to be deleted" | tee -a $CLEAR_LOG

else
    echo " Deleting following coredumps:" | tee -a $CLEAR_LOG
    for CORE_DUMP in ${CORE_DUMPS[*]}
    do
       ls -l $CORE_DUMP | tee -a $CLEAR_LOG
       rm $CORE_DUMP | tee -a $CLEAR_LOG
    done
fi

# Check and delete IS logs
echo " 2. Checking standard log directory!" | tee -a $CLEAR_LOG

#echo $HOME/IntegrationServer/instances/$IS_INSTANCE_NAME/logs
LOG_DIR=$HOME/IntegrationServer/instances/$IS_INSTANCE_NAME/logs

if [[  -d "$LOG_DIR" ]]
then
    cd $LOG_DIR
    echo "Standard log directory: "$LOG_DIR | tee -a $CLEAR_LOG
else
    echo "No log directory found!" | tee -a $CLEAR_LOG
    exit 3
fi

typeset -i i_unused=0 i_used=0

typeset -i SAVE_SIZE=0

for FILE in `ls $LOG_DIR/*.log*`
do
  if [[ -f $FILE ]]
  then
    OPEN_FILE=`/usr/sbin/fuser $FILE 2> /dev/null; printf "\n"`
    if [[ "$OPEN_FILE" = "" ]]
    then
        i_unused=$i_unused+1
        FILE_UNUSED[$i_unused]=$FILE
    else
        i_used=$i_used+1
        SAVE_SIZE=$SAVE_SIZE+`ls -l $FILE | awk '{printf $5 "\n"}'`
        FILE_USED[$i_used]=$FILE
    fi
  fi
done

if [[ `echo ${FILE_UNUSED[*]}` != "" ]]
then
    echo " Following log files are unused and can be deleted!" | tee -a $CLEAR_LOG
    for FILE in ${FILE_UNUSED[*]}
    do
        rm $FILE | tee -a $CLEAR_LOG
        echo $FILE" deleted!"  | tee -a $CLEAR_LOG
    done
else
    echo " No logfile not in use found! Nothing can be deleted!" | tee -a $CLEAR_LOG
fi

if [[ `echo ${FILE_USED[*]}` != "" ]]
then
    echo " Found in use log files! Saving them for analysis to "$ACT_LOGS | tee -a $CLEAR_LOG
    typeset -i SPACE_REQUIRED=0
    SPACE_REQUIRED=$SAVE_SIZE/1024
    if  (( `df -k /tmp | tail -1 | awk '{printf $4 "\n"}'` > "$SPACE_REQUIRED" ))
    then
        echo " Creating tar archive "$ACT_LOGS"!"
        touch $ACT_LOGS
        for FILE in ${FILE_USED[*]}
        do
                tar -rvf $ACT_LOGS $FILE | tee -a $CLEAR_LOG
        done
    else
        echo " Not enough freespace in /tmp! At least "$SAVE_SIZE" kb is needed!"
    fi
    echo " Now clearing the used logfiles!" | tee -a $CLEAR_LOG
    for FILE in ${FILE_USED[*]}
    do
       cat /dev/null > $FILE
       echo $FILE" was emtpied" | tee -a $CLEAR_LOG
    done
else
    echo " No logfile in use found!" | tee -a $CLEAR_LOG
fi

unset OPEN_FILE FILE_UNUSED FILE_USED FILE


echo " 3. Checking IS profile log directory!" | tee -a $CLEAR_LOG

#echo $HOME/profiles/IS_$IS_INSTANCE_NAME/logs
PROFILELOG_DIR=$HOME/profiles/IS_$IS_INSTANCE_NAME/logs

if [[  -d "$PROFILELOG_DIR" ]]
then
    cd $PROFILELOG_DIR
    echo "Profile log directory: "$PROFILELOG_DIR | tee -a $CLEAR_LOG
else
    echo "No log directory found!" | tee -a $CLEAR_LOG
    exit 3
fi

typeset -i i_unused=0 i_used=0

typeset -i SAVE_SIZE=0

for FILE in `ls $PROFILELOG_DIR/*.log*`
do
  if [[ -f $FILE ]]
  then
    OPEN_FILE=`/usr/sbin/fuser $FILE 2> /dev/null; printf "\n"`
    if [[ "$OPEN_FILE" = "" ]]
    then
        i_unused=$i_unused+1
        FILE_UNUSED[$i_unused]=$FILE
    else
        i_used=$i_used+1
        SAVE_SIZE=$SAVE_SIZE+`ls -l $FILE | awk '{printf $5 "\n"}'`
        FILE_USED[$i_used]=$FILE
    fi
  fi
done

if [[ `echo ${FILE_UNUSED[*]}` != "" ]]
then
    echo " Following log files are unused and can be deleted!" | tee -a $CLEAR_LOG
    for FILE in ${FILE_UNUSED[*]}
    do
        rm $FILE | tee -a $CLEAR_LOG
        echo $FILE" deleted!"  | tee -a $CLEAR_LOG
    done
else
    echo " No logfile not in use found! Nothing can be deleted!" | tee -a $CLEAR_LOG
fi

if [[ `echo ${FILE_USED[*]}` != "" ]]
then
    echo " Found in use log files! Saving them for analysis to "$ACT_LOGS | tee -a $CLEAR_LOG
    typeset -i SPACE_REQUIRED=0
    SPACE_REQUIRED=$SAVE_SIZE/1024
    if  (( `df -k /tmp | tail -1 | awk '{printf $4 "\n"}'` > "$SPACE_REQUIRED" ))
    then
        echo " Creating tar archive "$ACT_LOGS"!"
        touch $ACT_LOGS
        for FILE in ${FILE_USED[*]}
        do
                tar -rvf $ACT_LOGS $FILE | tee -a $CLEAR_LOG
        done
    else
        echo " Not enough freespace in /tmp! At least "$SAVE_SIZE" kb is needed!"
    fi
    echo " Now clearing the used logfiles!" | tee -a $CLEAR_LOG
    for FILE in ${FILE_USED[*]}
    do
       cat /dev/null > $FILE
       echo $FILE" was emtpied" | tee -a $CLEAR_LOG
    done
else
    echo " No logfile in use found!" | tee -a $CLEAR_LOG
fi

unset OPEN_FILE FILE_UNUSED FILE_USED FILE




# Check and delete sap rfc logs
# dev_rfc.trc   find . -name "dev_rfc*" -print
# packages/SAP/logs/new_sap*.log find . -name "new_sap????????.log" -print
# rfc?????_?????.trc    find . -name "rfc?????_?????.trc" -print
##echo " 3. Checking for  SAP rfc log and trace files!" | tee -a $CLEAR_LOG

##typeset -i i_unused=0 i_used=0

##typeset -i SAVE_SIZE=0

# collecting sap logfiles
##touch $SAP_LOG
##find $HOME/IntegrationServer -name "dev_rfc*" -print >> $SAP_LOG
##find $HOME/IntegrationServer -name "new_sap????????.log" -print >> $SAP_LOG
##find $HOME/IntegrationServer -name "rfc?????_?????.trc" -print >> $SAP_LOG

##for FILE in `cat $SAP_LOG`
##do
##  if [[ -f $FILE ]]
##  then
##    OPEN_FILE=`/usr/sbin/fuser $FILE 2> /dev/null; printf "\n"`
##    if [[ "$OPEN_FILE" = "" ]]
##    then
##        i_unused=$i_unused+1
##        FILE_UNUSED[$i_unused]=$FILE
##    else
##        i_used=$i_used+1
##        SAVE_SIZE=$SAVE_SIZE+`ls -l $FILE | awk '{printf $5 "\n"}'`
##        FILE_USED[$i_used]=$FILE
##    fi
##  fi
##done

##if [[ `echo ${FILE_UNUSED[*]}` != "" ]]
##then
##    echo " Following rfc log files are not in use and can be deleted!" | tee -a $CLEAR_LOG
##    for FILE in ${FILE_UNUSED[*]}
##    do
##        rm $FILE | tee -a $CLEAR_LOG
##        echo $FILE" deleted!"  | tee -a $CLEAR_LOG
##    done
##else
##    echo " No rfc logfile not in use found! Nothing can be deleted!" | tee -a $CLEAR_LOG
##fi

##if [[ `echo ${FILE_USED[*]}` != "" ]]
##then
##    echo " Found rfc log files in use! Saving them for analysis to "$ACT_LOGS | tee -a $CLEAR_LOG
##    typeset -i SPACE_REQUIRED=0
##    SPACE_REQUIRED=$SAVE_SIZE/1024
##    echo $SPACE_REQUIRED
##    if  (( `df -k /tmp | tail -1 | awk '{printf $4 "\n"}'` > "$SPACE_REQUIRED" ))
##    then
##        if [[ ! -f "$ACT_LOGS" ]]
##        then
##            touch $ACT_LOGS
##        fi
##        for FILE in ${FILE_USED[*]}
##        do
##                tar -rvf $ACT_LOGS $FILE | tee -a $CLEAR_LOG
##        done
##    fi
##    echo " Now clearing the used logfiles!" | tee -a $CLEAR_LOG
##    for FILE in ${FILE_USED[*]}
##    do
##       cat /dev/null > $FILE
##       echo $FILE" was emtpied" | tee -a $CLEAR_LOG
##    done
##else
##    echo " No logfile in use found!" | tee -a $CLEAR_LOG
##fi

# cleanup replicate directory
echo " 4. Cleaning replicate/outbound and replicate/salvage directory!" | tee -a $CLEAR_LOG
cd $HOME/IntegrationServer/instances/$IS_INSTANCE_NAME
echo " Package releases in replicate/outbound!" | tee -a $CLEAR_LOG
typeset -i NUMBER_FILES=0
NUMBER_FILES=`ls -l replicate/outbound | wc -l`
if [[ "$NUMBER_FILES" > "1" ]]
then
    ls -l replicate/outbound  | tee -a $CLEAR_LOG
    echo " Deleting package releases in replicate/outbound!" | tee -a $CLEAR_LOG
    rm $HOME/IntegrationServer/instances/$IS_INSTANCE_NAME/replicate/outbound/*.zip
else
    echo " No package releases in replicate/outbound!" | tee -a $CLEAR_LOG
fi
typeset -i NUMBER_FILES=0
echo " Package backups in replicate/salvage!" | tee -a $CLEAR_LOG
NUMBER_FILES=`ls -l replicate/salvage | wc -l`
if [[ "$NUMBER_FILES" > "1" ]]
then
    ls -l replicate/salvage  | tee -a $CLEAR_LOG
    echo " Deleting package backups in replicate/salvage!" | tee -a $CLEAR_LOG
    rm -R $HOME/IntegrationServer/instances/$IS_INSTANCE_NAME/replicate/salvage/*
else
    echo " No package backups in replicate/salvage!" | tee -a $CLEAR_LOG
fi

SAVE_SIZE=0

##rm $SAP_LOG
unset OPEN_FILE FILE_UNUSED FILE_USED FILE

echo | tee -a $CLEAR_LOG
echo " Finished with clean up!" | tee -a $CLEAR_LOG

echo " Short break for releasing disk space!"
sleep 30

typeset -i USED_SPACE_END=0
USED_SPACE_END=`df -k . | tail -1 | awk '{print $3}'`

typeset -i FILESYSTEM=0
FILESYSTEM=`df -k . | tail -1 | awk '{print $2}'`

typeset -i FREE_START=0

FREE_START=$FILESYSTEM-$USED_SPACE_START

typeset -i FREE_END=0

FREE_END=$FILESYSTEM-$USED_SPACE_END

typeset -i FREE=0

FREE=$FREE_END-$FREE_START

# Some output for analysis reason
#echo "USED_SPACE_START: "$USED_SPACE_START
#echo "USED_SPACE_END:   "$USED_SPACE_END
#echo "FILESYSTEM:       "$FILESYSTEM

# Ueberpruefung Erfolg
echo  | tee -a $CLEAR_LOG
echo " VERIFIFCATION:"  | tee -a $CLEAR_LOG
echo  | tee -a $CLEAR_LOG
echo " Free space before cleanup [kb]: "$FREE_START | tee -a $CLEAR_LOG
echo " Free space after cleanup  [kb]: "$FREE_END  | tee -a $CLEAR_LOG
echo | tee -a $CLEAR_LOG
echo " Freed disk space          [kb]: "$FREE | tee -a $CLEAR_LOG
echo | tee -a $CLEAR_LOG

if [[ -f "$ACT_LOGS" ]]
then
    echo | tee -a $CLEAR_LOG
    echo " Adding logfile to tar archive!" | tee -a $CLEAR_LOG
    echo | tee -a $CLEAR_LOG
    tar -rvf $ACT_LOGS $CLEAR_LOG | tee -a $CLEAR_LOG
    echo | tee -a $CLEAR_LOG
    echo " Zipping the analysis tar archive!" | tee -a $CLEAR_LOG
    echo | tee -a $CLEAR_LOG
    gzip -9 $ACT_LOGS | tee -a $CLEAR_LOG
    echo " File can be found under /tmp!" | tee -a $CLEAR_LOG
    echo " File: "$ACT_LOGS".gz" | tee -a $CLEAR_LOG
    echo | tee -a $CLEAR_LOG
fi

echo " Logfile of this run can be found under /tmp!"  | tee -a $CLEAR_LOG
echo " File: "$CLEAR_LOG
echo
exit 0
