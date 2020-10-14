#!/bin/bash

# shellcheck disable=SC1090
set -e
source ./automation_tools.sh

main() {
  load_sonar_admin_credentials
  create_missing_tokens
}

create_missing_tokens() {

  local username token_name generated_token token_credentials

  echo "Creating missing tokens..."

  mkdir -p "$SONAR_CREDENTIALS_DIR"
  test -f "$SONAR_USERS_FILE" || echo '{"users": []}' | jq -M -r > "$SONAR_USERS_FILE"

  for i in $(echo "$sonar_server_config" | jq -M -r -c '.users[]') ; do
    username=$(echo "$i" | jq -M -r '.username')
    token_name="$username-token"

    if [[ $(check_user_has_token -u "$username") == "0" ]]; then
      # Generate token
      echo "Generating token for user $username..."
      generated_token=$(create_user_token_simple -a "$admin_user_or_token" -c "$admin_password" "$username" "$token_name")

      # Update users file
      token_credentials="{\"token_name\": \"$token_name\", \"token\": \"$generated_token\"}"
      echo $(jq "walk (if type==\"object\" and .username==\"$username\" then . +=$token_credentials else . end)" -M -r "$SONAR_USERS_FILE") | \
        jq -M -r > $SONAR_USERS_FILE.tmp

      mv "$SONAR_USERS_FILE".tmp "$SONAR_USERS_FILE"
      echo "Generated token for user $username."
    else
       echo "User $username already has token, skipping generation..."
    fi

  done

  echo "Completed creation of missing tokens."

}

main "$@"; exit
