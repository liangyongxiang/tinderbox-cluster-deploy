#!/bin/bash

set -x

TINDERBOX_CLUSTER="${TINDERBOX_CLUSTER:-tinderbox-cluster}"
IRC_CHANNEL_NAME="${IRC_CHANNEL_NAME:-#plct-gentoo-riscv-buidbot}"
PASSWORD="${PASSWORD:-bu1ldbOt}"
IP_ADDRESS="${IP_ADDRESS:-localhost}"
GENTOOCI_DB="${GENTOOCI_DB:-gentoo-ci}"
BUILDBOT_DB="${BUILDBOT_DB:-buildbot}"
SQL_FILE="${SQL_FILE:-sql/gentooci.sql}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# python env
if command -v deactivate; then
    deactivate
fi
if [ ! -d sandbox ]; then
    #rm -rf sandbox
    #python -m venv --system-site-packages sandbox
    python -m venv sandbox
    source sandbox/bin/activate
    pip install -r requirements.txt
fi

mkdir -p "${TINDERBOX_CLUSTER}"
if [ ! -d "${TINDERBOX_CLUSTER}" ]; then
    echo "${TINDERBOX_CLUSTER} is not dir"
    exit 1
fi
cd "${TINDERBOX_CLUSTER}"

if ! git rev-parse --is-inside-work-tree; then
    if ! git clone https://anongit.gentoo.org/git/proj/tinderbox-cluster.git .; then
        echo "git clone false"
        exit 1
    fi
fi

git reset --hard
#git clean -dfx

# IRC
sed -i "s/#gentoo-ci/${IRC_CHANNEL_NAME}/g" buildbot_gentoo_ci/config/reporters.py

# database
sed -i "s/password@ip/${PASSWORD}@${IP_ADDRESS}/g" gentooci.cfg
sed -i "s/password@ip/${PASSWORD}@${IP_ADDRESS}/g" master.cfg
sed -i "s/user:password@host/buildbot:${PASSWORD}@${IP_ADDRESS}/g" logparser.json
sed -i "s/sa.Column('image'/#sa.Column('image'/g" buildbot_gentoo_ci/db/model.py

# worker_data
sed -i "/'uuid'/d" master.cfg
sed -i '/^worker_data.*/a \
    {"uuid" : "local0", "password" : "riscv", "type" : "local",   "enable" : True, },\
    {"uuid" : "local1", "password" : "riscv", "type" : "local",   "enable" : True, },\
    {"uuid" : "node0", "password" : "riscv", "type" : "node",    "enable" : True, },\
    {"uuid" : "a89c2c1a-46e0-4ded-81dd-c51afeb7fcfa", "password" : "riscv", "type" : "default", "enable" : True, },\
    {"uuid" : "a89c2c1a-46e0-4ded-81dd-c51afeb7fcfd", "password" : "riscv", "type" : "default", "enable" : True, },\
' master.cfg

sudo -u postgres dropdb --if-exists ${GENTOOCI_DB} #>/dev/null
sudo -u postgres dropdb --if-exists ${BUILDBOT_DB} #>/dev/null

sudo -u postgres dropuser --if-exists buildbot #>/dev/null

# buildbot db
sudo -u postgres psql -c "CREATE USER buildbot WITH PASSWORD '\${PASSWORD}';"
sudo -u postgres createdb -O buildbot buildbot

# gentoo-ci db
if [ ! -f "$SQL_FILE" ]; then
    wget --output-document $SQL_FILE http://90.231.13.235:8000/gentooci.sql
    sed -i 's/sv_SE/en_US/g' "$SQL_FILE"
fi
sudo -u postgres psql -f $SQL_FILE >/dev/null

migrate version_control postgresql://buildbot:${PASSWORD}@${IP_ADDRESS}/${GENTOOCI_DB} buildbot_gentoo_ci/db/migrate

if [ ! -f "buildbot.tac" ]; then
    buildbot create-master -r .
    rm master.cfg.sample
fi

buildbot upgrade-master

#git --no-pager diff
