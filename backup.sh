#! /usr/bin/bash
#Making incremental backups with rsync.
#Usage: backup -b BackupDir DirToBackup
#DirToBackup: A directory to backup
#-b DIR: A directory where the last backups are located. Their names are expected to have the form "nameFORMAT", where "name" is the name of the directory you want to backup now and FORMAT is a date and timestamp.
#-v: verbose output
#-i: interactive. Confirm before backup. Triggers -v as well.
while getopts vib: opt; do
	case $opt in
		b) BACKUP=`realpath $OPTARG`;;
		i) VERBOSE=v;INTERACTIVE=i;;
		v) VERBOSE=v;;
	esac
done
shift $[ $OPTIND -1 ]
[ -z $BACKUP ] && echo 'no backup directory specified.' && exit 1
SOURCE=`realpath $1`
FORMAT='_%Y_%m_%d_%H%M%S'
if [[ $VERBOSE ]]; then
	echo "Directory to backup: $SOURCE"
	echo "Backup location: $BACKUP"
fi

find_last() {
#Find the most recent folder of the format "nameFORMAT" in the current directory.
#Input: "name"
	ls | egrep "$1_[0-9]{4}_[0-9]{2}_[0-9]{2}_[0-9]{6}$" | sort | tail -n 1
}
cd $BACKUP
`basename $SOURCE | echo`
PREFIX=`basename $SOURCE`
LAST=`find_last $PREFIX`
NEW=$BACKUP/`basename $SOURCE``date +$FORMAT`
if [[ $VERBOSE ]]; then
	if [[ -d $LAST ]]; then
		echo "Previous backup directory found: $LAST"
	else
		echo "No previous backup directory found. Creating an independent copy."
	fi
fi
if [[ $INTERACTIVE ]]; then
	read -p "Do you want to start the backup? (y/n)" CHOICE
	case $CHOICE in
		[yY]);;
		[nN]) exit 1;;
		*) echo "Please answer y or n."; exit 1;;
	esac
fi
if [[ -d $LAST ]]; then
	rsync -a$VERBOSE --link-dest=$BACKUP/$LAST $SOURCE $NEW
else
	rsync -a$VERBOSE $SOURCE $NEW
fi







