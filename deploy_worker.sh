#!/usr/bin/env bash

set -x
set -e

WORKER_BASEDIR="${WORKER_BASEDIR:-/mnt}"
WORKER_NAME="${WORKER_NAME:-defaultWorker}"
WORKER_PATH="${WORKER_BASEDIR}/${WORKER_NAME}"

PASSWORD="${PASSWORD:-riscv}"
MASTER_HOST="${MASTER_HOST:-localhost}"
MASTER_PORT="${MASTER_PORT:-9989}"
STAGE3_MIRROR="${STAGE3_MIRROR:-https://gentoo.osuosl.org/}"
STAGE3_FILENAME="${STAGE3_FILENAME:-stage3-amd64-openrc-20220612T170541Z.tar.xz}"

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

if [ ! -f "${STAGE3_FILENAME}" ]; then
    wget "${STAGE3_MIRROR}/releases/amd64/autobuilds/current-stage3-amd64-openrc/${STAGE3_FILENAME}"
fi

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# FIXME: Validate the WORKER_PATH which couldn't be folder hold by system,
#        or be malformed string
if [ -d "${WORKER_PATH}" ]; then
  echo "File ${WORKER_PATH} exists"
  echo "Please check if you worker has already been created"
  echo "Otherwise, Plsease Remove the folder"
  exit 1
fi

mkdir "${WORKER_PATH}"
cd "${WORKER_PATH}"

cp "${SCRIPT_DIR}/deploy_in_chroot.sh" .
chmod a+x deploy_in_chroot.sh

tar xpf "${SCRIPT_DIR}/${STAGE3_FILENAME}" --numeric-owner --xattrs-include='*.*'

mkdir etc/portage/repos.conf
cp usr/share/portage/config/repos.conf etc/portage/repos.conf/gentoo.conf

# build failed for python3.8 in riscv
# /dev/shm: https://github.com/containers/bubblewrap/issues/329

bwrap \
    --die-with-parent \
    --bind      "${WORKER_PATH}" / \
    --ro-bind   /etc/resolv.conf /etc/resolv.conf \
    --tmpfs     /run \
    --dev       /dev \
    --perms 1777 --tmpfs /dev/shm \
    --bind      /sys /sys \
    --proc      /proc \
    --setenv    WORKER_NAME "${WORKER_NAME}" \
    --setenv    PASSWORD "${PASSWORD}" \
    --setenv    MASTER_HOST "${MASTER_HOST}" \
    --setenv    MASTER_PORT "${MASTER_PORT}" \
    --share-net \
    /bin/bash --login /deploy_in_chroot.sh
