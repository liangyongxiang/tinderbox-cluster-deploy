#!/usr/bin/env bash
#

set -x
set -e

WORKER_BASEDIR="${WORKER_BASEDIR:-/mnt}"
WORKER_NAME="${WORKER_NAME:-defaultWorker}"
WORKER_PATH="${WORKER_BASEDIR}/${WORKER_NAME}"

PASSWORD="${PASSWORD:-riscv}"
MASTER_HOST="${MASTER_HOST:-localhost}"
MASTER_PORT="${MASTER_PORT:-9989}"
STAGE3_MIRROR="${STAGE3_MIRRORS:-https://gentoo.osuosl.org/}"
STAGE3_FILENAME="${STAGE3_FILENAME:-stage3-amd64-openrc-20220612T170541Z.tar.xz}"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

if [ -d "${WORKER_PATH}" ]; then
  echo "File ${WORKER_PATH} exists"
  echo "Please check if you worker has already been created"
  echo "Otherwise, Plsease Remove the folder"
  exit 1
fi

mkdir "${WORKER_PATH}"
cd "${WORKER_PATH}"

cp deploy_in_chroot.sh .
chmod a+x deploy_in_chroot.sh

wget "${STAGE3_MIRROR}/releases/amd64/autobuilds/current-stage3-amd64-openrc/${STAGE3_FILENAME}"

tar xpf "${STAGE3_FILENAME}" --numeric-owner --xattrs-include='*.*'

cp -L /etc/resolv.conf etc
mkdir etc/portage/repos.conf
cp usr/share/portage/config/repos.conf etc/portage/repos.conf/gentoo.conf

mount -t proc /proc proc
mount --rbind /sys sys
mount --make-rslave sys
mount --rbind /dev dev
mount --make-rslave dev
mount --bind /run run
mount --make-slave run

chroot "/mnt/${WORKER_NAME}" /bin/bash -c "WORKER_NAME=${WORKER_NAME} PASSWORD=${PASSWORD:-riscv} MASTER_HOST=${MASTER_HOST} MASTER_PORT=${MASTER_PORT} ./deploy_in_chroot.sh"
