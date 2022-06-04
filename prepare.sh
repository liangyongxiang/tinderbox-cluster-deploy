#!/bin/bash

set -x

TINDERBOX_CLUSTER="${TINDERBOX_CLUSTER:-tinderbox-cluster}"
IRC_CHANNEL_NAME="${IRC_CHANNEL_NAME:-#plct-gentoo-riscv-buidbot}"
PASSWORD="${PASSWORD:-bu1ldbOt}"
IP_ADDRESS="${IP_ADDRESS:-localhost}"
SQL_DB="${SQL_DB:-gentoo-ci}"
SQL_FILE="${SQL_FILE:-sql/gentooci.sql}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# python env
if command -v deactivate; then
    deactivate
fi
if [ -d sandbox ]; then
    rm -rf sandbox
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
sed -i "s/buildbot:password@ip:${PASSWORD}@${IP_ADDRESS}\/${SQL_DB}/g" gentooci.cfg
sed -i "s/password@ip\/buildbot/${PASSWORD}@${IP_ADDRESS}\/${SQL_DB}/g" master.cfg
sed -i "s/user:password@host/buildbot:${PASSWORD}@${IP_ADDRESS}/g" logparser.json

# worker_data
sed -i "/'uuid'/d" master.cfg
sed -i '/^worker_data.*/a \
    {"uuid" : "local0", "password" : "riscv", "type" : "local",   "enable" : True, },\
    {"uuid" : "local1", "password" : "riscv", "type" : "local",   "enable" : True, },\
    {"uuid" : "node0", "password" : "riscv", "type" : "node",    "enable" : True, },\
    {"uuid" : "a89c2c1a-46e0-4ded-81dd-c51afeb7fcfa", "password" : "riscv", "type" : "default", "enable" : True, },\
    {"uuid" : "a89c2c1a-46e0-4ded-81dd-c51afeb7fcfd", "password" : "riscv", "type" : "default", "enable" : True, },\
' master.cfg

# buildbot db
sudo -u postgres createuser -P buildbot
Enter password for new role: bu1ldb0t
Enter it again: bu1ldb0t
postgres$ createdb -O buildbot buildbot
postgres$ exit

# gentoo-ci db
if [ ! -f "$SQL_FILE" ]; then
    wget --output-document $SQL_FILE http://90.231.13.235:8000/gentooci.sql
    sed -i 's/sv_SE/en_US/g' "$SQL_FILE"
fi
sudo -u postgres dropdb --if-exists ${SQL_DB} >/dev/null
sudo -u postgres psql -f $SQL_FILE >/dev/null
pushd "buildbot_gentoo_ci/db/migrate"
migrate version_control postgresql://buildbot:${PASSWORD}@${IP_ADDRESS}/${SQL_DB} .
popd

#git --no-pager diff
