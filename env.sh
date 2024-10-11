#!/bin/sh

# Pre-validate the environment
if [ "${CLICKHOUSE_DB}" = "**None**" -a "${CLICKHOUSE_DB_FILE}" = "**None**" ]; then
  echo "You need to set the CLICKHOUSE_DB or CLICKHOUSE_DB_FILE environment variable."
  exit 1
fi

if [ "${CLICKHOUSE_HOST}" = "**None**" ]; then
  if [ -n "${CLICKHOUSE_PORT_9000_TCP_ADDR}" ]; then
    CLICKHOUSE_HOST=${CLICKHOUSE_PORT_9000_TCP_ADDR}
    CLICKHOUSE_PORT=${CLICKHOUSE_PORT_9000_TCP_PORT}
  else
    echo "You need to set the CLICKHOUSE_HOST environment variable."
    exit 1
  fi
fi

if [ "${CLICKHOUSE_USER}" = "**None**" -a "${CLICKHOUSE_USER_FILE}" = "**None**" ]; then
  echo "You need to set the CLICKHOUSE_USER or CLICKHOUSE_USER_FILE environment variable."
  exit 1
fi

if [ "${CLICKHOUSE_PASSWORD}" = "**None**" -a "${CLICKHOUSE_PASSWORD_FILE}" = "**None**" -a "${CLICKHOUSE_PASSFILE_STORE}" = "**None**" ]; then
  echo "You need to set the CLICKHOUSE_PASSWORD or CLICKHOUSE_PASSWORD_FILE or CLICKHOUSE_PASSFILE_STORE environment variable or link to a container named CLICKHOUSE."
  exit 1
fi

#Process vars
if [ "${CLICKHOUSE_DB_FILE}" = "**None**" ]; then
  CLICKHOUSE_DBS=$(echo "${CLICKHOUSE_DB}" | tr , " ")
elif [ -r "${CLICKHOUSE_DB_FILE}" ]; then
  CLICKHOUSE_DBS=$(cat "${CLICKHOUSE_DB_FILE}")
else
  echo "Missing CLICKHOUSE_DB_FILE file."
  exit 1
fi
if [ "${CLICKHOUSE_USER_FILE}" = "**None**" ]; then
  export PGUSER="${CLICKHOUSE_USER}"
elif [ -r "${CLICKHOUSE_USER_FILE}" ]; then
  export PGUSER=$(cat "${CLICKHOUSE_USER_FILE}")
else
  echo "Missing CLICKHOUSE_USER_FILE file."
  exit 1
fi
if [ "${CLICKHOUSE_PASSWORD_FILE}" = "**None**" -a "${CLICKHOUSE_PASSFILE_STORE}" = "**None**" ]; then
  export PGPASSWORD="${CLICKHOUSE_PASSWORD}"
elif [ -r "${CLICKHOUSE_PASSWORD_FILE}" ]; then
  export PGPASSWORD=$(cat "${CLICKHOUSE_PASSWORD_FILE}")
elif [ -r "${CLICKHOUSE_PASSFILE_STORE}" ]; then
  export PGPASSFILE="${CLICKHOUSE_PASSFILE_STORE}"
else
  echo "Missing CLICKHOUSE_PASSWORD_FILE or CLICKHOUSE_PASSFILE_STORE file."
  exit 1
fi
export PGHOST="${CLICKHOUSE_HOST}"
export PGPORT="${CLICKHOUSE_PORT}"
KEEP_MINS=${BACKUP_KEEP_MINS}
KEEP_DAYS=${BACKUP_KEEP_DAYS}
KEEP_WEEKS=`expr $(((${BACKUP_KEEP_WEEKS} * 7) + 1))`
KEEP_MONTHS=`expr $(((${BACKUP_KEEP_MONTHS} * 31) + 1))`

# Validate backup dir
if [ '!' -d "${BACKUP_DIR}" -o '!' -w "${BACKUP_DIR}" -o '!' -x "${BACKUP_DIR}" ]; then
  echo "BACKUP_DIR points to a file or folder with insufficient permissions."
  exit 1
fi