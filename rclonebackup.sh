#!/bin/bash

main_function() {

# Location to place backups.
backup_dir="/home/backup/"
#String to append to the name of the backup files
backup_date=`date +%Y-%m-%d_%a-%H-%M`
# User that runs backup
backup_user=kasa
#Numbers of days you want to keep copie of your databases
number_of_days=365
mailto="ncakelic@holobit.hr"
log="evidencija.log"
rclonelog="rclone.log"
from="ncakelic@holobit.hr"
databases=`psql -U $backup_user -l -t | egrep -v 'postgres|template[01]' | awk '{print $1}'`
for i in $databases; do
    echo Dumping $i to $backup_dir$i\_$backup_date
    pg_dump -U $backup_user -Fp $i > $backup_dir$backup_date\_$i\.arh
    if [ "${?}" -eq 0 ]; then
    bzip2 $backup_dir$backup_date\_$i\.arh
    else
    echo "Dump baza kod `hostname` nije uspjesno izvrsen na dan `date`" | mail -r $from -s "Dump kod `hostname` nije izvrsen" $mailto
    exit 1
    fi
done

# Pobrisi starije arhive
find $backup_dir -type f -prune -mtime +$number_of_days -exec rm -f {} \; && echo "ARHIVIRANJE i VAKUMIRANJE napravljeno u `date`" >> $backup_dir$log

sleep 5;

# Cloud upload
COMPUTER_NAME=$(hostname -s)
SOURCE_PATH=/home/backup/
DESTINATION_PATH="secret:arhiviranje/${COMPUTER_NAME}/"
CONFIG=/home/$backup_user/.config/rclone/rclone.conf
MESSAGE="/tmp/message.out"

echo "Uploading to cloud storage..."
echo "Uploading to cloud storage..." >> $MESSAGE
rclone --config $CONFIG -v copy $SOURCE_PATH $DESTINATION_PATH \
 --max-age 2d \
 --bwlimit 50k \
 --exclude "{*.log,*cf4*,*tsus*,*arhiva*}" \
 --log-file $backup_dir$rclonelog \
 --retries 4
if [[ $? -eq 0 ]]; then
	echo "Upload na Cloud uspjesno izvrsen u `date`" >> $backup_dir$log
else
        echo "Cloud upload kod `hostname` nije napravljen na dan `date`" >> $MESSAGE | mail -r $from -A "$backup_dir$rclonelog" -s "`hostname` rclone upload failed" $mailto < $MESSAGE
fi
echo "Brisem stari backup s clouda..."
echo "Brisem stari backup s clouda..." >> $MESSAGE
rclone --config $CONFIG -v delete $DESTINATION_PATH \
 --min-age 7d
if [[ $? -eq 0 ]]; then
	 echo "Brisanje starih arhiva uspjesno napravljeno u `date`" >> $backup_dir$log
 else
	 echo "Brisanje arhiva kod `hostname` nije napravljeno na dan `date`" >> $MESSAGE | mail -r $from -A "$backup_dir$rclonelog" -s "`hostname` rclone upload failed" $mailto < $MESSAGE
fi
}

if [ -z $TERM ]; then
  # if not run via terminal, log everything into a log file
  main_function >> $MESSAGE 2>&1
else
  # run via terminal, only output to screen
  main_function
fi
rm $MESSAGE
