#!/usr/bin/env bash

# Bash Strict Mode
set -euo pipefail
IFS=$'\n\t'

if [[ $(id -u) -ne 0 ]]; then
  echo "Please run this script as root"
  exit 1
fi

# Set the console keyboard layout
loadkeys uk

echo "#==============================================================================="
echo "# Specify system's fully qualified domain name (FQDN):                         #"
echo "#==============================================================================="

read -r -p "Fully Qualified Domain Name: " sys_fqdn
echo
if [[ -z "$sys_fqdn" ]]; then
  echo "ERROR: No system FQDN was specified!"
  exit 1
fi

echo

echo "#==============================================================================="
echo "# Specify LUKS password: (will not be echoed to screen)                        #"
echo "#==============================================================================="

read -r -s -p "Password: " luks_password
echo
if [[ -z "$luks_password" ]]; then
  echo "ERROR: No LUKS password was specified!"
  exit 1
fi

echo

# Display a list of devices with the count number
echo "#==============================================================================="
echo "# Available disk devices                                                       #"
echo "#==============================================================================="

# Get list of devices
devices=$(lsblk -n -o PATH,TYPE,SIZE | grep -e ' disk ' | cut -d' ' -f1)

count=0

for string in $devices
do
  count=$((count+1))
  echo "($count) $(lsblk -n -o PATH,MAJ:MIN,TYPE,SIZE,VENDOR,MODEL,SERIAL "$string" | grep -e ' disk ')"
  # Create shell variables named $deviceNN for each device
  eval device$count="$string"
done

echo

while :; do
  read -r -p "Select a device to WIPE and install on: " device_num
  [[ $device_num =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((device_num >= 1 && device_num <= count)); then
    break
  else
    echo "Number out of range, try again"
  fi
done

device=""
eval device="\$device$device_num"
device_map_name="${device##*/}"
device_part="${device}$( if [[ "$device" =~ "nvme" ]]; then echo "p"; fi )"
device_map_name="${device_map_name}$( if [[ "$device_map_name" =~ "nvme" ]]; then echo "p"; fi )"

echo "Selected device = $device"

echo

echo "#==============================================================================="
echo "# The selected device's partition layout pre-setup is:                         #"
echo "#==============================================================================="

sgdisk --pretend --print "$device"

echo

echo "#==============================================================================="
echo "# ALL INFORMATION ON SELECTED DEVICE WILL BE WIPED (no further prompts!)       #"
echo "#==============================================================================="

read -r -p "WARNING: About to wipe $device. Continue (y/n)? " answer

if [ "$answer" != "${answer#[Yy]}" ] ;then 
  echo "Proceeding..."
else
  echo "Exiting..."
  exit 1
fi

echo

echo "#==============================================================================="
echo "# Creating partitions                                                          #"
echo "#==============================================================================="

# For partition type codes see:
# - https://sourceforge.net/p/gptfdisk/code/ci/master/tree/parttypes.cc#l142
# - https://www.freedesktop.org/software/systemd/man/systemd-gpt-auto-generator.html
#
# The set:63 partition attribute is to prevent GPT partition automounting.
sgdisk --zap-all "$device"
sgdisk --clear "$device"
sgdisk --attributes=1:set:63 --align-end --new=1:0:+1G --typecode=1:ef00 --change-name=1:EFI    "$device"
sgdisk --attributes=2:set:63 --align-end --new=2:0:0   --typecode=2:8304 --change-name=2:ROOTFS "$device"

echo

echo "#==============================================================================="
echo "# The selected device's partition layout post-setup is:                        #"
echo "#==============================================================================="

sgdisk --pretend --print "$device"

echo

echo "#==============================================================================="
echo "# Initialising the LUKS volumes                                                #"
echo "#==============================================================================="

echo -n "$luks_password" | cryptsetup luksFormat --iter-time 5000 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --type luks2 --pbkdf argon2id --use-random "${device_part}2" -d -

echo

echo "#==============================================================================="
echo "# Opening the LUKS volumes                                                     #"
echo "#==============================================================================="

echo -n "$luks_password" | cryptsetup open --type luks2 --allow-discards "${device_part}2" "${device_map_name}2_crypt" -d -

echo

echo "#==============================================================================="
echo "# Creating the file systems                                                    #"
echo "#==============================================================================="

mkfs.fat -F 32 -n EFI "${device_part}1"
mkfs.btrfs -L ROOT "/dev/mapper/${device_map_name}2_crypt"

echo

echo "#==============================================================================="
echo "# Setting up BTRFS subvolume layout and mounting partitions                    #"
echo "#==============================================================================="

mkdir -p /mnt/btrfs_root
mount -t btrfs -o defaults,rw,noatime,nodiratime,compress-force=zstd:2 "/dev/mapper/${device_map_name}2_crypt" /mnt/btrfs_root
btrfs subvolume create /mnt/btrfs_root/@rootfs
btrfs subvolume create /mnt/btrfs_root/@homefs
btrfs subvolume create /mnt/btrfs_root/@swap
mkdir -p /mnt/btrfs_root/btrbk_snapshots
umount /mnt/btrfs_root
rmdir /mnt/btrfs_root

mkdir -p /mnt
mount -t btrfs -o defaults,rw,noatime,nodiratime,compress-force=zstd:2,subvol=@rootfs "/dev/mapper/${device_map_name}2_crypt" /mnt

mkdir -p /mnt/efi
mount -t vfat -o defaults,umask=0077 "${device_part}1" /mnt/efi

mkdir -p /mnt/home
mount -t btrfs -o defaults,rw,noatime,nodiratime,compress-force=zstd:2,subvol=@homefs "/dev/mapper/${device_map_name}2_crypt" /mnt/home

mkdir -p /mnt/swap
# From btrfs(5) "within a single file system, it is not possible to mount some
# subvolumes with nodatacow and others with datacow. The mount option of the
# first mounted subvolume applies to any other subvolumes." So the nodatacow
# option in the line below has no effect.
mount -t btrfs -o defaults,rw,noatime,nodiratime,nodatacow,subvol=@swap "/dev/mapper/${device_map_name}2_crypt" /mnt/swap
chattr +C /mnt/swap
btrfs filesystem mkswapfile --size 8g --uuid clear /mnt/swap/swapfile
chown -R root:root /mnt/swap
chmod -R og-rwx /mnt/swap
swapon /mnt/swap/swapfile

echo

echo "#==============================================================================="
echo "# Set up the /etc/pacman.d/mirrorlist file via reflector                       #"
echo "#==============================================================================="

# Mirrors I trust:
# - archlinux.mirrors.ovh.net - Large hosting provider, France
# - dist-mirror.fem.tu-ilmenau.de - Ilmenau University of Technology, Germany
# - ftp.fau.de - University of Erlangen-Nuremberg, Germany
# - ftp.spline.inf.fu-berlin.de - Free University of Berlin, Germany
# - mirror.informatik.tu-freiberg.de - Freiberg University, Germany
# - mirror.umd.edu - The University of Maryland, United States of America
# - mirrors.mit.edu - Massachusetts Institute of Technology, United States of America
# - mirrors.rit.edu - Rochester Institute of Technology, United States of America
# - packages.oth-regensburg.de - Regensburg University, Germany
# - plug-mirror.rcac.purdue.edu - Purdue University, United States of America
# - www.mirrorservice.org - University of Kent, United Kingdom
reflector --ipv4 --protocol https --country gb,fr,de,us --sort rate \
  --include '(archlinux\.mirrors\.ovh\.net|dist-mirror\.fem\.tu-ilmenau\.de|ftp\.fau\.de|ftp\.spline\.inf\.fu-berlin\.de|mirror\.informatik\.tu-freiberg\.de|mirror\.umd\.edu|mirrors\.mit\.edu|mirrors\.rit\.edu|packages\.oth-regensburg\.de|plug-mirror\.rcac\.purdue\.edu|www\.mirrorservice\.org)' \
  --save /etc/pacman.d/mirrorlist

echo

echo "#==============================================================================="
echo "# Install essential packages                                                   #"
echo "#==============================================================================="

pacstrap -K /mnt \
  base \
  btrfs-progs \
  cryptsetup \
  iptables-nft \
  iw \
  linux \
  linux-firmware \
  mkinitcpio \
  nano \
  networkmanager \
  wireless-regdb

echo

echo "#==============================================================================="
echo "# Configure hostname and hosts file                                            #"
echo "#==============================================================================="

echo "${sys_fqdn%%.*}" > /mnt/etc/hostname
chown root:root /mnt/etc/hostname
chmod 0644 /mnt/etc/hostname

cat << HOSTS_EOF > /mnt/etc/hosts
# Static table lookup for hostnames.
# See hosts(5) for details.

# Loopback entries; do not change.
# For historical reasons, localhost precedes localhost.localdomain:
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
127.0.1.1   ${sys_fqdn} ${sys_fqdn%%.*}
HOSTS_EOF
chown root:root /mnt/etc/hosts
chmod 0644 /mnt/etc/hosts

echo

echo "#==============================================================================="
echo "# Configuring the /etc/fstab & /etc/crypttab files                             #"
echo "#==============================================================================="

mkdir -p /mnt/media/cdrom
chown root:root /mnt/media/cdrom
chmod 0755 /mnt/media/cdrom

mkdir -p /mnt/mnt/btr_pool
chown root:root /mnt/mnt/btr_pool
chmod 0755 /mnt/mnt/btr_pool

FS_UUID_EFI=$(blkid -o value -s UUID "${device_part}1")
FS_UUID_ROOT=$(blkid -o value -s UUID "/dev/mapper/${device_map_name}2_crypt")

echo "Generating /etc/fstab"

cat << FSTAB_EOF > /mnt/etc/fstab
# /etc/fstab: static file system information.
#
# <file system>   <mount point>   <type>   <options>   <dump>   <pass>
# ---------------------------------------------------------------------------------------------------------------------------------------

# ROOT
/dev/disk/by-uuid/${FS_UUID_ROOT}   /   btrfs   defaults,noatime,nodiratime,compress-force=zstd:2,discard=async,subvol=/@rootfs   0   0

# HOME
/dev/disk/by-uuid/${FS_UUID_ROOT}   /home   btrfs   defaults,noatime,nodiratime,compress-force=zstd:2,discard=async,subvol=/@homefs   0   0

# BTRBK Snapshots
/dev/disk/by-uuid/${FS_UUID_ROOT}   /mnt/btr_pool   btrfs   defaults,noatime,nodiratime,compress-force=zstd:2,subvolid=5,discard=async,noauto,x-systemd.automount,x-systemd.idle-timeout=300   0   0

# SWAP
/dev/disk/by-uuid/${FS_UUID_ROOT}   /swap   btrfs   defaults,noatime,nodiratime,compress-force=zstd:2,discard=async,subvol=/@swap   0   0

# SWAP FILE
/swap/swapfile   none   swap   sw   0   0

# EFI
/dev/disk/by-uuid/${FS_UUID_EFI}   /efi   vfat   defaults,umask=0077   0   1

# CDROM
/dev/cdrom   /media/cdrom   udf,iso9660   defaults,user,noauto   0   0
FSTAB_EOF

chown root:root /mnt/etc/fstab
chmod 0644 /mnt/etc/fstab

mkdir -p /mnt/etc/luks
chown root:root /mnt/etc/luks
chmod 0700 /mnt/etc/luks

echo "Backing up LUKS headers"

echo -n "$luks_password" | cryptsetup luksHeaderBackup  "${device_part}2" --header-backup-file "/mnt/etc/luks/crypt_headers_${device_map_name}2_crypt.img" -d -
chown root:root /mnt/etc/luks/*
chmod 0600 /mnt/etc/luks/*

echo "Generating /etc/crypttab.initramfs"

cat << CRYPTTAB_EOF > /mnt/etc/crypttab.initramfs
${device_map_name}2_crypt  UUID=$(blkid -o value -s UUID "${device_part}2")  none  luks,discard,key-slot=0
CRYPTTAB_EOF

chown root:root /mnt/etc/crypttab.initramfs
chmod 0600 /mnt/etc/crypttab.initramfs

echo

echo "#==============================================================================="
echo "# Configuring kernel parameters                                                #"
echo "#==============================================================================="

mkdir -p /mnt/etc/cmdline.d
chown root:root /mnt/etc/cmdline.d
chmod 0755 /mnt/etc/cmdline.d

cat << ROOT_CONF_EOF > /mnt/etc/cmdline.d/root.conf
root=/dev/mapper/${device_map_name}2_crypt rootflags=subvol=/@rootfs rw
ROOT_CONF_EOF

cat << 'AUDIT_CONF_EOF' > /mnt/etc/cmdline.d/audit.conf
audit=1 audit_backlog_limit=32768
AUDIT_CONF_EOF

cat << 'SILENT_BOOT_CONF_EOF' > /mnt/etc/cmdline.d/silent_boot.conf
quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3
SILENT_BOOT_CONF_EOF

chown root:root \
  /mnt/etc/cmdline.d/audit.conf \
  /mnt/etc/cmdline.d/root.conf \
  /mnt/etc/cmdline.d/silent_boot.conf

chmod 0644 \
  /mnt/etc/cmdline.d/audit.conf \
  /mnt/etc/cmdline.d/root.conf \
  /mnt/etc/cmdline.d/silent_boot.conf

echo

echo "#==============================================================================="
echo "# CHROOT into the new system                                                   #"
echo "#==============================================================================="

arch-chroot /mnt /bin/bash <<'CHROOT_EOF'

# Bash Strict Mode
set -euo pipefail
IFS=$'\n\t'

echo "#==============================================================================="
echo "# Set the time zone                                                            #"
echo "#==============================================================================="

ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime

echo

echo "#==============================================================================="
echo "# Generate /etc/adjtime                                                        #"
echo "#==============================================================================="

hwclock --systohc

echo

echo "#==============================================================================="
echo "# Configure localization                                                       #"
echo "#==============================================================================="

sed -i -e 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g' /etc/locale.gen
sed -i -e 's/^#en_GB ISO-8859-1/en_GB ISO-8859-1/g' /etc/locale.gen

locale-gen

echo 'LANG=en_GB.UTF-8' > /etc/locale.conf
export LANG=en_GB.UTF-8
chown root:root /etc/locale.conf
chmod 0644 /etc/locale.conf

echo -e 'KEYMAP=uk' > /etc/vconsole.conf
chown root:root /etc/vconsole.conf
chmod 0644 /etc/vconsole.conf

# For now, SDDM/kwin seems to read the /etc/X11/xorg.conf.d/00-keyboard.conf
# file to figure out the keyboard layout. We can't run localectl inside this
# chroot and so are setting up the needed file manually.
#localectl --no-convert set-x11-keymap gb pc105
mkdir -p /etc/X11/xorg.conf.d

cat << 'KEYBOARD_CONF_EOF' > /etc/X11/xorg.conf.d/00-keyboard.conf
# Written by systemd-localed(8), read by systemd-localed and Xorg. It's
# probably wise not to edit this file manually. Use localectl(1) to
# update this file.
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "gb"
        Option "XkbModel" "pc105"
EndSection
KEYBOARD_CONF_EOF

chmod 0644 /etc/X11/xorg.conf.d/00-keyboard.conf
chmod 0755 \
  /etc/X11 \
  /etc/X11/xorg.conf.d
chown root:root \
  /etc/X11 \
  /etc/X11/xorg.conf.d \
  /etc/X11/xorg.conf.d/00-keyboard.conf

echo

echo "#==============================================================================="
echo "# Configure networking                                                         #"
echo "#==============================================================================="

# Enable the correct wireless regulatory domain
sed -i -e 's/^#WIRELESS_REGDOM="GB"/WIRELESS_REGDOM="GB"/g' /etc/conf.d/wireless-regdom

# Disable connectivity checking
cat << 'CONNECTIVITY_CONF_EOF' > /etc/NetworkManager/conf.d/20-connectivity.conf
[connectivity]
enabled=false
CONNECTIVITY_CONF_EOF
chown root:root /etc/NetworkManager/conf.d/20-connectivity.conf
chmod 0644 /etc/NetworkManager/conf.d/20-connectivity.conf

# Configure a unique DUID per connection
cat << 'DUID_CONF_EOF' > /etc/NetworkManager/conf.d/duid.conf
[connection]
ipv6.dhcp-duid=stable-uuid
DUID_CONF_EOF
chown root:root /etc/NetworkManager/conf.d/duid.conf
chmod 0644 /etc/NetworkManager/conf.d/duid.conf

# We don't want to use systemd-resolved
cat << 'NOSYSTEMDRESOLVED_CONF_EOF' > /etc/NetworkManager/conf.d/no-systemd-resolved.conf
[main]
systemd-resolved=false
NOSYSTEMDRESOLVED_CONF_EOF
chown root:root /etc/NetworkManager/conf.d/no-systemd-resolved.conf
chmod 0644 /etc/NetworkManager/conf.d/no-systemd-resolved.conf

echo

echo "#==============================================================================="
echo "# Configure initramfs                                                          #"
echo "#==============================================================================="

#
# - Placed the "keyboard" hook before autodetect in order to always include all
# keyboard drivers. Otherwise the external keyboard only works in early userspace
# if it was connected when creating the image.
#
# - Placed the sd-vconsole before sd-encrypt to allow use of non-US keymaps.
#
echo 'HOOKS=(base systemd keyboard autodetect microcode modconf kms sd-vconsole sd-encrypt block filesystems fsck)' > /etc/mkinitcpio.conf.d/myhooks.conf
chown root:root /etc/mkinitcpio.conf.d/myhooks.conf
chmod 0644 /etc/mkinitcpio.conf.d/myhooks.conf

echo 'MODULES=(usbhid xhci_hcd)' > /etc/mkinitcpio.conf.d/mymodules.conf
chown root:root /etc/mkinitcpio.conf.d/mymodules.conf
chmod 0644 /etc/mkinitcpio.conf.d/mymodules.conf

# Configure mkinitcpio to create Unified Kernel Images(UKI)
sed -i -e 's/^default_image=/#default_image="/g' /etc/mkinitcpio.d/linux.preset
sed -i -e 's/^#default_uki=/default_uki=/g' /etc/mkinitcpio.d/linux.preset
sed -i -e 's/^#default_options=/default_options=/g' /etc/mkinitcpio.d/linux.preset
sed -i -e 's/^fallback_image=/#fallback_image=/g' /etc/mkinitcpio.d/linux.preset
sed -i -e 's/^#fallback_uki=/fallback_uki=/g' /etc/mkinitcpio.d/linux.preset

# Create the directory in which the UKI will be installed
mkdir -p /efi/EFI/Linux

# Remove any old initramfs-*.img created during pacstrap
rm /boot/initramfs-*.img

# Generate the initramfs images based on all existing presets
mkinitcpio -P

echo

echo "#==============================================================================="
echo "# Install and configure bootloader                                             #"
echo "#==============================================================================="

bootctl install

cat << 'LOADER_CONF_EOF' > /efi/loader/loader.conf
default @saved
timeout 10
console-mode keep
editor no
LOADER_CONF_EOF

echo

echo "#==============================================================================="
echo "# Configure pacman                                                             #"
echo "#==============================================================================="

sed -i -e 's/^#Color/Color/g' /etc/pacman.conf
sed -i -e 's/^#VerbosePkgLists/VerbosePkgLists/g' /etc/pacman.conf
sed -i -e 's/^#ParallelDownloads/ParallelDownloads/g' /etc/pacman.conf
sed -i -z -e 's/#\[multilib\]\n#Include = \/etc\/pacman.d\/mirrorlist/[multilib]\nInclude = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf
sed -i -e 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/g' /etc/makepkg.conf

# Download the database files
pacman -Sy
pacman -Fy

echo

echo "#==============================================================================="
echo "# Configure btrfs maintenance tasks                                            #"
echo "#==============================================================================="

mkdir -p /etc/systemd/system/btrfs-scrub@.service.d/
chown root:root /etc/systemd/system/btrfs-scrub@.service.d/
chmod 0755 /etc/systemd/system/btrfs-scrub@.service.d/
cat << 'BTRFS_SCRUB_SERVICE_OVERRIDE_EOF' > /etc/systemd/system/btrfs-scrub@.service.d/override.conf
[Service]
CPUSchedulingPolicy=idle
ExecStart=
ExecStart=/usr/bin/bash -c 'echo "Starting btrfs scrub of %f"; /usr/bin/flock -x /var/lock/btrfs-maintenance.lock /usr/bin/btrfs scrub start -Bd %f;'
BTRFS_SCRUB_SERVICE_OVERRIDE_EOF

cat << 'BTRFS_BALANCE_SERVICE_EOF' > /etc/systemd/system/btrfs-balance@.service
[Unit]
Description=Balance block groups on a btrfs filesystem %f
ConditionPathIsMountPoint=%f
RequiresMountsFor=%f
After=fstrim.service btrfs-trim.service btrfs-scrub.service

[Service]
Nice=19
CPUSchedulingPolicy=idle
IOSchedulingClass=idle
KillSignal=SIGINT
# Source: https://www.mail-archive.com/linux-btrfs@vger.kernel.org/msg72375.html
ExecStart=/usr/bin/bash -c 'echo "Before balance of %f"; /usr/bin/btrfs filesystem df %f; /usr/bin/flock -x /var/lock/btrfs-maintenance.lock /usr/bin/btrfs balance start -v -dusage=25 -dlimit=2..10 -musage=25 -mlimit=2..10 %f; echo "After balance of %f"; /usr/bin/btrfs filesystem df %f;'
BTRFS_BALANCE_SERVICE_EOF

cat << 'BTRFS_BALANCE_TIMER_EOF' > /etc/systemd/system/btrfs-balance@.timer
[Unit]
Description=Weekly Btrfs balance on %f

[Timer]
OnCalendar=weekly
RandomizedDelaySec=12h
Persistent=true

[Install]
WantedBy=timers.target
BTRFS_BALANCE_TIMER_EOF

chown root:root \
  /etc/systemd/system/btrfs-balance@.service \
  /etc/systemd/system/btrfs-balance@.timer \
  /etc/systemd/system/btrfs-scrub@.service.d/override.conf

chmod 0644 \
  /etc/systemd/system/btrfs-balance@.service \
  /etc/systemd/system/btrfs-balance@.timer \
  /etc/systemd/system/btrfs-scrub@.service.d/override.conf

echo

echo "#==============================================================================="
echo "# Configure auditd                                                             #"
echo "#==============================================================================="

# Set max size of /var/log/audit/audit.log files to 100mb
sed -i -e 's/max_log_file = [0-9]*/max_log_file = 100/g' /etc/audit/auditd.conf

echo

echo "#==============================================================================="
echo "# Enable services                                                              #"
echo "#==============================================================================="

systemctl enable auditd.service
systemctl enable NetworkManager.service
systemctl enable systemd-boot-update.service
systemctl enable systemd-timesyncd.service

systemctl enable btrfs-balance@-.timer
systemctl enable btrfs-scrub@-.timer

echo

echo "#==============================================================================="
echo "# Setup users                                                                  #"
echo "#==============================================================================="

# Set up temporary root password
echo -e "Passw0rd\nPassw0rd" | passwd

# Set up my user with a temporary password
useradd -m jc
echo -e "Passw0rd\nPassw0rd" | passwd jc

echo

CHROOT_EOF

cd
sync
swapoff /mnt/swap/swapfile
umount -R /mnt/swap
umount -R /mnt/home
umount -R /mnt/efi
umount -R /mnt
