#!/bin/bash

set -e
set -x

SQL_URL="${SQL_URL:-http://90.231.13.235:8000}"
DB_IP_ADDRESS="${DB_IP_ADDRESS:-localhost}"
GENTOOCI_DB="${GENTOOCI_DB:-gentoo-ci}"
PASSWORD="${PASSWORD:-bu1ldbOt}"
TEST_ARCH="${TEST_ARCH:-riscv}"

if [ "$(id -u -n)" != "postgres" ]; then
  echo "Please run as postgres"
  exit 1
fi

if [ -d sql ]; then
  mkdir -p sql
fi

dropdb --if-exists ${GENTOOCI_DB}
dropdb --if-exists buildbot
dropuser --if-exists buildbot

psql -v ON_ERROR_STOP=1 -c "CREATE USER buildbot WITH PASSWORD '\${PASSWORD}';" > /dev/null
createdb -O buildbot buildbot

psql ON_ERROR_STOP=1 -f "sql/gentoo_ci_schema.sql" > /dev/null

sql_dbs=(
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
    wget -qO "sql/$db" "$SQL_URL/$db"
  fi
  psql -Ubuildbot -d${GENTOOCI_DB} -f "sql/$db" > /dev/null
done

if [ "${TEST_ARCH}" = 'riscv' ]; then
   psql ON_ERROR_STOP=1 -Ubuildbot -d${GENTOOCI_DB} <<-EOSQL > /dev/null
     UPDATE projects_portage SET value='default/linux/riscv/20.0/rv64gc/lp64d/systemd' WHERE id = 1;
     UPDATE projects_portage SET value='default/linux/riscv/20.0/rv64gc/lp64d/desktop' WHERE id = 3;
     UPDATE projects_portage SET value='default/linux/riscv/20.0/rv64gc/lp64d' WHERE id = 5;

     UPDATE projects SET profile='profiles/default/linux/riscv', keyword_id='11' WHERE uuid = 'e89c2c1a-46e0-4ded-81dd-c51afeb7fcff';
     UPDATE projects SET name='defriscv20_0unstable', description='Default riscv 20.0 Unstable', profile='profiles/default/linux/riscv/20.0/rv64gc/lp64d', keyword_id='11', image='stage3-rv64_lp64d-openrc-latest' WHERE uuid = 'e89c2c1a-46e0-4ded-81dd-c51afeb7fcfa';
     UPDATE projects SET profile='profiles/default/linux/riscv/20.0/rv64gc/lp64d/systemd', keyword_id='11', enabled='t', image='stage3-rv64_lp64d-systemd-latest' WHERE uuid = 'e89c2c1a-46e0-4ded-81dd-c51afeb7fcfd';

     UPDATE public.projects_portages_makeconf set value='riscv64-unknown-linux-gnu' WHERE id = 2;
     INSERT INTO public.projects_portages_makeconf VALUES (63, 'e89c2c1a-46e0-4ded-81dd-c51afeb7fcff', 3, '--jobs');
EOSQL
fi
