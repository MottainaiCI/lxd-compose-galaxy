#!/bin/bash
# Author: Daniele Rondina, geaaru@sabayonlinux.org

create_admin () {
  local adminDb=$(echo ${mongodb_replica_set} | jq '.superuser.db' -r)
  local user=$(echo ${mongodb_replica_set} | jq '.superuser.user' -r)
  local pwd=$(echo ${mongodb_replica_set} | jq '.superuser.pwd' -r)
  local roles=$(echo ${mongodb_replica_set} | jq '.superuser.roles' -Mc)

  create_user "${adminDb}" "${user}" "${pwd}" "${roles}" "0" || return 1
  return 0
}

create_users () {
  local i=""
  local user=""
  local usr=""
  local pass=""
  local db=""
  local roles=""

  for i in $(echo "${mongodb_replica_set}" | jq -M -r -c '.users[].user') ; do

    user=$(echo "${mongodb_replica_set}" | jq -M ".users[] | select(.user==\"$i\")")

    db=$(echo "${user}" | jq -M -r ".db")
    usr=$(echo "${user}" | jq -M -r ".user")
    pass=$(echo "${user}" | jq -M -r ".pwd")
    roles=$(echo "${user}" | jq -Mc ".roles")

    create_user "${db}" "${usr}" "${pass}" "${roles}" "1" || return 1
  done

  return 0
}

create_user () {
  local adminDb=$1
  local user=$2
  local pwd=$3
  local roles=$4
  local withCredential=$5

  local adminUser=$(echo ${mongodb_replica_set} | jq '.superuser.user' -r) && \
  local adminPass=$(echo ${mongodb_replica_set} | jq '.superuser.pwd' -r) && \

  echo "
sleep(5000)
admin = db.getSiblingDB('${adminDb}')
" > /tmp/mongo-user.js

  if [ "$pwd" == "false" ] ; then
    echo "
admin.createUser({
  user: \"${user}\",
  roles: ${roles}
})" >> /tmp/mongo-user.js

  else

    echo "
admin.createUser({
  user: \"${user}\",
  pwd: \"${pwd}\",
  roles: ${roles}
})" >> /tmp/mongo-user.js

  fi

  if [ $withCredential = "0" ] ; then
    mongo /tmp/mongo-user.js || return 1
  else
    mongo -u "${adminUser}" -p "${adminPass}" /tmp/mongo-user.js || return 1
  fi

  #rm /tmp/mongo-user.js

  return 0
}

join () {
  local user=$(echo ${mongodb_replica_set} | jq '.superuser.user' -r)
  local pwd=$(echo ${mongodb_replica_set} | jq '.superuser.pwd' -r)
  local port=$(echo ${mongo_config} | jq '.net.port' -r)

  local node_name=$(echo ${node} | jq '.name' -r)
  local domain=$(echo ${mongodb_replica_set} | jq '.net_domain' -r)
  local node=""
 
  # Workaround to weird issue on parse json on for"
  echo "${project}" > /tmp/project.env

  for i in $(cat /tmp/project.env | jq '.groups[0].nodes[].name' -r); do
    node="${i}"
    if [ -n "${domain}" ] ; then
      node="${node}.${domain}"
    fi
    node="${node}:${port}"

    if [ "${node_name}" != "$i" ] ; then
      echo "Joining node ${node}..."
      echo "rs.add('${node}')" | mongo -u ${user} -p ${pwd} || return 1
    fi
  done

  rm /tmp/project.env

  return 0
}

main () {

  _parse_args () {

    _help () {

      echo "Copyright (c) 2020 Daniele Rondina

Mongo Setup script.

Example:

  $> mongo-setup.sh <command> [OPTS]

Available commands:

* admin: Create admin users

* users: Create standard users

* cluster: Join node to cluster

"
      return 0

    }

    if [ $# -eq 0 ] ; then
      _help
      exit 1
    fi

    local short_opts="h"
    local long_opts="help"

    MONGO_OPERATION=$1
    shift

    case "$MONGO_OPERATION" in
      admin|users|join)
        ;;
      *)
        echo "Invalid command $1"
        exit 1
        ;;
    esac

    while [ $# -gt 0 ] ; do
      case "$1" in
        -h|--help)
          _help
          exit 1
          ;;
        *)
          echo "Invalid parameter $1"
          exit 1
       esac
       shift
    done

    return 0
  }

  _parse_args "$@"

  unset -f _parse_args

  case "$MONGO_OPERATION" in
    admin)
      create_admin || return 1
      ;;
    users)
      create_users || return 1
      ;;
    join)
      join || return 1
      ;;
  esac

  return 0
}

main "$@"
exit $?
