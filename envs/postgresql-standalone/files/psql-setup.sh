#!/bin/bash
# Author: Daniele Rondina, geaaru@gmail.com
# Description: Script to create database 

if [ -n "$DEBUG" ] ; then
  set -x
fi

workfile=${workfile:-/tmp/initial_ddl.sql}
override_admin_pwd=${override_admin_pwd:-""}
dbrm_user=${dbrm_user:-postgres}

# DBRM OPTIONS
LOCAL_DIR=${LOCAL_DIR:-/root}
DRM_DB=${DRB_DB:-/root/dbrm.db}
POSTGRESQL_DIR="${POSTGRESQL_DIR:-/root}"
SQLCA=${SQLCA:-psql}
# I don't need multiple profiles here.
DRM_PROFILE=0
LOGFILE=${LOGFILE:-/tmp/dbrm.log}

export LOCAL_DIR DRM_DB POSTGRESQL_DIR SQLCA DRM_PROFILE LOGFILE

process_db_data() {
  local dbdata=$1

  local t=0
  local name=$(echo "${dbdata}" | jq .name -r)
  local encoding=$(echo "${dbdata}" | jq .encoding -r)
  local maintbs=$(echo "${dbdata}" | jq .maintbs -r)
  local admin=$(echo "${dbdata}" | jq .user -r)
  local pass=$(echo "${dbdata}" | jq .pass -r)
  local template=$(echo "${dbdata}" | jq .template -r)
  local ntablesp=$(echo "${dbdata}" | jq '.tablespaces | length')
  local location=""
  local tname=""
  local uname=""
  local upass=""

  if [ -n "${override_admin_pwd}" ] ; then
    pass="${override_admin_pwd}"
  fi

  echo "
CREATE USER ${admin} with PASSWORD '${pass}';
" > ${workfile}

  local nusers=$(echo "${dbdata}" | jq '.users | length')

  if [ ${nusers} -gt 0 ] ; then
    for ((u=0;u<${nusers};u++)); do
      uname=$(echo ${dbdata} | jq -r ".users[${u}].name")
      upass=$(echo ${dbdata} | jq -r ".users[${u}].pass")

      echo "
CREATE USER ${uname} WITH PASSWORD '${upass}';
" >> ${workfile}

    done
  fi


  if [ ${ntablesp} -gt 0 ] ; then
    for ((t=0;t<${ntablesp};t++)); do
      tname=$(echo "${dbdata}" | jq -r ".tablespaces[${t}].name")
      location=$(echo "${dbdata}" | jq -r ".tablespaces[${t}].location")

      echo "
CREATE TABLESPACE ${tname}
OWNER ${admin}
LOCATION '${location}';
" >> ${workfile}

      if [ ! -e ${location} ] ; then
        mkdir -p ${location}
        chown postgres:postgres -R ${location}
      fi

    done
  fi

  createdb="CREATE DATABASE ${name} WITH ENCODING='${encoding}' OWNER=${admin}"
  if [ -n "${maintbs}" ] ; then
    createdb="${createdb} TABLESPACE ${maintbs}"
  fi

  if [ -n "${template}" ] ; then
    createdb="${createdb} TEMPLATE ${template}"
  fi


  echo "
${createdb};
" >> ${workfile}

  local nschemas=$(echo "${dbdata}" | jq '.schemas | length')

  if [ ${nschemas} -gt 0 ] ; then

    # Enter on database
    echo "\c ${name}"

    for ((s=0;s<${nschemas};s++)); do
      sname=$(echo "${dbdata}" | jq -r ".schemas[${s}].name")
      suser=$(echo "${dbdata}" | jq -r ".schemas[${s}].user")

      echo "
CREATE SCHEMA ${sname} AUTHORIZATION ${suser};
ALTER USER ${suser} SET search_path TO ${sname}, public;

GRANT ALL ON SCHEMA ${sname} TO ${suser};

ALTER DATABASE ${name} SET search_path TO ${sname}, public;
" >> ${workfile}

    done


  fi

  echo "Executing workfile"
  cat ${workfile}
  echo -e "\n\n\n"

  echo "Compiling file ${workfile}..."
  dbrm psql compile --local -U ${dbrm_user} --file ${workfile}

  cat ${LOGFILE}

  rm ${LOGFILE} ${workfile}


  return 0
}

main () {

  if [ -z "${psql_databases}" ] ; then
    echo "No databases found. Exiting..."
    return 0
  fi

  ndb=$(echo "${psql_databases}" | jq ". | length")
  for ((i=0; i<${ndb}; i++)) ; do
    dbdata=$(echo "${psql_databases}" | jq -r ".[${i}]")
    process_db_data "${dbdata}" || return 1
  done

  return 0
}

main $@
exit $?
