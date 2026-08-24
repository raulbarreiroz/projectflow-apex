#!/bin/bash

set -Eeuo pipefail

DB_HOST="${DB_HOST:-oracle-db}"
DB_PORT="${DB_PORT:-1521}"
DB_SERVICE="${DB_SERVICE:-XEPDB1}"
ORACLE_PASSWORD="${ORACLE_PASSWORD:?ORACLE_PASSWORD is required}"
APEX_ADMIN_USER="${APEX_ADMIN_USER:-ADMIN}"
APEX_ADMIN_EMAIL="${APEX_ADMIN_EMAIL:-admin@localhost}"
APEX_ADMIN_PASSWORD="${APEX_ADMIN_PASSWORD:?APEX_ADMIN_PASSWORD is required}"
APEX_PUBLIC_PASSWORD="${APEX_PUBLIC_PASSWORD:?APEX_PUBLIC_PASSWORD is required}"

if [[ ! "${APEX_ADMIN_USER}" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "APEX_ADMIN_USER may contain only letters, numbers, and underscores." >&2
    exit 1
fi

for secret_name in ORACLE_PASSWORD APEX_ADMIN_PASSWORD APEX_PUBLIC_PASSWORD; do
    secret_value="${!secret_name}"
    if [[ "${secret_value}" == *'"'* || "${secret_value}" == *$'\n'* ]]; then
        echo "${secret_name} cannot contain double quotes or newlines." >&2
        exit 1
    fi
done

sql_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

ADMIN_USER_SQL="$(sql_escape "${APEX_ADMIN_USER^^}")"
ADMIN_EMAIL_SQL="$(sql_escape "${APEX_ADMIN_EMAIL}")"
ADMIN_PASSWORD_SQL="$(sql_escape "${APEX_ADMIN_PASSWORD}")"

echo "Waiting for Oracle Database ${DB_SERVICE}..."
until sqlplus -s /nolog >/dev/null 2>&1 <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT sys/"${ORACLE_PASSWORD}"@${DB_HOST}:${DB_PORT}/${DB_SERVICE} AS SYSDBA
SELECT 1 FROM DUAL;
EXIT
SQL
do
    sleep 10
done

echo "Oracle Database ${DB_SERVICE} is ready."

APEX_INSTALLED="$(
    sqlplus -s /nolog <<SQL | tr -d '[:space:]'
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT sys/"${ORACLE_PASSWORD}"@${DB_HOST}:${DB_PORT}/${DB_SERVICE} AS SYSDBA
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_users WHERE username = 'APEX_240200';
EXIT
SQL
)"

if [[ "${APEX_INSTALLED}" == "0" ]]; then
    echo "Installing Oracle APEX 24.2 in ${DB_SERVICE}..."
    cd /opt/apex
    sqlplus -s /nolog <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT sys/"${ORACLE_PASSWORD}"@${DB_HOST}:${DB_PORT}/${DB_SERVICE} AS SYSDBA
@apexins.sql SYSAUX SYSAUX TEMP /i/
EXIT
SQL

else
    echo "Oracle APEX 24.2 is already installed; skipping installation."
fi

echo "Ensuring the ${APEX_ADMIN_USER} account exists in INTERNAL..."
sqlplus -s /nolog <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT sys/"${ORACLE_PASSWORD}"@${DB_HOST}:${DB_PORT}/${DB_SERVICE} AS SYSDBA
DECLARE
    l_user_count PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO l_user_count
      FROM APEX_WORKSPACE_APEX_USERS
     WHERE WORKSPACE_NAME = 'INTERNAL'
       AND USER_NAME = '${ADMIN_USER_SQL}';

    IF l_user_count = 0 THEN
        APEX_UTIL.SET_WORKSPACE('INTERNAL');
        APEX_UTIL.CREATE_USER(
            p_user_name                    => '${ADMIN_USER_SQL}',
            p_email_address                => '${ADMIN_EMAIL_SQL}',
            p_web_password                 => '${ADMIN_PASSWORD_SQL}',
            p_change_password_on_first_use => 'N',
            p_developer_privs              => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL'
        );
        COMMIT;
    END IF;
END;
/
EXIT
SQL

echo "Ensuring APEX_PUBLIC_USER is ready for ORDS..."
sqlplus -s /nolog <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT sys/"${ORACLE_PASSWORD}"@${DB_HOST}:${DB_PORT}/${DB_SERVICE} AS SYSDBA
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "${APEX_PUBLIC_PASSWORD}" ACCOUNT UNLOCK;
COMMIT;
EXIT
SQL

echo "APEX setup completed without replacing existing schemas."