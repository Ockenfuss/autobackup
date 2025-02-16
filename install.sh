pwd
cp -i 80-autobackup.rules /etc/udev/rules.d
cp -i autobackup@.service /etc/systemd/system
cp -i backup.sh /usr/local/bin/backup
cp -i autobackup.sh /usr/local/bin/autobackup 
udevadm control --reload