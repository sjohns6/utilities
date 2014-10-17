#!/bin/ksh
################################################################################
## Function error_chk
################################################################################
function error_chk {
    RC=$1
    MSG=$2
    STOPGO=$3
if ( test $RC -ne 0 ) then
   echo "$MSG"
   if ( test $STOPGO -ne 0 ) then
     echo "Quitting program"
     echo "$MSG" | mail -s "FAILURE:imac2:backup:Documents" $EMAIL
     exit $STOPGO
   fi
fi
}
################################################################################
# Setup variables
APP=Documents
EMAIL="sample@gmail.com"
start_time=$(date +%s)
HOST=`hostname -s`
SRC_DIR="$HOME/Documents"
# My target drive is a NAS
TRG_DIR="/Volumes/media/${HOST}/${APP}_backup"
AWS_BUCKET="s3://stj.S3.backup/Excel"

# Start of Code
date
echo "Backing up Documents from ${SRC_DIR} to ${TRG_DIR}"
mkdir -p $TRG_DIR
error_chk $? "mkdir $TRG_DIR failed" 1

# rsync to backup directory
cd ${SRC_DIR}
rsync -a --delete  --include=".*" ${SRC_DIR} $TRG_DIR 

# Create a list of files for source and target directories.  Compare to ensure all files are same
cd ${TRG_DIR}/${APP}
find . -type f |  egrep -v 'DS_Store|time_machine' | sort  > $HOME/${APP}.list.trg.txt
cd ${SRC_DIR}
find . -type f |  egrep -v 'DS_Store|time_machine' | sort > $HOME/${APP}.list.src.txt
diff $HOME/${APP}.list.trg.txt $HOME/${APP}.list.src.txt 
error_chk $? "Diff Issue" 1
rm  $HOME/${APP}.list.trg.txt $HOME/${APP}.list.src.txt



# I copy to S3 once a week.  
DOW=`date +%u`
# Only run on Fridays
if [[ $DOW -eq 5 ]];then
cd $TRG_DIR 
error_chk $? "Changing to Backup Directory" 1
echo "Calling sync to AWS ${AWS_BUCKET} at `date`"
echo "/usr/local/bin/aws s3 sync . \"${AWS_BUCKET}\" --delete"
/usr/local/bin/aws s3 sync . "${AWS_BUCKET}" --delete
error_chk $? "Sync to AWS Failed" 1
fi
finish_time=$(date +%s)
#echo "Backup Complete for ${SRC_DIR}" | mail -s "SUCCESS:Backup ${APP}" ${EMAIL}
logger -t BACKUP "SUCCESS:Backup ${APP} Duration:$((finish_time - start_time)) secs"

