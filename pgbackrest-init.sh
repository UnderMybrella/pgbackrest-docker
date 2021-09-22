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

file_env 'PGBACKREST_STANZA'
file_env 'PGBACKREST_REPO' '/var/lib/pgbackrest/data'
file_env 'PGBACKREST_CIPHER_PASS'
file_env 'PGBACKREST_CIPHER_TYPE' 'aes-256-cbc'
file_env 'PGBACKREST_COMPRESS_TYPE' 'zst'
file_env 'PGBACKREST_COMPRESS_LEVEL' '6' #pgbackrest says that this is allowed between 0-9, so we pick an approximate value that should line up with our other settings
file_env 'PGBACKREST_RETENTION_FULL' '1'
file_env 'PGBACKREST_RETENTION_DIFF' '7'

PGBACKREST_CONF="/etc/pgbackrest/conf.d/default.conf"
POSTGRES_CONF="$PGDATA/postgresql.conf"

# Check if file is not empty
if [ ! -s $PGBACKREST_CONF ]; then
    cat << EOF > "$PGBACKREST_CONF"
[$PGBACKREST_STANZA]
pg1-path=$PGDATA

repo1-cipher-pass=$PGBACKREST_CIPHER_PASS
repo1-cipher-type=$PGBACKREST_CIPHER_TYPE
repo1-path=$PGBACKREST_REPO
repo1-retention-full=$PGBACKREST_RETENTION_FULL
repo1-retention-diff=$PGBACKREST_RETENTION_FULL

[$PGBACKREST_STANZA:archive-push]
compress-type=$PGBACKREST_COMPRESS_TYPE
compress-level=$PGBACKREST_COMPRESS_LEVEL
EOF
fi

# Don't try and write if the config is read only
[ -w $POSTGRES_CONF ] && cat << EOF >> "$POSTGRES_CONF"
archive_command = 'pgbackrest --stanza=$PGBACKREST_STANZA archive-push %p'
archive_mode = on
max_wal_senders = 3
EOF

pgbackrest --stanza=$PGBACKREST_STANZA --log-level-console=info stanza-create

# Check that everything has gone correctly
# Note, this doesn't work because the database doesn't restart before we can do our checks... hm
# pgbackrest --stanza=$PGBACKREST_STANZA --log-level-console=info check