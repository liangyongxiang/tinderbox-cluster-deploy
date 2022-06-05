#!/bin/bash

set -x
set -e

TINDERBOX_CLUSTER="${TINDERBOX_CLUSTER:-tinderbox-cluster}"
IRC_BOT_NAME="${IRC_BOT_NAME:-#yongxiang-bb}"
IRC_CHANNEL_NAME="${IRC_CHANNEL_NAME:-#plct-gentoo-riscv-buidbot}"
PASSWORD="${PASSWORD:-bu1ldbOt}"
IP_ADDRESS="${IP_ADDRESS:-localhost}"
GENTOOCI_DB="${GENTOOCI_DB:-gentoo-ci}"
BUILDBOT_DB="${BUILDBOT_DB:-buildbot}"
SQL_URL="${SQL_URL:-http://90.231.13.235:8000}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# python env
if [ ! -d sandbox ]; then
    python -m venv sandbox
    source sandbox/bin/activate
    pip install -r requirements.txt
else
    source sandbox/bin/activate
fi

mkdir -p "${TINDERBOX_CLUSTER}"
cd "${TINDERBOX_CLUSTER}"

# alway stop
buildbot stop

# clone code
if ! git rev-parse --is-inside-work-tree; then
    if ! git clone https://anongit.gentoo.org/git/proj/tinderbox-cluster.git .; then
        echo "git clone false"
        exit 1
    fi
fi

# revert all change
git reset --hard
#git clean -dfx

# IRC
sed -i "s/gci_test/${IRC_BOT_NAME}/g" buildbot_gentoo_ci/config/reporters.py
sed -i "s/#gentoo-ci/${IRC_CHANNEL_NAME}/g" buildbot_gentoo_ci/config/reporters.py

# master.conf
# database
sed -i "s/password@ip/${PASSWORD}@${IP_ADDRESS}/g" master.cfg
# worker_data
sed -i "/'uuid'/d" master.cfg
sed -i '/^worker_data.*/a \
    {"uuid" : "local0", "password" : "riscv", "type" : "local",   "enable" : True, },\
    {"uuid" : "local1", "password" : "riscv", "type" : "local",   "enable" : True, },\
    {"uuid" : "node0", "password" : "riscv", "type" : "node",    "enable" : True, },\
    {"uuid" : "a89c2c1a-46e0-4ded-81dd-c51afeb7fcfa", "password" : "riscv", "type" : "default", "enable" : True, },\
    {"uuid" : "a89c2c1a-46e0-4ded-81dd-c51afeb7fcfd", "password" : "riscv", "type" : "default", "enable" : True, },\
' master.cfg

# logparser.json
# database
sed -i "s/user:password@host/buildbot:${PASSWORD}@${IP_ADDRESS}/g" logparser.json
sed -i "s/sa.Column('image'/#sa.Column('image'/g" buildbot_gentoo_ci/db/model.py

# gentooci.cfg
# database
sed -i "s/password@ip/${PASSWORD}@${IP_ADDRESS}/g" gentooci.cfg

# delete the database and run away, 删库跑路
# TODO: backup database
sudo -u postgres dropdb --if-exists ${GENTOOCI_DB} #>/dev/null
sudo -u postgres dropdb --if-exists ${BUILDBOT_DB} #>/dev/null
sudo -u postgres dropuser --if-exists buildbot #>/dev/null

# buildbot db init
sudo -u postgres psql -c "CREATE USER buildbot WITH PASSWORD '\${PASSWORD}';"
sudo -u postgres createdb -O buildbot ${BUILDBOT_DB}

# import gentoo-ci db
sql_dbs=(
    gentooci.sql
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

	if [ "$db" = "gentooci.sql" ]; then
		sudo -u postgres psql -f "sql/$db" >/dev/null
	else
		sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -f "sql/$db" >/dev/null
	fi
done
# migrate version_control
migrate version_control postgresql://buildbot:${PASSWORD}@${IP_ADDRESS}/${GENTOOCI_DB} buildbot_gentoo_ci/db/migrate

if [ ! -f "buildbot.tac" ]; then
    buildbot create-master -r .
    rm master.cfg.sample
fi

# update database
buildbot upgrade-master

if ! buildbot start; then
    less twistd.log
fi

#git --no-pager diff
