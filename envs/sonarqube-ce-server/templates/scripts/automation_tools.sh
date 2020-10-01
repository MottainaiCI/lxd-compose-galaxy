#!/bin/bash

# DEFAULTS
HOST="localhost"
PORT=9000


# CREATE USER FUNCTIONS

usage_create_user() {
  echo "Usage: create_user <-a string> <-c string> [-H string] [-P number] [-S] user password" 1>&2
  echo "  - a     Sonar Admin Credential Username or Token (Mandatory)"
  echo "  - c     Sonar Admin Credential Password (Mandatory only if Username is used instead of Token)"
  echo "  - H     Sonar Host Address"
  echo "  - P     Sonar Port Address"
  echo "  - S     Use secure HTTPS over HTTP"
}

create_user() {
  local OPTIND o
  local status_code
  local user password
  local admin_or_token
  local admin_password=""
  local protocol="http"
  local host=$HOST
  local port=$PORT
  local url="api/users/create"
  local query
  local abort=false

  while getopts ":a:c:H:P:U:S" o; do
    case "${o}" in
    a) admin_or_token=${OPTARG} ;;
    c) admin_password=${OPTARG} ;;
    H) host=${OPTARG} ;;
    P) port=${OPTARG} ;;
    U) url=${OPTARG} ;;
    S) protocol="https" ;;
    :)
      echo "ERROR: Option -$OPTARG requires an argument"
      abort=true
      ;;
    \?)
      echo "ERROR: Invalid option -$OPTARG"
      abort=true
      ;;
    esac
  done
  shift $((OPTIND - 1))

  user=$1
  password=$2
  query="login=$user&name=$user&password=$password"

  if [[ -z "$admin_or_token" ]]; then
    echo "ERROR: Missing Admin Username or Token"
    usage_create_user
    return 1
  elif [[ -z "$user" ]]; then
    echo "ERROR: Missing User's Username"
    usage_create_user
    return 1
  elif [[ -z "$password" ]]; then
    echo "ERROR: Missing User's Password"
    usage_create_user
    return 1
  elif [[ "$abort" == true ]]; then
    usage_create_user
    return 1
  else

    if [[ -z "$admin_password" ]]; then
      echo "NOTE: No Admin Password set. Admin Username Field will be used as API Token..."
    fi

    status_code=$(
      curl \
        -X POST \
        -H "Content-Type: application/json" \
        -w "%{http_code}" \
        -s \
        -k \
        -o /dev/null "$protocol"://"$admin_or_token":"$admin_password"@"$host":"$port"/"$url"?"$query"
    )
    if [[ "$status_code" -ne 200 ]] && [[ $status_code -ne 201 ]]; then
      echo "Cannot create user=$user on Sonar, got HTTP status=$status_code" >&2
      return 1
    else
      echo "Created user=$user on Sonar"
    fi
    return 0
  fi
}



# SIMPLE CREATE RANDOM PASSWORD (no configurability)

usage_generate_password() {
  echo "Usage: create_user <override_password>" 1>&2
  echo "  <override_password>     Force return of provided override password (Optional). Useful for using in scripts"
}

generate_password() {
  local OPTIND o
  local abort=false
  local password="${1:-$(openssl rand -base64 25)}"

  echo "$password"
  return 0
}



# CHANGE PASSWORD FUNCTIONS (BY ADMIN)

usage_change_password() {
  echo "Usage: change_password <-a string> <-c string> [-H string] [-P number] [-S] user old_password new_password" 1>&2
  echo "  - a     Sonar Admin Credential Username or Token (Mandatory)"
  echo "  - c     Sonar Admin Credential Password (Mandatory only if Username is used instead of Token)"
  echo "  - H     Sonar Host Address"
  echo "  - P     Sonar Port Address"
  echo "  - S     Use secure HTTPS over HTTP"
}

change_password() {
  local OPTIND o
  local status_code
  local user old_password new_password
  local admin_or_token
  local admin_password=""
  local protocol="http"
  local host=$HOST
  local port=$PORT
  local url="api/users/change_password"
  local query
  local abort=false

  while getopts ":a:c:H:P:U:S" o; do
    case "${o}" in
    a) admin_or_token=${OPTARG} ;;
    c) admin_password=${OPTARG} ;;
    H) host=${OPTARG} ;;
    P) port=${OPTARG} ;;
    U) url=${OPTARG} ;;
    S) protocol="https" ;;
    :)
      echo "ERROR: Option -$OPTARG requires an argument"
      abort=true
      ;;
    \?)
      echo "ERROR: Invalid option -$OPTARG"
      abort=true
      ;;
    esac
  done
  shift $((OPTIND - 1))

  user=$1
  old_password=$2
  new_password=$3
  query="login=$user&previousPassword=$old_password&password=$new_password"

  if [[ -z "$admin_or_token" ]]; then
    echo "ERROR: Missing Admin Username or Token"
    usage_change_password
    return 1
  elif [[ -z "$user" ]]; then
    echo "ERROR: Missing User's Username"
    usage_change_password
    return 1
  elif [[ -z "$old_password" ]]; then
    echo "ERROR: Missing User's Old Password"
    usage_change_password
    return 1
  elif [[ -z "$new_password" ]]; then
    echo "ERROR: Missing User's New Password"
    usage_change_password
    return 1
  elif [[ "$abort" == true ]]; then
    usage_change_password
    return 1
  else

    if [[ -z "$admin_password" ]]; then
      echo "NOTE: No Admin Password set. Admin Username Field will be used as API Token..."
    fi

    status_code=$(
      curl \
        -X POST \
        -H "Content-Type: application/json" \
        -w "%{http_code}" \
        -s \
        -k \
        -o /dev/null "$protocol"://"$admin_or_token":"$admin_password"@"$host":"$port"/"$url"?"$query"
    )
    if [[ "$status_code" -ne 200 ]] && [[ $status_code -ne 201 ]] && [[ $status_code -ne 204 ]]; then
      echo "Cannot change user=$user password on Sonar, got HTTP status=$status_code" >&2
      return 1
    else
      echo "Changed password for user=$user on Sonar"
    fi
    return 0
  fi
}



# CREATE USER TOKEN FUNCTIONS

usage_create_user_token() {
  echo "Usage: create_user_token <-u string> <-p string> [-H string] [-P number] [-S] user token_name" 1>&2
  echo "  - a     Sonar Admin Credential Username or Token (Mandatory)"
  echo "  - c     Sonar Admin Credential Password (Mandatory only if Username is used instead of Token)"
  echo "  - H     Sonar Host Address"
  echo "  - P     Sonar Port Address"
  echo "  - S     Use secure HTTPS over HTTP"
}

# User friendly function with logs
create_user_token() {
  local OPTIND o
  local response body status_code token
  local user token_name
  local admin_or_token
  local admin_password=""
  local protocol="http"
  local host=$HOST
  local port=$PORT
  local url="api/user_tokens/generate"
  local query=""
  local abort=false

  while getopts ":a:c:H:P:U:S" o; do
    case "${o}" in
    a) admin_or_token=${OPTARG} ;;
    c) admin_password=${OPTARG} ;;
    H) host=${OPTARG} ;;
    P) port=${OPTARG} ;;
    U) url=${OPTARG} ;;
    S) protocol="https" ;;
    :)
      echo "ERROR: Option -$OPTARG requires an argument"
      abort=true
      ;;
    \?)
      echo "ERROR: Invalid option -$OPTARG"
      abort=true
      ;;
    esac
  done
  shift $((OPTIND - 1))

  user=$1
  token_name=$2
  query="login=$user&name=$token_name"

  if [[ -z "$admin_or_token" ]]; then
    echo "ERROR: Missing Admin Username or Token"
    usage_create_user_token
    return 1
  elif [[ -z "$user" ]]; then
    echo "ERROR: Missing User's Username"
    usage_create_user_token
    return 1
  elif [[ -z "$token_name" ]]; then
    echo "ERROR: Missing User's Token Name"
    usage_create_user_token
    return 1
  elif [[ "$abort" == true ]]; then
    usage_create_user_token
    return 1
  else
    if [[ -z "$admin_password" ]]; then
      echo "NOTE: No Admin Password set. Admin Username Field will be used as API Token..."
    fi

    response=$(
      curl \
        -X POST \
        -H "Content-Type: application/json" \
        -w "\n%{http_code}" \
        -s \
        "$protocol"://"$admin_or_token":"$admin_password"@"$host":"$port"/"$url"?"$query"
    )
    # shellcheck disable=SC2206
    response=(${response[@]})              # convert to array
    status_code=${response[-1]}            # get last element (last line)
    # shellcheck disable=SC2124s
    body=${response[@]::${#response[@]}-1} # get all elements except last
    token=$(echo "$body" | jq -r '.token')
    if [[ "$status_code" -ne 200 ]] && [[ $status_code -ne 201 ]]; then
      echo "Cannot create token with name=$token_name for Sonar user=$user, got HTTP status=$status_code" >&2
      return 1
    else
      echo "Correctly created token with name=$token_name for Sonar user=$user. Please, take note of token=$token"
    fi
    return 0

  fi
}

# Same as create_user_token, but his function will be used directly by automation frameworks bypassing all logs
create_user_token_simple() {
  local result=$({ create_user_token "$@"; } 2>&1)
  local token=$(echo "$result" | grep -oP 'token=\K.*')
  echo "$token"
}
