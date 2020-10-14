#!/bin/bash

# shellcheck disable=SC1090
set -e
source ./automation_tools.sh

main() {
  prepare_database
  prepare_sonar
}

prepare_database() {

  db_version="$(echo $sonar_server_config | jq -M -r '.db.version')"
  db_version=${db_version:-"$POSTGRESQL_VERSION"}

  if [[ $(is_database_configured -v "$db_version") == "0" ]]; then
    init_database -v "$db_version"
    systemctl start "postgresql-$db_version"
  fi

  db_name=$(echo "$sonar_server_config" | jq -M -r '.db.name')
  db_username=$(echo "$sonar_server_config" | jq -M -r '.db.username')
  db_password=$(echo "$sonar_server_config" | jq -M -r '.db.password')

  if [[ $(check_database_exists -n "$db_name") == "1" ]]; then
    create_database -n "$db_name" -u "$db_username" -p "$db_password"
  fi
}

prepare_sonar() {
  mkdir -p /var/log/sonarqube
  mkdir -p /var/lib/sonar
  mkdir -p /var/lib/sonar/downloads
  mkdir -p /tmp/sonar
  chown sonarqube:sonarqube -R /opt/sonarqube
  chown sonarqube:sonarqube /var/log/sonarqube
  chown sonarqube:sonarqube /var/lib/sonar
  chown sonarqube:sonarqube /var/lib/sonar/downloads
  chown sonarqube:sonarqube /tmp/sonar
  ln -s /opt/sonarqube/extensions/downloads /var/lib/sonar/downloads || true
}

main "$@"; exit

