#!/usr/bin/env bash

set -x
set -e

SQL_URL="${SQL_URL:-http://90.231.13.235:8000}"
DB_HOST="${DB_HOST:-localhost}"
DB_NAME="${DB_NAME:-gentoo-ci}"
USER_PASSWD="${USER_PASSWD:-bu1ldbOt}"
REPO_URL="${REPO_URL:-https://git.onfoo.top/Chi-Tan-Da-Eru/gentoo.git}"
DOCKER_HOST_URL="${DOCKER_HOST_URL:-tcp://127.0.0.1:2375}"
MASTER_FQDN="${MASTER_FQDN:-172.17.0.1}"
MASTER_IP="${MASTER_IP:-10.0.8.50}"

if [ -d tinderbox-cluster ]; then
  buildbot stop tinderbox-cluster
  rm -rf tinderbox-cluster
fi

git clone "https://anongit.gentoo.org/git/proj/tinderbox-cluster.git"

pushd tinderbox-cluster
  # master.cfg
  sed -i.bak "s/'password' : 'X\?'/'password' : 'riscv'/" master.cfg
  sed -i.bak "s|postgresql://buildbot:X@192.0.0.0/buildbot|postgresql://buildbot:${USER_PASSWD}@${DB_HOST}/buildbot|" master.cfg
  sed -i.bak "/#c\['change_source'\] = change_source.gentoo_change_source()/s/#//" master.cfg
  sed -i.bak "/c\['services'\] = reporters.gentoo_reporters(r=c\['services'\])/s/^/#/" master.cfg
  sed -i.bak "s|c\['buildbotURL'\] = \"http://0.0.0.0:8010/\"|c\['buildbotURL'\] = \"http://${MASTER_IP}:8010/\"|" master.cfg

  # logparser.json
  sed -i.bak "s|postgresql+psycopg2://user:password@host/gentoo-ci|postgresql+psycopg2://buildbot:${USER_PASSWD}@${DB_HOST}/${DB_NAME}|" logparser.json

  # gentooci.cfg
  sed -i.bak "s|postgresql://buildbot:password@ip/gentoo-ci|postgresql://buildbot:${USER_PASSWD}@${DB_HOST}/${DB_NAME}|" gentooci.cfg

  # buildbot_gentoo_ci/db/migrate/migrate.cfg
  sed -i.bak "s/required_dbs=\[\]/required_dbs=['postgresql']/" buildbot_gentoo_ci/db/migrate/migrate.cfg

  # buildbot_gentoo_ci/config/change_source.py
  sed -i.bak "s|repourl='https://gitlab.gentoo.org/zorry/gentoo-ci.git'|repourl='${REPO_URL}'|" buildbot_gentoo_ci/config/change_source.py
  sed -i.bak "/project='gentoo-ci'/a category='push'" buildbot_gentoo_ci/config/change_source.py
  sed -i.bak "/project='gentoo-ci'/s/^/#/" buildbot_gentoo_ci/config/change_source.py

  # buildbot_gentoo_ci/steps/logs.py
  sed -i.bak "/minio/s/^/#/" buildbot_gentoo_ci/steps/logs.py

  # buildbot_gentoo_ci/steps/logs.py
  sed -i.bak "/f.addStep(logs.MakeIssue())/s/^/#/" buildbot_gentoo_ci/config/buildfactorys.py

  # FIXME: setting up docker latent worker
  sed -i.bak "s|docker_host='tcp://192.168.1.12:2375'|docker_host='${DOCKER_HOST_URL}'|" buildbot_gentoo_ci/config/workers.py
  sed -i.bak "s|masterFQDN='192.168.1.5'|masterFQDN='${MASTER_FQDN}'|" buildbot_gentoo_ci/config/workers.py

popd

pushd tinderbox-cluster/buildbot_gentoo_ci/db/migrate
  migrate version_control postgresql://buildbot:${USER_PASSWD}@${DB_HOST}/${DB_NAME} .
popd

buildbot create-master -r master_never_be_created
cp master_never_be_created/buildbot.tac tinderbox-cluster
rm -r master_never_be_created

buildbot checkconfig tinderbox-cluster

buildbot upgrade-master tinderbox-cluster
rm tinderbox-cluster/master.cfg.sample

buildbot checkconfig tinderbox-cluster

buildbot start tinderbox-cluster

echo $?
