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
  wireless-regdb \
  xfsprogs

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
# The following is needed for steam runtime
sed -i -e 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
sed -i -e 's/^#en_US ISO-8859-1/en_US ISO-8859-1/g' /etc/locale.gen


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
echo "# Install base packages                                                        #"
echo "#==============================================================================="

pacman -S --noconfirm --noprogressbar \
  arch-audit \
  aria2 \
  atop \
  bandwhich \
  bash-completion \
  bat \
  bind \
  bmon \
  bottom \
  broot \
  btrbk \
  bzip3 \
  chezmoi \
  cifs-utils \
  compsize \
  dhex \
  dmidecode \
  dog \
  dos2unix \
  dosfstools \
  duf \
  dust \
  efibootmgr \
  ethtool \
  exfatprogs \
  eza \
  fakeroot \
  fd \
  fdupes \
  fish \
  fisher \
  fortune-mod \
  fzf \
  geoipupdate \
  git \
  git-delta \
  git-lfs \
  go-yq \
  htop \
  hunspell \
  hunspell-en_gb \
  hyperfine \
  iftop \
  inetutils \
  iotop-c \
  ipcalc \
  jq \
  lbzip2 \
  less \
  libfido2 \
  logrotate \
  lrzip \
  lshw \
  lsof \
  ltrace \
  lzip \
  lzop \
  mailcap \
  man-db \
  man-pages \
  mbuffer \
  mc \
  msmtp \
  msmtp-mta \
  mtr \
  ncdu \
  net-tools \
  nethogs \
  nmap \
  ntfs-3g \
  openbsd-netcat \
  openssh \
  p7zip \
  pacman-contrib \
  patchutils \
  perl \
  pigz \
  pixz \
  pkgfile \
  plocate \
  procs \
  python3 \
  qemu-guest-agent \
  ripgrep \
  rsync \
  s-nail \
  shared-mime-info \
  shfmt \
  sipcalc \
  strace \
  sudo \
  tailspin \
  tcpdump \
  tealdeer \
  testssl.sh \
  tmux \
  traceroute \
  tree \
  trippy \
  ttyd \
  unrar \
  unzip \
  usbutils \
  vim \
  w3m \
  wakeonlan \
  wget \
  which \
  whois \
  wireguard-tools \
  words \
  zip

echo

echo "#==============================================================================="
echo "# Install hardware support packages                                            #"
echo "#==============================================================================="

if [ -f /sys/devices/virtual/dmi/id/board_name ]; then
  board_name="$(cat /sys/devices/virtual/dmi/id/board_name)"
else
  board_name=""
fi

if [ -f /sys/devices/virtual/dmi/id/board_vendor ]; then
  board_vendor="$(cat /sys/devices/virtual/dmi/id/board_vendor)"
else
  board_vendor=""
fi

case "$board_vendor" in

  "TUXEDO" | "Micro-Star International Co., Ltd." | "SAMSUNG ELECTRONICS CO., LTD.")

    # Common hardware packages
    pacman -S --noconfirm --noprogressbar \
      bluez \
      bluez-obex \
      bluez-utils \
      cpupower \
      cups \
      cups-pdf \
      lm_sensors \
      pipewire \
      pipewire-alsa \
      pipewire-jack \
      pipewire-pulse \
      rtkit \
      smartmontools

    if [[ "$board_name" = "P95_96_97Ex,Rx" ]]; then

      # Clevo XP1610 Laptop
      pacman -S --noconfirm --noprogressbar \
        intel-gpu-tools \
        intel-media-driver \
        intel-ucode \
        lib32-nvidia-utils \
        lib32-vulkan-intel \
        libva-intel-driver \
        libva-nvidia-driver \
        libva-utils \
        libvdpau-va-gl \
        mesa \
        mesa-utils \
        nvidia-open \
        nvidia-prime \
        nvidia-settings \
        nvidia-utils \
        nvtop \
        powertop \
        tlp \
        vdpauinfo \
        vulkan-icd-loader \
        vulkan-intel \
        vulkan-mesa-layers \
        vulkan-tools

    fi

    if [[ "$board_name" = "MEG X570 ACE (MS-7C35)" ]]; then

      # MSI MEG X570 ACE Motherboard Desktop
      pacman -S --noconfirm --noprogressbar \
        amd-ucode \
        lib32-vulkan-radeon \
        libva-mesa-driver \
        libva-utils \
        libvdpau-va-gl \
        mesa \
        mesa-utils \
        mesa-vdpau  \
        nvtop \
        radeontop \
        vdpauinfo \
        vulkan-icd-loader \
        vulkan-mesa-layers \
        vulkan-radeon \
        vulkan-tools

    fi

    if [[ "$board_name" = "SAMSUNG_NP1234567890" ]]; then

      # Samsung Series 9 NP900X4C Laptop
      # Note: When setting up wireless connection in NM, you need to set the
      # wireless security to "WPA/WPA2 Personal". The default is "WPA3 
      # Personal" which doesn't work and you will get a "nl80211: kernel
      # reports: key setting validation failed" error.
      # Relevant threads:
      # - https://gitlab.freedesktop.org/NetworkManager/NetworkManager/-/issues/964
      # - https://groups.google.com/g/linux.debian.bugs.dist/c/EDqc_hzb0sQ
      # - https://lists.infradead.org/pipermail/hostap/2022-February/040230.html
      # - https://bbs.archlinux.org/viewtopic.php?id=273651
      pacman -S --noconfirm --noprogressbar \
        intel-gpu-tools \
        intel-media-driver \
        intel-ucode \
        lib32-vulkan-intel \
        libva-intel-driver \
        libva-mesa-driver \
        libva-utils \
        libvdpau-va-gl \
        mesa \
        mesa-utils \
        mesa-vdpau  \
        nvtop \
        powertop \
        tlp \
        vdpauinfo \
        vulkan-icd-loader \
        vulkan-intel \
        vulkan-mesa-layers \
        vulkan-tools

    fi

    ;;

  *)

    # Else assume we are in a VM and use generic hardware support
      pacman -S --noconfirm --noprogressbar \
        amd-ucode \
        intel-ucode \
        lib32-vulkan-mesa-layers \
        lib32-vulkan-swrast \
        lib32-vulkan-virtio \
        libva-mesa-driver \
        libva-utils \
        libvdpau-va-gl \
        mesa \
        mesa-utils \
        mesa-vdpau  \
        nvtop \
        qemu-guest-agent \
        spice-vdagent \
        vdpauinfo \
        vulkan-icd-loader \
        vulkan-mesa-layers \
        vulkan-swrast \
        vulkan-tools \
        vulkan-virtio

    ;;
esac

echo

echo "#==============================================================================="
echo "# Install desktop packages                                                     #"
echo "#==============================================================================="

# Fonts
pacman -S --noconfirm --noprogressbar \
  adobe-source-sans-fonts \
  adobe-source-serif-fonts \
  noto-fonts \
  noto-fonts-cjk \
  noto-fonts-emoji \
  noto-fonts-extra \
  otf-latin-modern \
  otf-latinmodern-math \
  ttf-hack-nerd \
  ttf-iosevkaterm-nerd \
  ttf-jetbrains-mono-nerd \
  ttf-roboto \
  ttf-roboto-mono-nerd

# KDE Plasma Desktop
pacman -S --noconfirm --noprogressbar \
  ark \
  bluedevil \
  dolphin \
  dolphin-plugins \
  ffmpegthumbs \
  filelight \
  gnuchess \
  gwenview \
  kamera \
  kate \
  kcalc \
  kcharselect \
  kclock \
  kcolorchooser \
  kde-gtk-config \
  kde-inotify-survey \
  kdebugsettings \
  kdegraphics-thumbnailers \
  kdeplasma-addons \
  kdialog \
  kdiff3 \
  keditbookmarks \
  kfind \
  kgraphviewer \
  khelpcenter \
  kigo \
  kimageformats \
  kinfocenter \
  kio-admin \
  kjournald \
  kmahjongg \
  knights \
  konsole \
  konversation \
  kpat \
  krdc \
  krdp \
  krecorder \
  krfb \
  kscreen \
  ksshaskpass \
  ksudoku \
  ksystemlog \
  kwallet-pam \
  kwalletmanager \
  kweather \
  kwrited \
  libappimage \
  markdownpart \
  okular \
  partitionmanager \
  plasma-desktop \
  plasma-disks \
  plasma-nm \
  plasma-pa \
  plasma-systemmonitor \
  plasma-thunderbolt \
  powerdevil \
  print-manager \
  qt6-imageformats \
  qt6-multimedia-ffmpeg \
  sddm-kcm \
  skanpage \
  spectacle \
  speech-dispatcher \
  svgpart \
  tesseract-data-eng \
  tesseract-data-guj \
  tesseract-data-hin \
  yakuake

# Flatpak
pacman -S --noconfirm --noprogressbar \
  flatpak \
  flatpak-kcm

# Orthodox file manager
pacman -S --noconfirm --noprogressbar \
  doublecmd-qt6 \
  ffmpegthumbnailer \
  libunrar

# Web browser and email client
pacman -S --noconfirm --noprogressbar \
  firefox \
  firefox-i18n-en-gb \
  libotr \
  thunderbird \
  thunderbird-i18n-en-gb

# Office suite
pacman -S --noconfirm --noprogressbar \
  beanshell \
  coin-or-mp \
  gst-libav \
  gst-plugins-bad \
  gst-plugins-good \
  gst-plugins-ugly \
  jdk-openjdk \
  libmythes \
  libreoffice-fresh \
  libreoffice-fresh-en-gb \
  libwpg \
  mythes-en \
  postgresql-libs \
  rhino \
  sane-airscan \
  unixodbc

# Password manager
pacman -S --noconfirm --noprogressbar \
  keepassxc \
  wl-clipboard \
  xclip

# Image editor
pacman -S --noconfirm --noprogressbar \
  gimp \
  gimp-help-en_gb \
  gimp-plugin-gmic \
  libwmf

# Scientific calculator
pacman -S --noconfirm --noprogressbar \
  qalculate-qt

# BitTorrent client
pacman -S --noconfirm --noprogressbar \
  qbittorrent

# Media player
pacman -S --noconfirm --noprogressbar \
  mpv \
  mpv-mpris

# Video downloader
pacman -S --noconfirm --noprogressbar \
  atomicparsley \
  python-brotli \
  python-mutagen \
  python-pycryptodomex \
  python-secretstorage \
  python-websockets \
  python-xattr \
  yt-dlp

# Video recording and live streaming
pacman -S --noconfirm --noprogressbar \
  linux-headers \
  obs-studio \
  sndio \
  v4l2loopback-dkms \
  v4l2loopback-utils

# Video editor
pacman -S --noconfirm --noprogressbar \
  gavl \
  opusfile \
  qtractor \
  rtaudio \
  sdl12-compat \
  sdl_image \
  shotcut \
  sox \
  swh-plugins

# Docker / Kubernetes / Terraform
pacman -S --noconfirm --noprogressbar \
  dive \
  docker \
  docker-buildx \
  docker-compose \
  docker-scan \
  helm \
  kubectl \
  kubetui \
  kustomize \
  minikube \
  packer \
  stern \
  terraform \
  terragrunt

# Virtualisation
pacman -S --noconfirm --noprogressbar \
  dnsmasq \
  qemu-desktop \
  qemu-tools \
  virt-manager

# Command-line translator
pacman -S --noconfirm --noprogressbar \
  rlwrap \
  translate-shell

# Gaming
pacman -S --noconfirm --noprogressbar \
  gamescope \
  goverlay \
  lib32-mangohud \
  steam

# Slack / Dropbox dependencies
pacman -S --noconfirm --noprogressbar \
  libappindicator-gtk3 \
  perl-file-mimeinfo

# Offline Arch Wiki
pacman -S --noconfirm --noprogressbar \
  arch-wiki-docs

# RSSGuard
pacman -S --noconfirm --noprogressbar \
  nodejs \
  npm \
  rssguard

# Android development
pacman -S --noconfirm --noprogressbar \
  gradle \
  gradle-doc \
  groovy-docs \
  jdk8-openjdk

# Zed text editor
pacman -S --noconfirm --noprogressbar \
  zed

# Wine
pacman -S --noconfirm --noprogressbar \
  dosbox \
  lib32-giflib \
  lib32-gnutls \
  lib32-gst-plugins-base-libs \
  lib32-gtk3 \
  lib32-libpulse \
  lib32-libva \
  lib32-libxcomposite \
  lib32-libxinerama \
  lib32-ocl-icd \
  lib32-sdl2 \
  lib32-v4l-utils \
  wine-staging

# Picard (Official MusicBrainz tagger)
pacman -S --noconfirm --noprogressbar \
  picard \
  qt5-multimedia

# Retroarch
pacman -S --noconfirm --noprogressbar \
  gamemode \
  libretro-beetle-pce \
  libretro-beetle-pce-fast \
  libretro-beetle-psx \
  libretro-beetle-psx-hw \
  libretro-beetle-supergrafx \
  libretro-blastem \
  libretro-bsnes \
  libretro-bsnes-hd \
  libretro-bsnes2014 \
  libretro-citra \
  libretro-core-info \
  libretro-desmume \
  libretro-dolphin \
  libretro-flycast \
  libretro-gambatte \
  libretro-genesis-plus-gx \
  libretro-kronos \
  libretro-mame \
  libretro-mame2016 \
  libretro-melonds \
  libretro-mesen \
  libretro-mesen-s \
  libretro-mgba \
  libretro-mupen64plus-next \
  libretro-nestopia \
  libretro-overlays \
  libretro-parallel-n64 \
  libretro-pcsx2 \
  libretro-picodrive \
  libretro-play \
  libretro-ppsspp \
  libretro-retrodream \
  libretro-sameboy \
  libretro-scummvm \
  libretro-shaders-slang \
  libretro-snes9x \
  libretro-yabause \
  retroarch \
  retroarch-assets-glui \
  retroarch-assets-ozone \
  retroarch-assets-xmb

# Signal
pacman -S --noconfirm --noprogressbar \
  signal-desktop

echo

echo "#==============================================================================="
echo "# Desktop configuration                                                        #"
echo "#==============================================================================="

mkdir -p /etc/sddm.conf.d
chown root:root /etc/sddm.conf.d
chmod 0755 /etc/sddm.conf.d

# Configure SDDM's display server to be Wayland
cat << 'SDDM_WAYLAND_CONF_EOF' > /etc/sddm.conf.d/10-wayland.conf
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1
SDDM_WAYLAND_CONF_EOF

# Configure SDDM's default theme
cat << 'SDDM_THEME_CONF_EOF' > /etc/sddm.conf.d/20-theme.conf
[Theme]
Current=breeze
CursorTheme=breeze_cursors
SDDM_THEME_CONF_EOF

# Docker: Configure docker daemon
mkdir -p /etc/docker
cat << 'DAEMON_JSON_EOF' > /etc/docker/daemon.json
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "100m",
    "max-file": "10"
  }
}
DAEMON_JSON_EOF

chown root:root /etc/docker
chmod 0755 /etc/docker

# Docker: Enable native overlay diff engine
cat << 'DISABLE_OVERLAY_REDIRECT_DIR_CONF_EOF' > /etc/modprobe.d/disable-overlay-redirect-dir.conf
# Used by docker to avoid issue:
#
#  Not using native diff for overlay2, this may cause degraded performance for building images: 
#  kernel has CONFIG_OVERLAY_FS_REDIRECT_DIR enabled
#
# Source: https://stackoverflow.com/questions/46787983/what-does-native-overlay-diff-mean-in-overlay2-storage-driver

options overlay metacopy=off redirect_dir=off
DISABLE_OVERLAY_REDIRECT_DIR_CONF_EOF

chown root:root \
  /etc/docker/daemon.json \
  /etc/modprobe.d/disable-overlay-redirect-dir.conf \
  /etc/sddm.conf.d/10-wayland.conf \
  /etc/sddm.conf.d/20-theme.conf

chmod 0644 \
  /etc/docker/daemon.json \
  /etc/modprobe.d/disable-overlay-redirect-dir.conf \
  /etc/sddm.conf.d/10-wayland.conf \
  /etc/sddm.conf.d/20-theme.conf

# Configure libvirtd to use the iptables firewall backend
sed -i -e 's/^#firewall_backend = "nftables"/firewall_backend = "iptables"/g' /etc/libvirt/network.conf

# Autostart default network interface. Can't use virsh in the chroot and so
# setup the symlink manually.
#virsh net-autostart default
ln -s /etc/libvirt/qemu/networks/default.xml /etc/libvirt/qemu/networks/autostart/default.xml

# Add the official Flathub repository
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo

echo "#==============================================================================="
echo "# Configure btrbk                                                              #"
echo "#==============================================================================="

cat << 'BTRBK_CONF_EOF' > /etc/btrbk/btrbk.conf
btrfs_commit_delete       yes
lockfile                  /var/lock/btrbk.lock
snapshot_preserve         14d
snapshot_preserve_min     1d
stream_buffer             512m
stream_compress           zstd
stream_compress_level     9
timestamp_format          long-iso
transaction_log           /var/log/btrbk.log

# Don't remove the #root comments below. They are used by btrbk-pac scripts.
volume /mnt/btr_pool                   # root
  snapshot_dir     btrbk_snapshots     # root
  subvolume        @rootfs             # root
BTRBK_CONF_EOF

mkdir -p /etc/btrbk_logger
cat << 'BTRBK_LOGGER_CONF_EOF' > /etc/btrbk_logger/btrbk_logger.conf
<both>{/etc/btrbk/btrbk.conf}[root]()
BTRBK_LOGGER_CONF_EOF

cat << 'BTRBK_LOGROTATE_EOF' > /etc/logrotate.d/btrbk
/var/log/btrbk.log {
  rotate 12
  monthly
  compress
  missingok
  notifempty
}
BTRBK_LOGROTATE_EOF

# Source: https://gitlab.com/KodyVB/btrbk-pac
# Date: 18/08/2024
cat << 'BTRBK_PAC_MASTER_ZST_B64_EOF' > /tmp/btrbk-pac-master.tar.zst.b64
KLUv/QRofekAmqdgHy6QzB09CqhrEtqEyc/H5g/Ni/T1pKtbQAYRcLSFAwp123vy8EkRAQAAAKCY
RQAHywHgAesBjbq1VrQvSaP/TXDsNLNeJ72273f1ZVfrTMFn9Wp1jlbLwcbT6ejtKfYsSDP/4889
zbHnr9SV5rSjF5Vn7iplaUatk3RhmWWXJDzxRhpVmmv0ZB17dc8s/Zzarp1eq/yeZ3VM37WbO9Wv
abMrr3RrE92sW1qt1LWuvT/uupvZD/936cnzd0sT357UTf2TWZFGIxJn+i52im/OHFPteh9Ili+X
vbvfs3o3ze/u5v+y5jJFtdtbZ/7/2ruJTfC6uS3+smPUtSDYuezrOtN2kNm1nVml8zTpT9fc1E3b
kwr79d1/M5uo76a6Vs+dJ/b9ajfb+ZvJ0vyfhM6fBbw6z58CySgudar6ybfNNe9rbZb6Z9Y/306c
u7HnbbqXWnN8mlzf7NT6yd4sbyDMPu3ibDeXvRTfzdJ8ufem/c52nrw6budyv+lW//fsYq9JpPY8
u5u/2VxGOVQ/yL1ck+zsSK3Z7FGcffbv2U+5D33v2pSnFyAUiUYXnc8IBILws/Vs70Vvt72W5qcX
LA0gIgLjEAERcXl4iNC6S8OBkdF4ZBIAdOOZ/wMA0QAkJCQuF4kHiYsD5gHzcAFggZC4QEBIWABI
7PlnZ2XTs0BKOJcCHLEHDOirfT+hGEHuSaTG/psmS/E8yel9UUHU8EiHZDQyHo+Go4vRs74q8vuP
4qVyx4POH42GR+YTPTYYo09Hgacjw/GAQvJjo8MAFIoYzZHhtEZn49YJb+54dHhXY6KQZmOT0Rqb
DE7nIrOwr0NtfnHPfQXJTVpntlX/PPHucvXbru9WmD9FdeAlb5bycuDAAQaCL6q1+nVVoU2hnfH1
Jq3sxNl8Uqo+vpOe2vsqPHnvy179G/vuAwiv/a9CiVez13vH+GaWXqPPT7T/bIavpaZZeZX365yl
r0BuCk/P3/q/lsvw9L/5q/dLkzbH4vLfhtADx15jlmVhGyLdaZFKdHttrEDsrKXOm1eKd39yX6vP
fv/sZ4tCIVLF0kwRgUayW0Mq/jvwqZq7m/P1bmVxpSqelXZecqvA49E8T2rt7TKl4HlmjLOttbqn
/O2+uSz5dZOCt83QjlbXLP9U9Wg3s8y/oaEhx4WYylSjI+6zm/DMo9L39Z66AULs5u2+5m67kus3
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
ZoQZ/HECLG55bgC9AlOGmck=
BTRBK_PAC_MASTER_ZST_B64_EOF

base64 --decode /tmp/btrbk-pac-master.tar.zst.b64 > /tmp/btrbk-pac-master.tar.zst
tar -I "zstd -d" -xpf /tmp/btrbk-pac-master.tar.zst -C /usr/local/src
chown -R root:root /usr/local/src/btrbk-pac-master
find /usr/local/src/btrbk-pac-master -type d -exec chmod 0755 {} \;
find /usr/local/src/btrbk-pac-master -type f -exec chmod 0644 {} \;
rm /tmp/btrbk-pac-master.tar.zst.b64 /tmp/btrbk-pac-master.tar.zst

cp /usr/local/src/btrbk-pac-master/scripts/btrbk_pac_log /usr/local/bin/btrbk_pac_log
cp /usr/local/src/btrbk-pac-master/scripts/btrbk_pac_log_script /usr/share/libalpm/scripts/btrbk_pac_log_script
cp /usr/local/src/btrbk-pac-master/hooks/00-btrbk-pre.hook /usr/share/libalpm/hooks/00-btrbk-pre.hook
cp /usr/local/src/btrbk-pac-master/hooks/zx-btrbk-post.hook /usr/share/libalpm/hooks/zx-btrbk-post.hook

# Patch btrbk_pac_log to work with long-iso snapshot timestamp format
sed -i -e 's/\[T\]?\[0-9_\]\*\$/[T]?[0-9_+-]*$/g' /usr/local/bin/btrbk_pac_log

# Setup a hook to backup the /efi folder before the pre snapshot
cat << 'BACKUPEFI_PRE_HOOK_EOF' > /usr/share/libalpm/hooks/00-backupefi_pre.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Description = Backing up pre /efi...
When = PreTransaction
Exec = /usr/bin/bash -c 'mkdir -p /efibackup;cp -pav /efi/* /efibackup/'
BACKUPEFI_PRE_HOOK_EOF

# Clean up the /efibackup after the pre snapshot
cat << 'BACKUPEFI_PRE_CLEANUP_HOOK_EOF' > /usr/share/libalpm/hooks/01-backupefi_cleanup_pre.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Description = Cleaning up pre /efi backup...
When = PreTransaction
Exec = /usr/bin/bash -c 'rm -rf /efibackup'
BACKUPEFI_PRE_CLEANUP_HOOK_EOF

# Setup a hook to backup the /efi folder before the post snapshot
cat << 'BACKUPEFI_POST_HOOK_EOF' > /usr/share/libalpm/hooks/zx-backupefi_post.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Description = Backing up post /efi...
When = PostTransaction
Exec = /usr/bin/bash -c 'mkdir -p /efibackup;cp -pav /efi/* /efibackup/'
BACKUPEFI_POST_HOOK_EOF

# Clean up the /efibackup after the post snapshot
cat << 'BACKUPEFI_POST_CLEANUP_HOOK_EOF' > /usr/share/libalpm/hooks/zy-backupefi_cleanup_post.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Description = Cleaning up pre /efi backup...
When = PostTransaction
Exec = /usr/bin/bash -c 'rm -rf /efibackup'
BACKUPEFI_POST_CLEANUP_HOOK_EOF

chown root:root \
  /etc/btrbk/btrbk.conf \
  /etc/btrbk_logger \
  /etc/btrbk_logger/btrbk_logger.conf \
  /etc/logrotate.d/btrbk \
  /usr/local/bin/btrbk_pac_log \
  /usr/share/libalpm/hooks/00-backupefi_pre.hook \
  /usr/share/libalpm/hooks/00-btrbk-pre.hook \
  /usr/share/libalpm/hooks/01-backupefi_cleanup_pre.hook \
  /usr/share/libalpm/hooks/zx-backupefi_post.hook \
  /usr/share/libalpm/hooks/zx-btrbk-post.hook \
  /usr/share/libalpm/hooks/zy-backupefi_cleanup_post.hook \
  /usr/share/libalpm/scripts/btrbk_pac_log_script

chmod 0644 \
  /etc/btrbk/btrbk.conf \
  /etc/btrbk_logger/btrbk_logger.conf \
  /etc/logrotate.d/btrbk \
  /usr/share/libalpm/hooks/00-backupefi_pre.hook \
  /usr/share/libalpm/hooks/00-btrbk-pre.hook \
  /usr/share/libalpm/hooks/01-backupefi_cleanup_pre.hook \
  /usr/share/libalpm/hooks/zx-backupefi_post.hook \
  /usr/share/libalpm/hooks/zx-btrbk-post.hook \
  /usr/share/libalpm/hooks/zy-backupefi_cleanup_post.hook

chmod 0755 \
  /etc/btrbk_logger \
  /usr/local/bin/btrbk_pac_log \
  /usr/share/libalpm/scripts/btrbk_pac_log_script

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

systemctl enable atop.service
systemctl enable atopacct.service
systemctl enable auditd.service
systemctl enable bluetooth.service
systemctl enable docker.socket
systemctl enable libvirtd.socket
systemctl enable NetworkManager.service
systemctl enable sddm.service
systemctl enable sshd.service
systemctl enable systemd-boot-update.service
systemctl enable systemd-timesyncd.service

systemctl enable atop-rotate.timer
systemctl enable btrbk.timer
systemctl enable btrfs-balance@-.timer
systemctl enable btrfs-scrub@-.timer
systemctl enable geoipupdate.timer
systemctl enable logrotate.timer
systemctl enable man-db.timer
systemctl enable paccache.timer
systemctl enable pacman-filesdb-refresh.timer

echo

echo "#==============================================================================="
echo "# Configure sudoers                                                            #"
echo "#===============================================================================" 

# Set default EDITOR
cat << 'DEFAULTEDITOR_EOF' > /etc/sudoers.d/default-editor
# Set default EDITOR to restricted version of nano, and do not allow visudo to use EDITOR/VISUAL.
Defaults      editor=/usr/bin/rnano, !env_editor
DEFAULTEDITOR_EOF
chown root:root /etc/sudoers.d/default-editor
chmod 0440 /etc/sudoers.d/default-editor

# Allow members of the wheel group to execute any command
cat << 'ALLOWWHEELGROUP_EOF' > /etc/sudoers.d/allow-wheel-group
%wheel ALL=(ALL:ALL) ALL
ALLOWWHEELGROUP_EOF
chown root:root /etc/sudoers.d/allow-wheel-group
chmod 0440 /etc/sudoers.d/allow-wheel-group

echo

echo "#==============================================================================="
echo "# Setup users                                                                  #"
echo "#==============================================================================="

# Add user's ~/.local/bin to the PATH
cat << 'LOCAL_BIN_SH_EOF' > /etc/profile.d/local_bin.sh
# Add user's ~/.local/bin to the PATH
if [ -d "${HOME}/.local/bin" ]; then
  append_path "${HOME}/.local/bin"
  export PATH
fi
LOCAL_BIN_SH_EOF
chown root:root /etc/profile.d/local_bin.sh
chmod 0644 /etc/profile.d/local_bin.sh

# Set up temporary root password
echo -e "Passw0rd\nPassw0rd" | passwd

# Set up my user with a temporary password
useradd -m jc
usermod -a -G docker,libvirt,wheel -s /usr/bin/fish jc
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
