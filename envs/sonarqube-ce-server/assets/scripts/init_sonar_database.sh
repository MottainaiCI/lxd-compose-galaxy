#!/bin/bash

# shellcheck disable=SC1090
set -e
source ./automation_tools.sh

main() {
  prepare_database
}

prepare_database() {

  db_version="$(echo $sonar_server_config | jq -M -r '.db.version')"
  db_version=${db_version:-"$POSTGRESQL_VERSION"}

  if [[ $(is_database_configured -v "$db_version") == "0" ]]; then
    init_database -v "$db_version"
    link_database_configs -v "$db_version"
    start_database -v "$db_version"
  fi

  db_name=$(echo "$sonar_server_config" | jq -M -r '.db.name')
  db_username=$(echo "$sonar_server_config" | jq -M -r '.db.username')
  db_password=$(echo "$sonar_server_config" | jq -M -r '.db.password')

  if [[ $(check_database_exists -n "$db_name") == "1" ]]; then
    create_database -n "$db_name" -u "$db_username" -p "$db_password"
  fi
}

main "$@"; exit

