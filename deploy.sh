#!/bin/bash

set -x
set -e

TINDERBOX_BASEDIR="${TINDERBOX_BASEDIR:-/var/lib/buildmaster/gentoo-ci-cloud}"
SQL_URL="${SQL_URL:-http://90.231.13.235:8000}"
INSTALL_DEPEND="${INSTALL_DEPEND:-yes}"

IRC_BOT_NAME="${IRC_BOT_NAME:-plct-bbbot}"
IRC_CHANNEL_NAME="${IRC_CHANNEL_NAME:-#plct-bb}"

WEB_IP_ADDRESS="${WEB_IP_ADDRESS:-localhost}"
DB_IP_ADDRESS="${DB_IP_ADDRESS:-localhost}"

GENTOOCI_DB="${GENTOOCI_DB:-gentoo-ci}"
PASSWORD="${PASSWORD:-bu1ldbOt}"

TEST_ARCH="${TEST_ARCH:-amd64}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# avoid emerge commnad in sandbox
if command -v deactivate; then
    deactivate
fi

if [ "${INSTALL_DEPEND}" = "yes" ]; then
    distributor=$(lsb_release --id --short)
    if [ "${distributor}" = "Gentoo" ]; then
        emerge-webrsync || emerge --sync
        emerge --verbose --quiet --update --noreplace app-misc/tmux dev-vcs/git app-misc/tmux dev-db/postgresql dev-python/pip
        if [ -z "$(ls -A /var/lib/postgresql/14/data)" ]; then
            emerge --config dev-db/postgresql:14
        fi
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

echo "Create Gentoo CI for ${TEST_ARCH}"

# get others resources
mkdir -p "${TINDERBOX_BASEDIR}"
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
export PATH="${TINDERBOX_BASEDIR}/tinderbox-cluster/bin:${TINDERBOX_BASEDIR}/sandbox/lib/portage/bin:${PATH}"
export PYTHONPATH="${TINDERBOX_BASEDIR}/tinderbox-cluster"

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

sed -i "s/-j14/-j$(nproc)/g" buildbot_gentoo_ci/steps/portage.py
sed -i "s/amd64/${TEST_ARCH}/g" buildbot_gentoo_ci/steps/portage.py
sed -i "/makeconf.*-march=native/d" buildbot_gentoo_ci/steps/portage.py

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

# FIXME: auto create dir
mkdir -p workers/local0
mkdir -p workers/local1
mkdir -p workers/a89c2c1a-46e0-4ded-81dd-c51afeb7fcfa
mkdir -p workers/a89c2c1a-46e0-4ded-81dd-c51afeb7fcfd
mkdir -p workers/nodeWorker
mkdir -p workers/dockerWorker

# logparser.json
# database
sed -i "s/user:password@host/buildbot:${PASSWORD}@${DB_IP_ADDRESS}/g" logparser.json
sed -i "s/\"default_uuid\" : \"uuid\"/\"default_uuid\" : \"e89c2c1a-46e0-4ded-81dd-c51afeb7fcff\"/" logparser.json
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

# FIXME: Configure data of gentoo-ci db instead of just importing them
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

if [ "${TEST_ARCH}" = 'riscv' ]; then
    # projects_portage
    sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -c "UPDATE projects_portage SET value='default/linux/riscv/20.0/rv64gc/lp64d/systemd' WHERE id = 1"
    sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -c "UPDATE projects_portage SET value='default/linux/riscv/20.0/rv64gc/lp64d/desktop' WHERE id = 3"
    sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -c "UPDATE projects_portage SET value='default/linux/riscv/20.0/rv64gc/lp64d' WHERE id = 5"
    # projects
    sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -c "UPDATE projects SET profile='profiles/default/linux/riscv', keyword_id='11' WHERE uuid = 'e89c2c1a-46e0-4ded-81dd-c51afeb7fcff'"
    sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -c "UPDATE projects SET name='defriscv20_0unstable', description='Default riscv 20.0 Unstable', profile='profiles/default/linux/riscv/20.0/rv64gc/lp64d', keyword_id='11', image='stage3-rv64_lp64d-openrc-latest' WHERE uuid = 'e89c2c1a-46e0-4ded-81dd-c51afeb7fcfa'"
    sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -c "UPDATE projects SET profile='profiles/default/linux/riscv/20.0/rv64gc/lp64d/systemd', keyword_id='11', enabled='t', image='stage3-rv64_lp64d-systemd-latest' WHERE uuid = 'e89c2c1a-46e0-4ded-81dd-c51afeb7fcfd'"
    # projects_portages_makeconf
    sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -c "UPDATE public.projects_portages_makeconf set value='riscv64-unknown-linux-gnu' WHERE id = 2;"
    sudo -u postgres psql -Ubuildbot -d${GENTOOCI_DB} -c "INSERT INTO public.projects_portages_makeconf VALUES (63, 'e89c2c1a-46e0-4ded-81dd-c51afeb7fcff', 3, '--jobs');"
fi

# migrate version_control
migrate version_control postgresql://buildbot:${PASSWORD}@${DB_IP_ADDRESS}/${GENTOOCI_DB} buildbot_gentoo_ci/db/migrate

if [ ! -f "buildbot.tac" ]; then
    buildbot create-master -r .
    rm master.cfg.sample
fi

# buildbot.tac
sed -i 's/umask = None/umask = 0o022/' buildbot.tac
chmod +x bin/ci_log_parser

# update database
buildbot upgrade-master

# FIXME: You will probably wish to create a separate user account for the buildmaster, perhaps named buildmaster. Do not run the buildmaster as root!
#        See https://docs.buildbot.net/latest/manual/installation/buildmaster.html#creating-a-buildmaster
if ! buildbot start; then
    less twistd.log
fi

