#!/bin/bash

source ./automation_tools.sh

if [[ "$(is_sonar_ready)" == "0" ]]; then

  echo "Configuring Admin..."
  # Prepare admin with new password and token
  admin_username=$(echo "$sonar_server_config" | jq -M -r '.admin.username')
  admin_previous_password="$(echo "$sonar_server_config" | jq -M -r '.admin.previous_password')"
  generated_password="$(generate_password)"
  new_password=$(change_password_simple -a "$admin_username" -c "$admin_previous_password" "$admin_username" "$admin_previous_password" "$generated_password")
  token_name="$admin_username"-token
  generated_token=$(create_user_token_simple -a "$admin_username" -c "$new_password" "$admin_username" "$token_name")

  # Update Admin credential file
  admin_credentials="{\"username\": \"$admin_username\", \"password\": \"$new_password\", \"token_name\": \"$token_name\", \"token\": \"$generated_token\"}"
  admin_credentials=$(echo "$admin_credentials" | jq -M -r)
  mkdir -p "$SONAR_CREDENTIALS_DIR"
  echo "$admin_credentials" > "$SONAR_ADMIN_FILE"

  set_sonar_ready
  echo "Configured Admin."
else
  echo "Admin is already configured."
fi
