#!/bin/bash

# shellcheck disable=SC1090
source "$(dirname $0)"/automation_tools.sh

if [[ -z "$sonar_admin_password" ]]; then
   admin_user_or_token="$sonar_admin_token"
   admin_password=""
elif [[ -z "$sonar_admin_token" ]]; then
   admin_user_or_token=admin
   admin_password="$sonar_admin_password"
else
   echo "An Admin Token or Password should be provided" >&2
fi

options=()
for i in $(echo "$sonar_server_config" | jq -M -r -c '.options[]') ; do
  key=$(echo "$i" | jq -M -r '.key')
  value=$(echo "$i" | jq -M -r '.value')
  options+=("$key\=$value")
done
set_options -a "$admin_user_or_token" -c "$admin_password"  "${options[@]}"