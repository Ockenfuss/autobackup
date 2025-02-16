#!/usr/bin/bash
#This script is normally called by a udev rule when a backup plate is connected.

#Settings:
CONFIG_FILE=/home/paul/Git/Autobackup/autobackup.conf

# Read directories from the config file
DIRS=$(grep -v '^LUKSKEY=' "$CONFIG_FILE")

#Input format: NAME-TYPE-DEVICE, e.g. "Autobackup1-encrypted-sda1"
NAME=$(echo $1 | cut -d '-' -f1)
TYPE=$(echo $1 | cut -d '-' -f2)
DEVICE=$(echo $1 | cut -d '-' -f3)
LOG=/tmp/autobackup.log
#export DISPLAY=:0
#export XAUTHORITY=/run/user/1000/gdm/Xauthority
#notify-send "Backup starting" "Backup plate \"$DEVICE\" detected. Starting inremental backup."
date +"%Y-%m-%d %H:%M:%S" >> $LOG
echo "Starting automatic backup to plate $NAME ($TYPE, device $DEVICE)" >> $LOG

id
#Check if a valid block device is given
if [ ! -b /dev/$DEVICE ]; then
    echo "Error: $DEVICE is not a block device!" | tee -a $LOG
    exit 1
fi
#Find the mountpoint of the device
MOUNTPOINT=$(findmnt -f -n -o TARGET /dev/$DEVICE)
#If not found: try to mount yourself
if [[ $? -gt 0 ]] || [[ -z $MOUNTPOINT ]]; then
    mkdir -p /mnt/$NAME
    #Normal disk (unencrypted)
    if [[ $TYPE = "normal" ]]; then
        #udisksctl mount -b /dev/$DEVICE >> $LOG
        mount /dev/$DEVICE /mnt/$NAME
        MOUNTPOINT=$(findmnt -f -n -o TARGET /dev/$DEVICE)
    #LUKS encrypted disk
    elif [[ $TYPE = "encrypted" ]]; then
        echo "found encrypted device. trying to mount..." >> $LOG
        LUKSKEY=$(grep '^LUKSKEY=' "$CONFIG_FILE" | cut -d '=' -f2)
        cryptsetup luksOpen --key-file $LUKSKEY /dev/$DEVICE $NAME
        if [ $? -ne 0 ]; then 
            echo "Failed to unlock $NAME ($DEVICE)" | tee -a $LOG
            exit 1
        fi
        mount /dev/mapper/$NAME /mnt/$NAME
        MOUNTPOINT=$(findmnt -f -n -o TARGET /dev/mapper/$NAME)
    fi
fi
#Check if device is mounted
if [ -z $MOUNTPOINT ]; then
    echo "Error: Could not mount device $DEVICE!" | tee -a $LOG
    exit 1
fi
echo "mountpoint of $DEVICE is $MOUNTPOINT" >> $LOG

#Check if $MOUNTPOINT contains only one entry
if [ `echo $MOUNTPOINT | wc -l` -ne 1 ]; then
    echo "Error: found more than one mountpoint. This should not happen." | tee -a $LOG
    exit 1
fi

#Create a directory for the backup if necessary and start the incremental backup
mkdir -p $MOUNTPOINT/Autobackup
while IFS= read -r dir; do
    # echo "DEBUG: $dir" >> $LOG
    backup -v -b $MOUNTPOINT/Autobackup "$dir" >>$LOG
done <<< "$DIRS"

#Reporting remaining disk space
USED_SPACE=$(df --output=used -h $MOUNTPOINT | tail -n 1)
TOTAL_SPACE=$(df --output=size -h $MOUNTPOINT | tail -n 1)
FRACTION_SPACE=$(df --output=pcent -h $MOUNTPOINT | tail -n 1)
echo "Total disk space used on device: $USED_SPACE of $TOTAL_SPACE ($FRACTION_SPACE)" >> $LOG

#Umnount the plate
echo "Unmounting $MOUNTPOINT" >> $LOG
umount -l $MOUNTPOINT
#Optionally power off the device. Comment this line, if you want to remount the plate after the backup manually.
#udisksctl power-off -b /dev/$DEVICE >> $LOG
sleep 1
#remove directory if empty
rmdir $MOUNTPOINT
if [[ $TYPE = "encrypted" ]]; then
    cryptsetup luksClose /dev/mapper/$NAME
    echo "Closed encrypted device $DEVICE" >> $LOG
fi

#notify-send "Backup successful" "See /tmp/autobackup.log for details."
echo "Done with backup." >> $LOG
echo "You can turn off the device now using \"udisksctl power-off -b /dev/$DEVICE\"." >> $LOG
echo "To remount the device, call the following commands:" >> $LOG
echo "mkdir /mnt/backup_to_read" >> $LOG
if [[ $TYPE = "encrypted" ]]; then
    echo "sudo cryptsetup luksOpen --key-file $LUKSKEY /dev/$DEVICE $NAME" >> $LOG
    echo "sudo mount -o ro /dev/mapper/$NAME /mnt/backup_to_read" >> $LOG
    echo "To close:"
    echo "sudo umount /mnt/backup_to_read"
    echo "sudo cryptsetup luksClose /dev/mapper/$NAME"
else
    echo "sudo mount -o ro /dev/$DEVICE /mnt/backup_to_read" >> $LOG
fi
exit 0