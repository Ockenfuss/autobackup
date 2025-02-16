# Autobackup
Automatic incremental backups using rsync

`Autobackup` allows you to create incremental backups on specific hard drives, as soon as they are connected to the system. It is based completely on standard linux tools.

## Incremental backups
With rsync, it is possible to create hard links to files, if they already exist in another directory. This allows to track changes in big directory structures, without the necessity to create independent copies of the full database each time. `backup.sh` provides a tool for that. You can remove (`rm`) older versions of your data anytime, without affecting the other copies, since the linux filesystem does not actually overwrite any files as long as at least one hard link exists to them.

## Automatic execution
If one of your backup drives is connected to the system, this is detected by a `udev` rule (`80-backup.rules`). `udev` then starts a `systemd` unit (`autobackup@.service`) in the background, which calls `autobackup.sh` to perform the backup. `autobackup.sh` mounts the hard drive using the name given from `udev`, makes a backup of your folders using `backup.sh` and unmounts the drive afterwards.

## Installation
- It is best if you deactivate the automounting for the drives. Therefore, make an entry like `UUID=29af023f-df9f-48ee-aced-61ffbdaba804 /mnt/autobackup1 auto noauto 0 0` in /etc/fstab. You can find the UUID from `ll /dev/disk/by-uuid/`.
- You need to register your drive to be mounted in `80-backup.rules` by providing a set of unique attributes to this piece of hardware, e.g. the serial number, the vendor or the device type. You can find available attributes by using the command 
```bash
udevadm info -a -n /dev/sda
``` 
Afterwards, execute `install.sh` as root. The backup will be executed as root as well and the drive mounted as read only for non-root users
- All configurations are done via a `autobackup.conf` file. The location of this file needs to be specified at the top of the `autobackup.sh` script.

## Configuration
The directories to be backed up are defined via a file `autobackup.conf`. You can place it anywhere, as long as you specify the location at the beginning of the `autobackup.sh` script.
```txt
LUKSKEY=/path/to/lukskey
/path/to/dir1
/path/to/dir2
```

## Backups
They are started once you plug in the drive. You can monitor the progress via the logfile in `/tmp/autobackup.log`. Once finished, the drive is automatically unmounted. You can power it of before plugging out via 
```bash
udisksctl power-off -b /dev/sda1
```

## Restore Backups
If not encrypted, the backups are directly readable as normal files on the drives. On any other computer, they should be mounted normally. Since on this computer, the automounting is deactivated, you have to mount the plate manually. After the backup finished, you can remount the plate using the following commands:
```bash
mkdir /mnt/backup_to_read
sudo mount -o ro /dev/sda1 /mnt/backup_to_read #instead of sda1, use the name which is printed after the backup finished. -o ro: read only mount
#after you are finished:
sudo umount /mnt/backup_to_read
udisksctl power-off -b /dev/sda1
```

## Encryption
Optionally, you can encrypt the external drive e.g. using LUKS. To prepare the hard drive, follow this manual: https://wiki.ubuntuusers.de/LUKS/Partitionen_verschl%C3%BCsseln/
To open the drive, `autobackup.sh` expects a keyfile to use with `cryptsetup luksOpen --key-file ...`. The location of the key file can be configured via the `autobackup.conf` file. In the udev rule, you need to switch the drive type from 'normal' to 'encrypted'.

## Inspiration
This project was inspired by the following webpages:
- https://www.sanitarium.net/golug/rsync_backups_2010.html
- https://www.admin-magazine.com/Articles/Using-rsync-for-Backups