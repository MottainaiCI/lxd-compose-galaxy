#!/bin/bash

# DEFAULTS
SONAR_HOST="localhost"
SONAR_PORT=9000
SONAR_START_DIR="/sonar"
SONAR_CREDENTIALS_DIR="/sonar/credentials"
SONAR_USERS_FILE="$SONAR_CREDENTIALS_DIR"/users.json
SONAR_NEW_USERS_FILE="$SONAR_CREDENTIALS_DIR"/new_users.json

### DATABASE (POSTGRESQL) FUNCTIONS #######################

is_database_configured() {
  # shellcheck disable=SC2010
  local has_postgresql_conf
  has_postgresql_conf="$(ls /var/lib/postgresql/10/data/ | grep postgresql.conf | wc -l)"
  echo "$has_postgresql_conf"
}

init_database() {
  su - postgres -c "initdb --auth-host=md5 -D /var/lib/postgresql/10/data -U postgres"
}

link_database_configs() {
  find /var/lib/postgresql/10/data/ -name '*.conf' -exec ln -s {} /etc/postgresql-10/ \;
}

start_database() {
  systemctl start postgresql-10
}

usage_check_database_exists() {
  echo "Usage: check_database_exists <-n string>" 1>&2
  echo "  - n     Database name to query on Postgresql"
}

check_database_exists() {
  local OPTIND o
  local database_name database_exists

    while getopts ":n:" o; do
    case "${o}" in
    n) database_name=${OPTARG} ;;
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

  if [[ -z "$database_name" ]]; then
    echo "ERROR: Missing Database name"
    usage_check_database_exists
    return 1
  else
    database_exists=$(echo "SELECT datname FROM pg_catalog.pg_database WHERE lower(datname) = lower('$database_name');" | su - postgres -c psql $database_name | grep -c "0 rows")
    echo "$database_exists"
  fi

  return 0
}

usage_create_database() {
  echo "Usage: create_database <-n string> <-u string> <-p string>" 1>&2
  echo "  - n     Database name to create on Postgresql"
  echo "  - u     Database User to create on Postgresql"
  echo "  - p     Database Password for user to create on Postgresql"
}

function create_database() {
  local OPTIND o
  local database_name database_user database_password


  while getopts ":n:u:p:" o; do
    case "${o}" in
    n) database_name=${OPTARG} ;;
    u) database_user=${OPTARG} ;;
    p) database_password=${OPTARG} ;;
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

  if [[ -z "$database_name" ]]; then
    echo "ERROR: Missing Database name"
    usage_create_database
    return 1
  elif [[ -z "$database_user" ]]; then
    echo "ERROR: Missing Database user"
    usage_create_database
    return 1
  elif [[ -z "$database_password" ]]; then
    echo "ERROR: Missing Database password"
    usage_create_database
    return 1
  else
    echo "CREATE DATABASE $database_name; CREATE USER $database_user WITH PASSWORD '$database_password'; GRANT ALL PRIVILEGES ON DATABASE $database_name TO $database_user;" | su - postgres -c psql
  fi

  return 0
}


### SONAR FUNCTIONS ##########################


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
  local host=$SONAR_HOST
  local port=$SONAR_PORT
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
      echo -n "Created user=$user on Sonar"
    fi
    return 0
  fi
}

# SIMPLE CREATE RANDOM PASSWORD (no configurability)

usage_generate_password() {
  echo "Usage: generate_password <override_password>" 1>&2
  echo "  <override_password>     Force return of provided override password (Optional). Useful for using in scripts"
}

generate_password() {
  local OPTIND o
  local abort=false
  local password="${1:-$(
    tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c${1:-32}
    echo
  )}"

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
  local response body status_code
  local user old_password new_password
  local admin_or_token
  local admin_password=""
  local protocol="http"
  local host=$SONAR_HOST
  local port=$SONAR_PORT
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

    response=$(
      curl \
        -q \
        -X POST \
        -H "Content-Type: application/json" \
        -w "%{http_code}" \
        -s \
        -k \
        -o /dev/null "$protocol"://"$admin_or_token":"$admin_password"@"$host":"$port"/"$url"?"$query"
    )
    # shellcheck disable=SC2206
    response=(${response[@]})              # convert to array
    status_code=${response[-1]}            # get last element (last line)
    # shellcheck disable=SC2124s
    body=${response[@]::${#response[@]}-1} # get all elements except last
    if [[ "$status_code" -ne 200 ]] && [[ $status_code -ne 201 ]] && [[ $status_code -ne 204 ]]; then
      echo "Cannot change user=$user password on Sonar, got HTTP status=$status_code" >&2
      # echo "Cannot change user=$user old_password=$old_password to new_password=$new_password on Sonar, got HTTP status=$status_code and body=$body" >&2
      return 1
    else
      echo -n "For Sonar user=$user, correctly set password=$new_password"
    fi
    return 0
  fi
}

# Same as change_password, but his function will be used directly by automation frameworks bypassing other logs
change_password_simple() {
  local result=$({ change_password "$@"; } 2>&1)
  local password=$(echo "$result" | grep -oP 'password=\K.*' | sed '/^[[:space:]]*$/d')
  echo -n "$password"
}

# CREATE USER TOKEN FUNCTIONS

usage_create_user_token() {
  echo "Usage: create_user_token <-a string> <-c string> [-H string] [-P number] [-S] user token_name" 1>&2
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
  local host=$SONAR_HOST
  local port=$SONAR_PORT
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
      echo -n "Correctly created token with name=$token_name for Sonar user=$user. Please, take note of token=$token"
    fi
    return 0

  fi
}

# Same as create_user_token, but his function will be used directly by automation frameworks bypassing other logs
create_user_token_simple() {
  local result=$({ create_user_token "$@"; } 2>&1)
  local token=$(echo "$result" | grep -oP 'token=\K.*' | sed '/^[[:space:]]*$/d')
  echo -n "$token"
}

# SET SONAR OPTIONS

usage_set_options() {
  echo "Usage: set_options <-a string> <-c string> [-H string] [-P number] [-S] [<sonar_opt_key>=<sonar_opt_value> string]" 1>&2
  echo "Note: Multiple sonar options are supported"
  echo "  - a     Sonar Admin Credential Username or Token (Mandatory)"
  echo "  - c     Sonar Admin Credential Password (Mandatory only if Username is used instead of Token)"
  echo "  - H     Sonar Host Address"
  echo "  - P     Sonar Port Address"
  echo "  - S     Use secure HTTPS over HTTP"
}

set_options() {

  local OPTIND o
  local response body status_code token
  local key value
  local admin_or_token
  local admin_password=""
  local protocol="http"
  local host=$SONAR_HOST
  local port=$SONAR_PORT
  local url="api/settings/set"
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
    esac
  done
  shift $((OPTIND - 1))

  for i in "$@"; do
    case $i in
    *=*)
      key="${i%%=*}"
      value="${i#*=}"
      query+="key=$key&value=$value&"
      shift # past argument=value
      ;;
    *)
      # unknown option
      echo "invalid option passed" >&2
      abort=true
      ;;
    esac
  done

  query=$(echo "$query" | sed 's/\&$//') # remove last "&" from query

  if [[ -z "$admin_or_token" ]]; then
    echo "ERROR: Missing Admin Username or Token"
    usage_set_options
    return 1
  elif [[ "$abort" == true ]]; then
    usage_set_options
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
    if [[ "$status_code" -ne 200 ]] && [[ $status_code -ne 201 ]] && [[ $status_code -ne 204 ]]; then
      echo "Cannot set options for Sonar, got HTTP status=$status_code" >&2
      return 1
    else
      echo -n "Correctly set options for Sonar."
    fi
    return 0

  fi

}

usage_check_user_exists() {
  echo "Usage: check_user_exists <-u string>" 1>&2
  echo "  - u     Sonar user name to check"
}

check_user_exists() {
  local OPTIND o
  local abort
  local user existing_users exists

  mkdir -p $SONAR_CREDENTIALS_DIR
  test -f $SONAR_USERS_FILE || echo $(jq -Rn '{users: []}') > $SONAR_USERS_FILE
  existing_users=("$(cat $SONAR_USERS_FILE | jq -r '.users[].username')")

  while getopts ":u:" o; do
    case "${o}" in
    u) user=${OPTARG} ;;
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

  if [[ -z "$user" ]]; then
    echo "ERROR: Missing User's Username"
    usage_check_user_exists
    return 1
  elif [[ "$abort" == true ]]; then
    usage_check_user_exists
    return 1
  else
    echo "$(array_contains $user ${existing_users[@]})"
  fi
  return 0
}

usage_check_user_has_token() {
  echo "Usage: check_has_token <-u string>" 1>&2
  echo "  - u     Sonar user name to check"
}

check_user_has_token() {
  local OPTIND o
  local abort
  local user existing_users has_token

  mkdir -p $SONAR_CREDENTIALS_DIR
  test -f $SONAR_USERS_FILE || echo $(jq -Rn '{users: []}') > $SONAR_USERS_FILE
  existing_users=("$(cat $SONAR_USERS_FILE | jq -r '.users[].username')")
  has_token="0"

  while getopts ":u:" o; do
    case "${o}" in
    u) user=${OPTARG} ;;
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

  if [[ -z "$user" ]]; then
    echo "ERROR: Missing User's Username"
    usage_check_user_has_token
    return 1
  elif [[ "$abort" == true ]]; then
    usage_check_user_has_token
    return 1
  elif [[ "$(array_contains $user ${existing_users[@]})" == "0" ]]; then
    echo "ERROR: Provided User does not exist"
    return 1
  else
    user_obj=$(jq  ".users[] | select(.username==\"$user\")" -M -r "$SONAR_USERS_FILE")
    [[ $(echo "$user_obj" | jq -M -r '.token') != null ]] && has_token="1" || has_token="0"
  fi
  echo "$has_token"
  return 0
}

# OTHER UTILITIES

has_sonar_already_started() {
  # shellcheck disable=SC2010
  local has_started
  mkdir -p $SONAR_START_DIR
  has_started="$(ls $SONAR_START_DIR | grep started | wc -l)"
  echo "$has_started"
}

set_sonar_started() {
  mkdir -p $SONAR_START_DIR
  touch $SONAR_START_DIR/started
}

array_contains () {
  local seeking=$1; shift
  local in=0
  for element; do
    if [[ $element == "$seeking" ]]; then
      in=1
      break
    fi
  done
  echo "$in"
}