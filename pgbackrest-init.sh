#!/usr/bin/env bash

set -Eeo pipefail

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

file_env 'BACKREST_STANZA'
file_env 'BACKREST_REPO'
file_env 'BACKREST_CIPHER_PASS'
file_env 'BACKREST_CIPHER_TYPE' 'aes-256-cbc'
file_env 'BACKREST_COMPRESS_TYPE' 'zst'
file_env 'BACKREST_COMPRESS_LEVEL' '6' #pgbackrest says that this is allowed between 0-9, so we pick an approximate value that should line up with our other settings
file_env 'BACKREST_RETENTION_FULL' '1'
file_env 'BACKREST_RETENTION_DIFF' '7'

BACKREST_CONF="$PGBACKREST_CONFIG_INCLUDE_PATH/default.conf"
POSTGRES_CONF="$PGDATA/postgresql.conf"

if [[ -z "$BACKREST_STANZA" ]]; then
    >&2 echo "BACKREST_STANZA not defined!"
    exit 1
fi

if [[ -z "$BACKREST_REPO" ]]; then
    >&2 echo "BACKREST_REPO not defined!"
    exit 2
fi

if [[ -z "$BACKREST_CIPHER_PASS" ]]; then
    >&2 echo "BACKREST_CIPHER_PASS not defined!"
    exit 3
fi

# Check if file is not empty
if [ ! -s $BACKREST_CONF ]; then
    cat << EOF > "$BACKREST_CONF"
[$BACKREST_STANZA]
pg1-path=$PGDATA
pg1-database=$POSTGRES_DB
pg1-user=$POSTGRES_USER

repo1-cipher-pass=$BACKREST_CIPHER_PASS
repo1-cipher-type=$BACKREST_CIPHER_TYPE
repo1-path=$BACKREST_REPO
repo1-retention-full=$BACKREST_RETENTION_FULL
repo1-retention-diff=$BACKREST_RETENTION_FULL

[$BACKREST_STANZA:archive-push]
compress-type=$BACKREST_COMPRESS_TYPE
compress-level=$BACKREST_COMPRESS_LEVEL
EOF
fi

# Don't try and write if the config is read only
[ -w $POSTGRES_CONF ] && cat << EOF >> "$POSTGRES_CONF"
archive_command = 'pgbackrest --stanza=$BACKREST_STANZA archive-push %p'
archive_mode = on
max_wal_senders = 3
EOF

if [ "$(id -u)" = '0' ]; then
    su postgres --session-command "pgbackrest --stanza=$BACKREST_STANZA --log-level-console=info stanza-create"
else
    pgbackrest --stanza="$BACKREST_STANZA" --log-level-console=info stanza-create
fi

# Check that everything has gone correctly
# Note, this doesn't work because the database doesn't restart before we can do our checks... hm
# pgbackrest --stanza=$BACKREST_STANZA --log-level-console=info check