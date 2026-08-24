#!/bin/bash

set -Eeuo pipefail

DB_HOST="${DB_HOST:-oracle-db}"
DB_PORT="${DB_PORT:-1521}"
DB_SERVICE="${DB_SERVICE:-XEPDB1}"
DB_ROOT_SERVICE="${DB_ROOT_SERVICE:-XE}"
ORACLE_PASSWORD="${ORACLE_PASSWORD:?ORACLE_PASSWORD is required}"
APEX_PUBLIC_PASSWORD="${APEX_PUBLIC_PASSWORD:?APEX_PUBLIC_PASSWORD is required}"
ORDS_PUBLIC_PASSWORD="${ORDS_PUBLIC_PASSWORD:?ORDS_PUBLIC_PASSWORD is required}"
CONFIG_DIR="${ORDS_CONFIG_DIR:-/opt/ords/config}"
APEX_IMAGES="${APEX_IMAGES:-/opt/apex/images}"
ORDS_BIN="/opt/ords/bin/ords"
POOL_CONFIG="${CONFIG_DIR}/databases/default/pool.xml"

if [[ "${ORDS_PUBLIC_PASSWORD}" == *'"'* || "${ORDS_PUBLIC_PASSWORD}" == *$'\n'* ]]; then
    echo "ORDS_PUBLIC_PASSWORD cannot contain double quotes or newlines." >&2
    exit 1
fi

mkdir -p "${CONFIG_DIR}" /tmp/ords-logs

ORDS_INSTALLED="$(
    sqlplus -s /nolog <<SQL | tr -d '[:space:]'
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT sys/"${ORACLE_PASSWORD}"@${DB_HOST}:${DB_PORT}/${DB_SERVICE} AS SYSDBA
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_users WHERE username = 'ORDS_METADATA';
EXIT
SQL
)"

if [[ "${ORDS_INSTALLED}" == "0" || ! -s "${POOL_CONFIG}" ]]; then
    if [[ "${ORDS_INSTALLED}" == "0" ]]; then
        echo "Installing ORDS metadata and persistent configuration..."
    else
        echo "Rebuilding the missing ORDS pool configuration without replacing metadata..."
    fi

    printf '%s\n%s\n' "${ORACLE_PASSWORD}" "${ORDS_PUBLIC_PASSWORD}" |
        "${ORDS_BIN}" --config "${CONFIG_DIR}" install \
            --admin-user SYS \
            --proxy-user \
            --db-hostname "${DB_HOST}" \
            --db-port "${DB_PORT}" \
            --db-servicename "${DB_SERVICE}" \
            --feature-sdw true \
            --gateway-mode proxied \
            --gateway-user APEX_PUBLIC_USER \
            --log-folder /tmp/ords-logs \
            --password-stdin
else
    echo "ORDS metadata and pool configuration already exist; skipping installation."
fi

echo "Synchronizing the ORDS runtime credential..."
ORDS_USER_COMMON="$(
    sqlplus -s /nolog <<SQL | tr -d '[:space:]'
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT sys/"${ORACLE_PASSWORD}"@${DB_HOST}:${DB_PORT}/${DB_SERVICE} AS SYSDBA
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT common FROM dba_users WHERE username = 'ORDS_PUBLIC_USER';
EXIT
SQL
)"

if [[ "${ORDS_USER_COMMON}" == "YES" ]]; then
    ORDS_USER_SERVICE="${DB_ROOT_SERVICE}"
    ORDS_USER_SCOPE=" CONTAINER=ALL"
else
    ORDS_USER_SERVICE="${DB_SERVICE}"
    ORDS_USER_SCOPE=""
fi

sqlplus -s /nolog <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT sys/"${ORACLE_PASSWORD}"@${DB_HOST}:${DB_PORT}/${ORDS_USER_SERVICE} AS SYSDBA
ALTER USER ORDS_PUBLIC_USER IDENTIFIED BY "${ORDS_PUBLIC_PASSWORD}" ACCOUNT UNLOCK${ORDS_USER_SCOPE};
COMMIT;
EXIT
SQL

printf '%s\n' "${ORDS_PUBLIC_PASSWORD}" |
    "${ORDS_BIN}" --config "${CONFIG_DIR}" config \
        --db-pool default secret --password-stdin db.password

"${ORDS_BIN}" --config "${CONFIG_DIR}" config --db-pool default verify

"${ORDS_BIN}" --config "${CONFIG_DIR}" config set standalone.context.path /ords
"${ORDS_BIN}" --config "${CONFIG_DIR}" config set standalone.static.context.path /i
"${ORDS_BIN}" --config "${CONFIG_DIR}" config set standalone.static.path "${APEX_IMAGES}"

echo "Validating APEX and its image prefix..."
sqlplus -s /nolog <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT sys/"${ORACLE_PASSWORD}"@${DB_HOST}:${DB_PORT}/${DB_SERVICE} AS SYSDBA
BEGIN
    APEX_INSTANCE_ADMIN.SET_PARAMETER('IMAGE_PREFIX', '/i/');
    SYS.VALIDATE_APEX;
    COMMIT;
END;
/
EXIT
SQL

echo "Starting ORDS on port 8080."
echo "APEX Administration: http://localhost:8081/ords/apex_admin"
echo "APEX static images:  http://localhost:8081/i/"

exec "${ORDS_BIN}" --config "${CONFIG_DIR}" serve \
    --port 8080 \
    --apex-images "${APEX_IMAGES}" \
    --apex-images-context-path /i