#!/bin/bash

TINDERBOX_BASEDIR="${TINDERBOX_BASEDIR:-/var/tmp/tinderbox}"

# Step 1: depends
emerge-webrsync
emerge --verbose --quiet --update app-misc/tmux dev-vcs/git app-misc/tmux dev-db/postgresql dev-python/pip
emerge --config dev-db/postgresql:14
# TODO: systemd
/etc/init.d/postgresql-* start


git clone https://github.com/liangyongxiang/tinderbox-cluster-deploy ${TINDERBOX_BASEDIR}

cd ${TINDERBOX_BASEDIR}
./deploy.sh
