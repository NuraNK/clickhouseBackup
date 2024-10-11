ARG BASETAG=alpine
FROM clickhouse/clickhouse-server:24.8.4.13-alpine

ARG GOCRONVER=v0.0.11
ARG TARGETOS
ARG TARGETARCH

RUN set -x \
    && apk update && apk add --no-cache ca-certificates curl \
    && curl --fail --retry 4 --retry-all-errors -L https://github.com/prodrigestivill/go-cron/releases/download/$GOCRONVER/go-cron-$TARGETOS-$TARGETARCH-static.gz | zcat > /usr/local/bin/go-cron \
    && chmod a+x /usr/local/bin/go-cron

ENV CLICKHOUSE_DB="**None**" \
    CLICKHOUSE_DB_FILE="**None**" \
    CLICKHOUSE_HOST="**None**" \
    CLICKHOUSE_PORT=9000 \
    CLICKHOUSE_USER="**None**" \
    CLICKHOUSE_USER_FILE="**None**" \
    CLICKHOUSE_PASSWORD="**None**" \
    CLICKHOUSE_PASSWORD_FILE="**None**" \
    CLICKHOUSE_PASSFILE_STORE="**None**" \
    SCHEDULE="@daily" \
    BACKUP_ON_START="FALSE" \
    BACKUP_DIR="/backups" \
    BACKUP_SUFFIX=".zip" \
    BACKUP_LATEST_TYPE="symlink" \
    BACKUP_KEEP_DAYS=7 \
    BACKUP_KEEP_WEEKS=4 \
    BACKUP_KEEP_MONTHS=6 \
    BACKUP_KEEP_MINS=1440 \
    HEALTHCHECK_PORT=8080 \
    WEBHOOK_URL="**None**" \
    WEBHOOK_ERROR_URL="**None**" \
    WEBHOOK_PRE_BACKUP_URL="**None**" \
    WEBHOOK_POST_BACKUP_URL="**None**" \
    WEBHOOK_EXTRA_ARGS=""

COPY hooks /hooks
COPY backup.sh env.sh init.sh /

RUN chmod +x /init.sh /backup.sh /env.sh

ENTRYPOINT ["/init.sh"]

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f "http://localhost:$HEALTHCHECK_PORT/" || exit 1
