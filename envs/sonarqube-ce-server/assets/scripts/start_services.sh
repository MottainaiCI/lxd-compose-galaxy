#!/bin/bash

# shellcheck disable=SC1090
set -e
source ./automation_tools.sh

db_version="$(echo $sonar_server_config | jq -M -r '.db.version')"
db_version=${db_version:-"$POSTGRESQL_VERSION"}

systemctl enable "postgresql-$db_version"
systemctl enable sonarqube

if [ "$(is_sonar_ready)" == "0" ]; then
  systemctl daemon-reload &&
  systemctl restart "postgresql-$db_version" sonarqube &&
  sleep 60;
fi