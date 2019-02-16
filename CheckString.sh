#!/bin/bash


#-----------------Description-------------------------------------------------------------------------------------------#
# Search for String in Files under a given path and create a List of them and save those files under a specific
# place. Files bigger then 100Mb will be skipped and marked in the list.
#-----------------------------------------------------------------------------------------------------------------------#
VERSION="1.0.1"
#-----------------Changes-----------------------------------------------------------------------------------------------#
# V 1.0.0
# V 1.0.1       added lower-case mail / removed echo for the check of each file in list
#-----------------------------------------------------------------------------------------------------------------------#

DATE=`date +'%Y-%m-%d'`
TIME_STAMP=`date +'%Y-%m-%d-%H-%M-%S'`
SCRIPT_DIR=.
LOGFILE=""
FILE_LIST=""
SEARCH_DIR=""
OUTPUT_FOLDER=""
SEARCH_STRING='*******' #give search string

# <----------------------------------------- functions ---------------------------------------------------------------->

#list wrapper function
f_list(){
        file=$1
        #echo "CHECK $file"
        #-i    Ignores upper/lower case distinction during  comparisons.
        COUNT=$(egrep -i $SEARCH_STRING $file | wc -l)
        if [ $COUNT -ne 0 ]; then
                #found - add it to list
                echo "$COUNT time(s)     $file" | tee -a $FILE_LIST
        fi
}

#zip wrapper function
f_zip(){
        file=$1
        target_folder=$2
        #-i    Ignores upper/lower case distinction during  comparisons.
        COUNT=$(egrep -i $SEARCH_STRING $file | wc -l)
        if [ $COUNT -ne 0 ]; then
                #found - add it to list
                echo "$COUNT time(s)     $file" | tee -a $FILE_LIST
                cp $file $target_folder
                rc=$?;
                [ "$rc" != "0" ] && echo "$ERROR: Could not copy $file to $target_folder" | tee -a $FILE_LIST
        fi
}

#replace wrapper function
f_replace(){
        file=$1
        #-i    Ignores upper/lower case distinction during  comparisons.
        COUNT=$(egrep -i $SEARCH_STRING $file | wc -l)
        if [ $COUNT -ne 0 ]; then
                #found - add it to list
                echo "$COUNT time(s)     $file" | tee -a $FILE_LIST
                #tmpfile erstellen
                tmpfile="$file."`date +%Y%m%d`"_"`date +%H%M%S`;
                >$tmpfile;
                sed -e 's% search string' 
                rc=$?;
                [ "$rc" != "0" ] && echo "ERROR: couldn't edit file $file and write it into $tmpfile!" | tee -a $FILE_LIST && return;
                mv $tmpfile $file;
                rc=$?;
                [ "$rc" != "0" ] && echo "ERROR: couldn't move tmp file $tmpfile to $file!" | tee -a $FILE_LIST && return;
                echo "- file $file has been successfully edited!" | tee -a $FILE_LIST
        fi
}

f_check_params(){
        # check if the folder exist / otherwise create them
        #[ ! -d $1 ] && echo "ERROR: not able to create directory $1" && exit 5;
        #[ ! -d $2 ] && mkdir -p $2 && echo "ERROR: not able to create directory $2" && exit 5;
        #check if directory is writeable
        #[ ! -w $1 ] && echo "ERROR: not able to write in directory $1" && exit 6;
        [ ! -w $2 ] && echo "ERROR: not able to write in directory $2" && exit 6;

        mkdir -p $RUN_FOLDER
}

f_help(){
  #Info's about the script
    echo Version: $VERSION
    echo "Usage: check_string_in_file.sh [{-list, -replace, -zip}] path outputFolder"
        echo -e "path\tpath were the script is searching for files - regular expressions allowed. See 'man find' for more informations."
        echo -e "outputFolder\tPath were the script is storing the data while running, i.e. Logs, Files, ..."
}

# <----------------------------------------- functions ---------------------------------------------------------------->


# <----------------------------------------- main ---------------------------------------------------------------->

if [ "$1" == "--help" ]; then
        f_help
    exit 0
fi

[ "$1" = "" ] && echo "ERROR: no type given!" && f_help && exit 1;
[ "$2" = "" ] && echo "ERROR: no path given!" && f_help && exit 2;
[ "$3" = "" ] && echo "ERROR: no outpuFolder given!" && f_help && exit 3;

SEARCH_DIR=$2
OUTPUT_FOLDER=$3
RUN_FOLDER=$OUTPUT_FOLDER/run-$TIME_STAMP
LOGFILE=$RUN_FOLDER/csif-$TIME_STAMP.log
FILE_LIST=$RUN_FOLDER/csif-found-files-$TIME_STAMP.log
TMP_FILE_LIST=$RUN_FOLDER/scanned-files-$TIME_STAMP.log

if [ "$1" == "-list" ]; then
        f_check_params $SEARCH_DIR $OUTPUT_FOLDER

        # buffer all files of directory in tmp-File
        find $SEARCH_DIR -type f > $TMP_FILE_LIST
        BACK_IFS="$IFS"
        IFS=''
        while read line; do
                f_list $line
        done < $TMP_FILE_LIST
        IFS=$BACK_IFS
        echo "---> DONE"
        echo "Results of this run can be found in: $RUN_FOLDER"
        exit 0
fi

if [ "$1" == "-replace" ]; then
        # check the params 2 and 3
        f_check_params $SEARCH_DIR $OUTPUT_FOLDER
        find $SEARCH_DIR -type f > $TMP_FILE_LIST
        BACK_IFS="$IFS"
        IFS=''
        while read line; do
                f_replace $line
        done < $TMP_FILE_LIST
        echo "---> DONE"
        IFS=$BACK_IFS
        echo "---> DONE"
        echo "Results of this run can be found in: $RUN_FOLDER"
        exit 0
fi

if [ "$1" == "-zip" ]; then
        # check the params 2 and 3
        f_check_params $SEARCH_DIR $OUTPUT_FOLDER
        FILES_FOLDER=$OUTPUT_FOLDER/FILES-$TIME_STAMP
        mkdir -p $FILES_FOLDER
        find $SEARCH_DIR -type f > $TMP_FILE_LIST
        BACK_IFS="$IFS"
        IFS=''
        while read line; do
                f_zip $line $FILES_FOLDER
        done < $TMP_FILE_LIST
        IFS=$BACK_IFS
        #tar and zip the folder
        tar cvf - $FILES_FOLDER | gzip -c > $RUN_FOLDER/files.tar.gz && rm -rf $FILES_FOLDER
        IFS=$BACK_IFS
        echo "---> DONE"
        echo "Results of this run can be found in: $RUN_FOLDER"
        exit 0
fi

#no valid type given
