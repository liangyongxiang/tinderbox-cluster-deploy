#!/usr/bin/env bash
#

set -x
set -e

WORKER_NAME="${WORKER_NAME:-defaultWorker}"
PASSWORD="${PASSWORD:-riscv}"
STAGE3_MIRROR="${STAGE3_MIRRORS:-https://gentoo.osuosl.org/}"
STAGE3_FILENAME="${STAGE3_FILENAME:-stage3-amd64-openrc-20220612T170541Z.tar.xz}"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

if [ -d /mnt/${WORKERNAME} ]; then
  echo "File /mnt/${WORKERNAME} exists"
  echo "Please check if you worker has already been created"
  echo "Otherwise, Plsease Remove the folder"
  exit 1
fi

mkdir "/mnt/${WORKERNAME}"

cp deploy_in_chroot.sh "/mnt/${WORKERNAME}"
chmod a+x deploy_in_chroot.sh 

cd "/mnt/${WORKERNAME}"

wget "${STAGE3_MIRROR}/releases/amd64/autobuilds/current-stage3-amd64-openrc/${STAGE3_FILENAME}"

tar xpf "${STAGE3_FILENAME}" --numeric-owner --xattrs-include='*.*'

cp -L /etc/resolv.conf etc
cp usr/share/portage/config/repos.conf

mount -t proc /proc proc
mount --rbind /sys sys
mount --make-rslave sys
mount --rbind /dev dev
mount --make-rslave dev
mount --bind /run run
mount --make-slave run

chroot "/mnt/${WORKERNAME}" /bin/bash -c "WORKER_NAME=${WORKER_NAME} PASSWORD="${PASSWORD:-riscv}" deploy_in_chroot.sh"
