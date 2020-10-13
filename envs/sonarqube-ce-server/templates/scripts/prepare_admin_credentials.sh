#!/bin/bash

# shellcheck disable=SC1090
source "$(dirname $0)"/automation_tools.sh

if [[ "$(has_sonar_already_started)" == "0" ]]; then
   admin_username=$(echo "$sonar_server_config" | jq -M -r '.admin.username')
   admin_previous_password="$(echo "$sonar_server_config" | jq -M -r '.admin.previous_password')"
   generated_password="$(generate_password)"
   new_password=$(change_password_simple -a "$admin_username" -c "$admin_previous_password" "$admin_username" "$admin_previous_password" "$generated_password")
   token_name="$admin_username"-token
   generated_token=$(create_user_token_simple -a "$admin_username" -c "$new_password" "$admin_username" "$token_name")
   echo -n "$generated_token"
else
   # DEBUG: For now, I rely on fact that admin token is set on groups/sonar-ce.yaml to tmp. You should fix and read from correct file
   echo -n "$(cat /tmp/sonar_admin_token)"
fi
