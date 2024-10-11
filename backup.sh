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

mkdir -p "${BACKUP_DIR}/last/" "${BACKUP_DIR}/daily/" "${BACKUP_DIR}/weekly/" "${BACKUP_DIR}/monthly/"

# Цикл по всем базам данных
for DB in ${CLICKHOUSE_DBS}; do
  # Инициализация имен файлов
  LAST_FILENAME="${DB}-$(date +%Y%m%d-%H%M%S)${BACKUP_SUFFIX}"
  DAILY_FILENAME="${DB}-$(date +%Y%m%d)${BACKUP_SUFFIX}"
  WEEKLY_FILENAME="${DB}-$(date +%G%V)${BACKUP_SUFFIX}"
  MONTHLY_FILENAME="${DB}-$(date +%Y%m)${BACKUP_SUFFIX}"

  FILE="$BACKUP_DIR/last/${LAST_FILENAME}"
  DFILE="$BACKUP_DIR/daily/${DAILY_FILENAME}"
  WFILE="$BACKUP_DIR/weekly/${WEEKLY_FILENAME}"
  MFILE="$BACKUP_DIR/monthly/${MONTHLY_FILENAME}"

  # Создание резервной копии
  echo "Создание резервной копии базы данных ${DB} с хоста ${CLICKHOUSE_HOST}..."
  clickhouse-client --host="${CLICKHOUSE_HOST}" --query="BACKUP DATABASE ${DB} TO Disk('backups', '${LAST_FILENAME}');"

  if [ ! -f "${BACKUP_DIR}/${LAST_FILENAME}" ]; then
      echo "Ошибка: файл резервной копии ${LAST_FILENAME} не найден."
      exit 1
  else
      mv "${BACKUP_DIR}/${LAST_FILENAME}" "$FILE"
  fi


  # Проверка успешности создания резервной копии
  if [ $? -ne 0 ]; then
      echo "Ошибка создания резервной копии базы данных ${DB}!"
      exit 1
  fi

  # Проверка, что файл резервной копии существует
  if [ ! -f "${FILE}" ]; then
      echo "Ошибка: файл резервной копии ${FILE} не найден."
      exit 1
  fi

  if [ -d "${FILE}" ]; then
    DFILENEW="${DFILE}-new"
    WFILENEW="${WFILE}-new"
    MFILENEW="${MFILE}-new"
    rm -rf "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
    mkdir "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
    (
      # Позволяет создать больше жестких ссылок, чем максимальная длина списка аргументов
      # Сначала переходим в директорию, чтобы избежать возможных проблем с пространством в BACKUP_DIR
      cd "${FILE}"
      for F in *; do
        ln -f "$F" "${DFILENEW}/"
        ln -f "$F" "${WFILENEW}/"
        ln -f "$F" "${MFILENEW}/"
      done
    )
    rm -rf "${DFILE}" "${WFILE}" "${MFILE}"
    echo "Замена ежедневной резервной копии ${DFILE} последней резервной копией..."
    mv "${DFILENEW}" "${DFILE}"
    echo "Замена еженедельной резервной копии ${WFILE} последней резервной копией..."
    mv "${WFILENEW}" "${WFILE}"
    echo "Замена ежемесячной резервной копии ${MFILE} последней резервной копией..."
    mv "${MFILENEW}" "${MFILE}"
  else
    echo "Замена ежедневной резервной копии ${DFILE} последней резервной копией..."
    ln -vf "${FILE}" "${DFILE}"
    echo "Замена еженедельной резервной копии ${WFILE} последней резервной копией..."
    ln -vf "${FILE}" "${WFILE}"
    echo "Замена ежемесячной резервной копии ${MFILE} последней резервной копией..."
    ln -vf "${FILE}" "${MFILE}"
  fi

  # Обновление символических ссылок на последние резервные копии
  LATEST_LN_ARG=""
  if [ "${BACKUP_LATEST_TYPE}" = "symlink" ]; then
    LATEST_LN_ARG="-s"
  fi
  if [ "${BACKUP_LATEST_TYPE}" = "symlink" -o "${BACKUP_LATEST_TYPE}" = "hardlink" ]; then
    echo "Установка последней резервной копии на эту последнюю резервную копию..."
    ln "${LATEST_LN_ARG}" -vf "${LAST_FILENAME}" "${BACKUP_DIR}/last/${DB}-latest${BACKUP_SUFFIX}"
    echo "Установка последней ежедневной резервной копии на эту последнюю резервную копию..."
    ln "${LATEST_LN_ARG}" -vf "${DAILY_FILENAME}" "${BACKUP_DIR}/daily/${DB}-latest${BACKUP_SUFFIX}"
    echo "Установка последней еженедельной резервной копии на эту последнюю резервную копию..."
    ln "${LATEST_LN_ARG}" -vf "${WEEKLY_FILENAME}" "${BACKUP_DIR}/weekly/${DB}-latest${BACKUP_SUFFIX}"
    echo "Установка последней ежемесячной резервной копии на эту последнюю резервную копию..."
    ln "${LATEST_LN_ARG}" -vf "${MONTHLY_FILENAME}" "${BACKUP_DIR}/monthly/${DB}-latest${BACKUP_SUFFIX}"
  else # [ "${BACKUP_LATEST_TYPE}" = "none" ]
    echo "Не обновляется последняя резервная копия."
  fi

  # Очистка старых файлов
  echo "Очистка старых файлов для базы данных ${DB} с хоста ${CLICKHOUSE_HOST}..."
  find "${BACKUP_DIR}/last" -maxdepth 1 -mmin "+${KEEP_MINS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime "+${KEEP_DAYS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime "+${KEEP_WEEKS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
  find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime "+${KEEP_MONTHS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
done

echo "SQL резервная копия успешно создана"

# Post-backup hook
if [ -d "${HOOKS_DIR}" ]; then
  run-parts -a "post-backup" --reverse --exit-on-error "${HOOKS_DIR}"
fi