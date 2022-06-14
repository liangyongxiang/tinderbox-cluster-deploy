#!/bin/bash

set -x
set -e

TINDERBOX_BASEDIR="${TINDERBOX_BASEDIR:-/var/tmp/tinderbox}"
SQL_URL="${SQL_URL:-http://90.231.13.235:8000}"
INSTALL_DEPEND="${INSTALL_DEPEND:-yes}"

IRC_BOT_NAME="${IRC_BOT_NAME:-#plct-bbbot}"
IRC_CHANNEL_NAME="${IRC_CHANNEL_NAME:-#plct-bb}"

WEB_IP_ADDRESS="${WEB_IP_ADDRESS:-localhost}"
DB_IP_ADDRESS="${DB_IP_ADDRESS:-localhost}"

GENTOOCI_DB="${GENTOOCI_DB:-gentoo-ci}"
PASSWORD="${PASSWORD:-bu1ldbOt}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if [ "${INSTALL_DEPEND}" = "yes" ]; then
    distributor=$(lsb_release --id --short)
    if [ "${distributor}" = "Gentoo" ]; then
        emerge-webrsync
        emerge --verbose --quiet --update --noreplace app-misc/tmux dev-vcs/git app-misc/tmux dev-db/postgresql dev-python/pip
        emerge --config dev-db/postgresql:14
        if [ "$(cat /proc/1/comm)" = "systemd" ]; then
            systemctl enable --now postgresql-14
        else
            rc-update add postgresql-14
            rc-service postgresql-14 start
        fi
    else
        echo "TODO: add $distributor support"
        echo -e "Please install the dependencies manually: \ngit postgresql python pip"
    fi
fi

# get others resources
cd "${TINDERBOX_BASEDIR}"
if [ ! -d ".git" ]; then
    if ! git clone https://github.com/liangyongxiang/tinderbox-cluster-deploy.git .; then
        echo "git clone false"
        exit 1
    fi
fi

# python env
if [ ! -d sandbox ]; then
    python -m venv sandbox
    source sandbox/bin/activate
    pip install -r requirements.txt
else
    source sandbox/bin/activate
fi
# fix portage aux_get
export PATH="$(pwd)/sandbox/lib/portage/bin:${PATH}"

mkdir -p tinderbox-cluster
cd tinderbox-cluster

# alway stop
if [ -f "buildbot.tac" ]; then
    buildbot stop
fi

# clone code
if [ ! -d ".git" ]; then
    if ! git clone https://github.com/FurudeRikaLiveOnHinami/tinderbox-cluster.git .; then
        echo "git clone false"
        exit 1
    fi
fi

## revert all change
git reset --hard
git checkout -B deploy origin/master

# IRC
sed -i "s/gci_test/${IRC_BOT_NAME}/g" buildbot_gentoo_ci/config/reporters.py
sed -i "s/#gentoo-ci/${IRC_CHANNEL_NAME}/g" buildbot_gentoo_ci/config/reporters.py

# master.conf
# database
sed -i "s/password@ip/${PASSWORD}@${DB_IP_ADDRESS}/g" master.cfg
# worker_data
sed -i "/'uuid'/d" master.cfg
sed -i '/^worker_data.*/a \
    {"uuid" : "local0", "password" : "riscv", "type" : "local",   "enable" : True, },\
    {"uuid" : "local1", "password" : "riscv", "type" : "local",   "enable" : True, },\
    {"uuid" : "a89c2c1a-46e0-4ded-81dd-c51afeb7fcfa", "password" : "riscv", "type" : "default", "enable" : True, },\
    {"uuid" : "a89c2c1a-46e0-4ded-81dd-c51afeb7fcfd", "password" : "riscv", "type" : "default", "enable" : True, },\
    {"uuid" : "nodeWorker", "password" : "riscv", "type" : "node", "enable" : True, }, \
    {"uuid" : "dockerWorker", "password" : "riscv", "type" : "docker", "enable": True, }, \
' master.cfg
# buildbot URL
sed -i "s|c\['buildbotURL'\] = \"http://localhost:8010/\"|c['buildbotURL'] = \"http://${WEB_IP_ADDRESS}:8010/\"|" master.cfg

# logparser.json
# database
sed -i "s/user:password@host/buildbot:${PASSWORD}@${DB_IP_ADDRESS}/g" logparser.json
# sed -i "s/sa.Column('image'/#sa.Column('image'/g" buildbot_gentoo_ci/db/model.py

# gentooci.cfg
# database
sed -i "s/password@ip/${PASSWORD}@${DB_IP_ADDRESS}/g" gentooci.cfg

mkdir -p sql

# delete the database and run away, 删库跑路
# TODO: backup database
sudo -u postgres dropdb --if-exists ${GENTOOCI_DB} #>/dev/null
sudo -u postgres dropdb --if-exists buildbot #>/dev/null
sudo -u postgres dropuser --if-exists buildbot #>/dev/null

# buildbot db init
sudo -u postgres psql -c "CREATE USER buildbot WITH PASSWORD '\${PASSWORD}';"
sudo -u postgres createdb --owner buildbot buildbot
sudo -u postgres createdb --owner buildbot ${GENTOOCI_DB} --template template0

# import gentoo-ci db
sql_dbs=(
    gentoo_ci_schema.sql
    keywords.sql
    categorys.sql
    repositorys.sql
    project.sql
    portage_makeconf.sql
    projects_emerge_options.sql

    workers.sql

    projects_env.sql
    projects_makeconf.sql
    projects_package.sql
    projects_pattern.sql
    projects_portage.sql
    projects_repositorys.sql
    projects_workers.sql

    repositorys_gitpullers.sql
)
for db in ${sql_dbs[@]}; do
    if [ ! -f "sql/$db" ]; then
        echo "$db not exists"
        wget --output-document "sql/$db" "$SQL_URL/$db"
        sed -i 's/sv_SE/en_US/g' "sql/$db" # my systemd don't include sv_SE
    fi

    sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -f "sql/$db" >/dev/null
done

# migrate version_control
migrate version_control postgresql://buildbot:${PASSWORD}@${DB_IP_ADDRESS}/${GENTOOCI_DB} buildbot_gentoo_ci/db/migrate

if [ ! -f "buildbot.tac" ]; then
    buildbot create-master -r .
    rm master.cfg.sample
fi

# buildbot.tac
sed -i 's/umask = None/umask = 0o022/' buildbot.tac

# update database
buildbot upgrade-master

if ! buildbot start; then
    less twistd.log
fi


