#!/usr/bin/env bash

set -e
set -x

WORKER_NAME="${WORKER_NAME:-DefaultWorker}"
PASSWORD="${PASSWORD:-riscv}"
MASTER_HOST="${MASTER_HOST:-localhost}"
MASTER_PORT="${MASTER_PORT:-9989}"

echo 'ACCEPT_KEYWORDS="~amd64"' >> /etc/portage/make.conf
chown -R portage:portage /var/db/repos/gentoo

emerge-webrsync
emerge -uUDN --with-bdeps=y @world
emerge --verbose --quiet --noreplace dev-util/pkgcheck app-arch/zstd dev-lang/rust-bin dev-vcs/git dev-util/buildbot-worker

cd /var/tmp

buildbot-worker create-worker --umask=0o22 "${MASTER_HOST}_${WORKER_NAME}" "${MASTER_HOST}:${MASTER_PORT}" ${WORKER_NAME} ${PASSWORD}

cd "${MASTER_HOST}_${WORKER_NAME}"

if ! buildbot-worker start; then
  less twistd.log
fi
