#!/bin/bash

# Step 1: depends
#emerge-webrsync
#emerge --verbose --quiet dev-vcs/git app-misc/tmux dev-db/postgresql dev-python/pip
#emerge --config dev-db/postgresql:14
# TODO: systemd
#/etc/init.d/postgresql-* start
#git clone https://github.com/liangyongxiang/tinderbox-cluster-deploy /var/tmp/tinderbox

cd /var/tmp/tinderbox
source deploy.sh
