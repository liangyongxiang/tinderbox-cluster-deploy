#!/usr/bin/env bash

set -e
set -x

WORKER_NAME="${WORKER_NAME:-DefaultWorker}"
PASSWORD="${PASSWORD:-riscv}"
MASTER_HOST="${MASTER_HOST:-localhost}"
MASTER_PORT="${MASTER_PORT:-9989}"

echo 'ACCEPT_KEYWORDS="~amd64"' >> /etc/portage/make.conf

emerge-webrsync

chown -R portage:portage /var/db/repos/gentoo

emerge -uUDN --with-bdeps=y @world

emerge dev-util/pkgcheck dev-vcs/git

emerge dev-util/buildbot-worker

cd /var/tmp

buildbot-worker create-worker --umask=0o22 "${MASTER_HOST}_${WORKER_NAME}" "${MASTER_HOST}:${MASTER_PORT}" ${WORKER_NAME} ${PASSWORD}

cd "${MASTER_HOST}_${WORKER_NAME}"

if ! buildbot start; then
  less twistd.log
fi
