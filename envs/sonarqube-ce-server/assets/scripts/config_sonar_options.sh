#!/bin/bash

# shellcheck disable=SC1090
set -e
source "$(dirname $0)"/automation_tools.sh

main() {
  load_sonar_admin_credentials
  config_options
}

config_options() {
  local key value
  local options=()
  for i in $(echo "$sonar_server_config" | jq -M -r -c '.options[]') ; do
    key=$(echo "$i" | jq -M -r '.key')
    value=$(echo "$i" | jq -M -r '.value')
    options+=("$key\=$value")
  done
  set_options -a "$admin_user_or_token" -c "$admin_password"  "${options[@]}"
}

main "$@"; exit
