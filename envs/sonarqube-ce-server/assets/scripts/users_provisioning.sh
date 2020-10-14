#!/bin/bash

# shellcheck disable=SC1090
set -e
source "$(dirname $0)"/automation_tools.sh

main() {
  load_sonar_admin_credentials
  create_new_users
}

create_new_users() {

  local username password user_password user_credentials

  echo "Creating new users..."

  mkdir -p "$SONAR_CREDENTIALS_DIR"
  test -f "$SONAR_USERS_FILE" || echo '{"users": []}' | jq -M -r > "$SONAR_USERS_FILE"

  for i in $(echo "$sonar_server_config" | jq -M -r -c '.users[]') ; do
    username=$(echo "$i" | jq -M -r '.username')
    password=$(echo "$i" | jq -M -r '.password')

    if [[ $(check_user_exists -u "$username") == "0" ]]; then
      # Create User
      user_password=${password:-"$(generate_password)"}
      create_user -a "$admin_user_or_token" -c "$admin_password" "$username" "$user_password"

      # Update User's file
      user_credentials=$(echo "{\"username\": \"$username\", \"password\": \"$user_password\"}" | jq -M -r)
      jq -M ".users + [${user_credentials}]" "$SONAR_USERS_FILE" | jq -n '.users |= inputs' > "$SONAR_USERS_FILE".tmp
      mv "$SONAR_USERS_FILE".tmp "$SONAR_USERS_FILE"
    else
      echo "User $username already exists, skipping creation..."
    fi

  done

  echo "Completed creation of new users."

}

main "$@"; exit
