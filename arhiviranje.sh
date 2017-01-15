#!/bin/sh

# Location to place backups.
BACKUP_DIR="/backup/"
# Second backup location, usually second HDD
SECOND_COPY=0                   # 0 za iskljuceno, 1 za ukljuceno
DEST_DIR="/home/backup/"
# Snimanje na CD/DVD
BURN_BACKUP=0                   # 0 za iskljuceno, 1 za ukljuceno
# Logs
LOG_FILE=evidencija.txt
BURN_LOG=output.txt
# String to append to the name of the backup files
BACKUP_DATE=`date +%Y-%m-%d_%a-%H-%M`
# User that runs backup
BACKUP_USER=kasa
# Broj dana za koliko dugo zelite drzati kopije baza
NUMBER_OF_DAYS=90
# Remote upload
# Da bi REMOTE_UPLOAD uredno radio, potrebno je prvo na racunalu odakle se salje baza,
# generirati ssh kljuc sa ssh-keygen programom, te isti prebaciti na udaljenu lokaciju
# s programom ssh-copy-id
REMOTE_UPLOAD=0                 # 0 za iskljuceno, 1 za ukljuceno
REMOTE_USER=                    # Korisnik na udaljenoj lokaciji
REMOTE_ADDRESS=                 # Adresa udaljene lokacije
REMOTE_DIR=                     # Direktorij za spremanje na udaljenoj lokaciji

# Do not edit below this line
# Script
# Kreiraj backup direktorij, ako vec ne postoji
if [ -d $BACKUP_DIR ]
then
    echo "$BACKUP_DIR vec postoji na racunalu"
else
    mkdir $BACKUP_DIR
fi
# Kreiraj drugi backup direktorij, ako vec ne postoji
if [ -d $DEST_DIR ]
then
    echo "$DEST_DIR vec postoji na racunalu"
else
    mkdir $DEST_DIR
fi
databases=`psql -U $BACKUP_USER -l -t | egrep -v 'postgres|template[01]' | awk '{print $1}'`
for i in $databases; do
    echo Running VACUUM on database $i
    vacuumdb -f -z -h localhost -U $BACKUP_USER $i >/dev/null 2>&1
    echo Dumping $i to $BACKUP_DIR$i\_$BACKUP_DATE
    pg_dump -h localhost -U $BACKUP_USER -Z 9 -Fp $i > $BACKUP_DIR$BACKUP_DATE\_$i\.arh.gz
done

# Delete old databases
find $BACKUP_DIR -type f -prune -mtime +$NUMBER_OF_DAYS -exec rm -f {} \; && echo "ARHIVIRANJE i VAKUMIRANJE napravljeno u `date`" >> $BACKUP_DIR$LOG_FILE

# Kopiranje na mjesto za backup na medij
if [ $SECOND_COPY = 1 ]; then
rsync -avz $BACKUP_DIR`date +%Y-%m-%d`*.arh.gz $DEST_DIR && echo "KOPIRANJE backupa u direktorij za snimanje napravljeno u `date`" >> $BACKUP_DIR$LOG_FILE
else
echo "KOPIRANJE na drugi disk NIJE UKLJUCENO" >> $BACKUP_DIR$LOG_FILE
fi

# Remote upload
if [ $REMOTE_UPLOAD = 1 ]; then
rsync --bwlimit=50 -avze ssh $BACKUP_DIR`date +%Y-%m-%d`*.arh.gz $REMOTE_USER@$REMOTE_ADDRESS:$REMOTE_DIR && echo "PRIJENOS arhiva baza na server u KNJIGOVODSTVO napravljeno u `date`" >> $BACKUP_DIR$LOG_FILE
else
echo "UPLOAD baza na udaljenu lokaciju NIJE UKLJUCENO" >> $BACKUP_DIR$LOG_FILE
fi

# Burn backup
if [ $BURN_BACKUP = 1 ]; then
mkisofs -iso-level 3 -J -R -o /tmp/backup.img $BACKUP_DIR >> $BACKUP_DIR$BURN_LOG
sleep 2;
cdrecord speed=8 dev=/dev/sr0 -v -dao -eject -data /tmp/backup.img >> $BACKUP_DIR$BURN_LOG && rm -f $BACKUP_DIR\*.gz && echo "BACKUP uspjesno napravljen na medij u `date`" >> $BACKUP_DIR$LOG_FILE
else
echo "BURN BACKUP na cd/dvd NIJE UKLJUCENO" >> $BACKUP_DIR$LOG_FILE
fi
