#!/bin/sh

set -Eeo pipefail

HOOKS_DIR="/hooks"
if [ -d "${HOOKS_DIR}" ]; then
  on_error(){
    run-parts -a "error" "${HOOKS_DIR}"
  }
  trap 'on_error' ERR
fi

source "$(dirname "$0")/env.sh"

# Pre-backup hook
if [ -d "${HOOKS_DIR}" ]; then
  run-parts -a "pre-backup" --exit-on-error "${HOOKS_DIR}"
fi

#Initialize dirs
mkdir -p "${BACKUP_DIR}/last/" "${BACKUP_DIR}/daily/" "${BACKUP_DIR}/weekly/" "${BACKUP_DIR}/monthly/"

#Loop all databases
for DB in ${CLICKHOUSE_DBS}; do
  #Initialize filename vers
  LAST_FILENAME="${DB}-$(date +%Y%m%d-%H%M%S)${BACKUP_SUFFIX}"
  DAILY_FILENAME="${DB}-$(date +%Y%m%d)${BACKUP_SUFFIX}"
  WEEKLY_FILENAME="${DB}-$(date +%G%V)${BACKUP_SUFFIX}"
  MONTHLY_FILENAME="${DB}-$(date +%Y%m)${BACKUP_SUFFIX}"

  FILE="$BACKUP_DIR/last/${LAST_FILENAME}"
  DFILE="$BACKUP_DIR/daily/${DAILY_FILENAME}"
  WFILE="$BACKUP_DIR/weekly/${WEEKLY_FILENAME}"
  MFILE="$BACKUP_DIR/monthly/${MONTHLY_FILENAME}"

  #Create dump
  echo "Creating dump of ${DB} database from ${CLICKHOUSE_HOST}..."
  clickhouse-client --host="${CLICKHOUSE_HOST}" --receive_timeout=${RECEIVE_TIMEOUT} --send_timeout=${SEND_TIMEOUT} --query="BACKUP DATABASE ${DB} TO Disk('backups', '${LAST_FILENAME}');"

  if [ ! -f "${BACKUP_DIR}/${LAST_FILENAME}" ]; then
      echo "Error: backup file ${LAST_FILENAME} not found."
      exit 1
  else
      mv "${BACKUP_DIR}/${LAST_FILENAME}" "$FILE"
  fi


# Check if the backup was created successfully
  if [ $? -ne 0 ]; then
      echo "Error creating backup for database ${DB}!"
      exit 1
  fi

# Check if the backup file exists
  if [ ! -f "${FILE}" ]; then
      echo "Error: backup file ${FILE} not found."
      exit 1
  fi

  if [ -d "${FILE}" ]; then
    DFILENEW="${DFILE}-new"
    WFILENEW="${WFILE}-new"
    MFILENEW="${MFILE}-new"
    rm -rf "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
    mkdir "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
    (
      # Allow to hardlink more files than max arg list length
      # first CHDIR to avoid possible space problems with BACKUP_DIR
      cd "${FILE}"
      for F in *; do
        ln -f "$F" "${DFILENEW}/"
        ln -f "$F" "${WFILENEW}/"
        ln -f "$F" "${MFILENEW}/"
      done
    )
    rm -rf "${DFILE}" "${WFILE}" "${MFILE}"
    echo "Replacing daily backup ${DFILE} folder this last backup..."
    mv "${DFILENEW}" "${DFILE}"
    echo "Replacing weekly backup ${WFILE} folder this last backup..."
    mv "${WFILENEW}" "${WFILE}"
    echo "Replacing monthly backup ${MFILE} folder this last backup..."
    mv "${MFILENEW}" "${MFILE}"
  else
    echo "Replacing daily backup ${DFILE} file this last backup..."
    ln -vf "${FILE}" "${DFILE}"
    echo "Replacing weekly backup ${WFILE} file this last backup..."
    ln -vf "${FILE}" "${WFILE}"
    echo "Replacing monthly backup ${MFILE} file this last backup..."
    ln -vf "${FILE}" "${MFILE}"
  fi

  # Update latest symlinks
  LATEST_LN_ARG=""
  if [ "${BACKUP_LATEST_TYPE}" = "symlink" ]; then
    LATEST_LN_ARG="-s"
  fi
  if [ "${BACKUP_LATEST_TYPE}" = "symlink" -o "${BACKUP_LATEST_TYPE}" = "hardlink" ]; then
    echo "Point last backup file to this last backup..."
    ln "${LATEST_LN_ARG}" -vf "${LAST_FILENAME}" "${BACKUP_DIR}/last/${DB}-latest${BACKUP_SUFFIX}"
    echo "Point latest daily backup to this last backup..."
    ln "${LATEST_LN_ARG}" -vf "${DAILY_FILENAME}" "${BACKUP_DIR}/daily/${DB}-latest${BACKUP_SUFFIX}"
    echo "Point latest weekly backup to this last backup..."
    ln "${LATEST_LN_ARG}" -vf "${WEEKLY_FILENAME}" "${BACKUP_DIR}/weekly/${DB}-latest${BACKUP_SUFFIX}"
    echo "Point latest monthly backup to this last backup..."
    ln "${LATEST_LN_ARG}" -vf "${MONTHLY_FILENAME}" "${BACKUP_DIR}/monthly/${DB}-latest${BACKUP_SUFFIX}"
  else # [ "${BACKUP_LATEST_TYPE}" = "none" ]
    echo "Not updating lastest backup."
  fi

  #Clean old files
  echo "Cleaning older files for ${DB} database from ${CLICKHOUSE_HOST}..."
  find "${BACKUP_DIR}/last" -maxdepth 1 -mmin "+${KEEP_MINS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime "+${KEEP_DAYS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime "+${KEEP_WEEKS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime "+${KEEP_MONTHS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
done

echo "SQL backup created successfully"

# Post-backup hook
if [ -d "${HOOKS_DIR}" ]; then
  run-parts -a "post-backup" --reverse --exit-on-error "${HOOKS_DIR}"
fi