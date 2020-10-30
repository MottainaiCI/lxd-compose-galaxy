#!/bin/bash
# Author: Daniele Rondina, geaaru@sabayonlinux.org

set -e

RESET_HTPASS="${nginx_reset_htpasswd:-0}"
HTPASSWD_OPTS="${HTPASSWD_OPTS:-}"

create_user () {
  local file=$1
  local user=$2
  local pwd=$3

  [ ! -e $file ] && {
    mkdir -p $(dirname $file) || true
    touch ${file}
  }

  htpasswd ${HTPASSWD_OPTS} -b ${file} ${user} ${pwd} || return 1

  return 0
}

main () {
  local i=""
  local z=""
  local user=""
  local pass=""

  if [ -n "${nginx_auth_basic_files}" ] ; then
    for i in $(echo "${nginx_auth_basic_files}" | jq -M -r -c '.[] | .path') ; do

      path_obj=$(echo "${nginx_auth_basic_files}" | jq -M ".[] | select(.path==\"$i\")")

      if [[ "${RESET_HTPASS}" == "1" ]] ; then
        rm -f ${i} || true
      fi

      for z in $(echo "${path_obj}" | jq -M -r -c '.users[] | .user') ; do
        pass=$(echo "${path_obj}" | jq -M -r -c ".users[] | select(.user==\"${z}\") | .pwd")

        echo "Creating/Updating file ${i} for user ${z}..."
        create_user "${i}" "${z}" "${pass}"
      done
    done
  fi

  return 0
}

main $@
exit $?
