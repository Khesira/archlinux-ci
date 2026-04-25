#!/usr/bin/env bash

set -o pipefail

if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be started using sudo"
   exit 1
fi

if [ -f .env ]; then
  source .env.example
fi

if [ -z "${TIMEZONE}" ]; then
  TIMEZONE="Europe/Berlin"
fi

if [ -z "${KEYMAP}" ]; then
  KEYMAP="de-latin1"
fi

if [ -z "${LOCALE}" ]; then
  LOCALE="en_US.UTF-8 UTF-8"
fi

if [ -z "${HOST_NAME}" ]; then
  HOST_NAME="archlinux-ci"
fi

if [ -z "${IMAGE_SIZE}" ]; then
  IMAGE_SIZE=20G
fi

FILE_NAME="archlinux-cloudinit-ext4-$(date +"%m-%d-%Y")"
RAW="${FILE_NAME}.raw"
QCOW="${FILE_NAME}.qcow2"

REAL_USER=${SUDO_USER:-$(whoami)}
REAL_GROUP=${SUDO_GID:-$(id -g "$REAL_USER")}

truncate -s "${IMAGE_SIZE}" "${RAW}"
losetup -fP "${RAW}"

# shellcheck disable=SC2155
ARCH_LOOP=$(losetup -j "${RAW}" | cut -d : -f 1)
ARCH_LOOPp1="${ARCH_LOOP}p1"
ARCH_LOOPp2="${ARCH_LOOP}p2"

MNT=mnt
BOOT="${MNT}/boot"

if [ ! -d "${MNT}" ]; then
    echo "Create mnt ${MNT}..."
    mkdir -p "${MNT}"
fi

# Check if we run in a GitHub action
echo "IMAGE_NAME=${QCOW}" > artifact_name.txt

sfdisk "${ARCH_LOOP}" <<EOF
label: gpt
unit: sectors
first-lba: 2048

# 1. EFI System Partition (Size: 200.000 sectors ≈ 100 MiB)
: size=524288, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="EFI"

# 2. Linux Root Partition (rest of the disk)
: type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709, name="root"
EOF

mkfs.fat -F 32 "${ARCH_LOOPp1}"
mkfs.ext4 "${ARCH_LOOPp2}"
ROOT_UUID=$(blkid -s UUID -o value "${ARCH_LOOPp2}")

mount "${ARCH_LOOPp2}" "${MNT}"
mkdir "${BOOT}"
mount "${ARCH_LOOPp1}" "${BOOT}"

pacstrap "${MNT}/" base \
  linux \
  amd-ucode \
  intel-ucode \
  cloud-init \
  qemu-guest-agent \
  cloud-guest-utils \
  openssh \
  efibootmgr \
  vim

genfstab -U "${MNT}/" > "${MNT}/etc/fstab"

# chroot into the system and configure it
arch-chroot "${MNT}/" <<EOF
# Set timezone
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# Set locale and keymap
echo "${LOCALE}" >> /etc/locale.gen
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
locale-gen

# Set hostname
echo "${HOST_NAME}" > /etc/hostname

# Set hooks for systemd and create initramfs
sed -i 's/^HOOKS=(.*/HOOKS=(systemd modconf kms sd-vconsole block filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# systemd bootloader Installation
bootctl install

# Activate services
systemctl enable \
  systemd-networkd.service \
  systemd-resolved.service \
  cloud-init.target \
  cloud-init-local.service \
  cloud-init-main.service \
  cloud-config.service \
  cloud-final.service \
  sshd \
  qemu-guest-agent

# Cleanup
pacman -Scc --noconfirm
rm -rf /var/cache/pacman/pkg/*
rm -rf /var/log/*
rm -rf /tmp/*

## Nullify whole remaining space
dd if=/dev/zero of=zero.fill bs=1M || true
rm zero.fill
EOF

# Create boot loader entries
cat <<EOF > "./${MNT}/boot/loader/loader.conf"
default  arch.conf
timeout  0
console-mode max
editor   no
EOF

cat <<EOF > "./${MNT}/boot/loader/entries/arch.conf"
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw
EOF

# Unmount file system
umount "${BOOT}"
umount "${MNT}/"
losetup -d "${ARCH_LOOP}"

# Convert raw image to qcow2 and cleanup
qemu-img convert -c -f raw -O qcow2 "${RAW}" "${QCOW}"
rm "${RAW}"
chown "$REAL_USER":"$REAL_GROUP" "${QCOW}"