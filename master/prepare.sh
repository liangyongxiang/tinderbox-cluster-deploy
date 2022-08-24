#!/usr/bin/env bash

set -x

PORTAGE_VERSION="${PORTAGE_VERSION:-14}"

if [ $(id -u) -ne 0 ]; then
  echo "You must run this script as root"
  exit 1
fi

echo "Prepare environment for installing dependencies...\n"

emerge -vqun dev-vcs/git

if portageq get_repos / | grep "guru"; [ $? -ne 0 ]; then
  if [ -d /etc/portage/repos.conf ]; then
    echo -e "[guru]\nlocation = /var/db/repos/guru\nsync-type = git\nsync-uri = https://github.com/gentoo-mirror/guru.git" | cat >> /etc/portage/repos.conf/guru.conf
  elif [ -f /etc/portage/repos.conf ]; then
    echo -e "\n[guru]\nlocation = /var/db/repos/guru\nsync-type = git\nsync-uri = https://github.com/gentoo-mirror/guru.git" | cat >> /etc/portage/repos.conf
  else
    mkdir /etc/portage/repos.conf
    echo -e "[guru]\nlocation = /var/db/repos/guru\nsync-type = git\nsync-uri = https://github.com/gentoo-mirror/guru.git" | cat >> /etc/portage/repos.conf/guru.conf
  fi
fi

emaint sync -r guru

emerge -vqun dev-db/postgresql:${PORTAGE_VERSION}

if [ -z "$(ls -A /var/lib/postgresql/14/data)" ]; then
    emerge --config dev-db/postgresql:14
fi

# Not consider openrc
#if [ "$(cat /proc/1/comm)" = "systemd" ]; then
    systemctl enable --now postgresql-14
#else
#    rc-update add postgresql-14
#    rc-service postgresql-14 start
#fi

echo "Checking dependencies for tinderbox-cluster...\n"

dependencies=(
  dev-vcs/git
  # avoid build dev-lang/rust
  dev-lang/rust-bin
  www-client/pybugz
  dev-python/GitPython
  dev-python/pygit2
  dev-python/psycopg:2
  dev-python/requests
  dev-python/txrequests
  dev-python/sqlalchemy-migrate
  dev-util/buildbot
  dev-util/buildbot-badges
  dev-util/buildbot-console-view
  dev-util/buildbot-grid-view
  dev-util/buildbot-waterfall-view
  dev-util/buildbot-wsgi-dashboards
  dev-util/buildbot-www
)

emerge -qvun ${dependencies[@]}

mkdir -p /var/lib/buildmaster/gentoo-ci-cloud/secrets

echo "Preparation Finishied"
