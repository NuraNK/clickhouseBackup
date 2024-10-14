#!/bin/sh

# Pre-validate the environment
if [ "${CLICKHOUSE_DB}" = "**None**" ]; then
  echo "You need to set the CLICKHOUSE_DB environment variable."
  exit 1
fi

if [ "${CLICKHOUSE_HOST}" = "**None**" ]; then
  echo "You need to set the CLICKHOUSE_HOST environment variable."
  exit 1
fi

if [ "${CLICKHOUSE_USER}" = "**None**" ]; then
  echo "You need to set the CLICKHOUSE_USER environment variable."
  exit 1
fi

if [ "${CLICKHOUSE_PASSWORD}" = "**None**" ]; then
  echo "You need to set the CLICKHOUSE_PASSWORD environment variable or link to a container named CLICKHOUSE."
  exit 1
fi

export CLICKHOUSE_DBS=$(echo "${CLICKHOUSE_DB}" | tr , " ")

KEEP_MINS=${BACKUP_KEEP_MINS}
KEEP_DAYS=${BACKUP_KEEP_DAYS}
KEEP_WEEKS=`expr $(((${BACKUP_KEEP_WEEKS} * 7) + 1))`
KEEP_MONTHS=`expr $(((${BACKUP_KEEP_MONTHS} * 31) + 1))`

# Validate backup dir
if [ '!' -d "${BACKUP_DIR}" -o '!' -w "${BACKUP_DIR}" -o '!' -x "${BACKUP_DIR}" ]; then
  echo "BACKUP_DIR points to a file or folder with insufficient permissions."
  exit 1
fi