#!/usr/bin/env bash

touch "/tmp/dev.sibr.docker.entrypoint"

RERUN_INIT=0

# We want to check to see if *our* init hasn't run yet, but psql is set up
if [ -s "$PGDATA/PG_VERSION" ]; then
    if [[ ! -s "$PGBACKREST_CONFIG_INCLUDE_PATH/default.conf" ]]; then
        RERUN_INIT=1
    fi
fi

if [[ $RERUN_INIT -eq 0 ]]; then
    /usr/local/bin/docker-entrypoint.sh "$@"
else 
    # Run our entry script with any arguments we receive
    /usr/local/bin/docker-entrypoint.sh "$@" &
    DOCKER_PID="$!"

    echo "Waiting on PostgreSQL..."
    until pg_isready; do sleep 1; done

    echo "PostgreSQL has already run setup, but we haven't yet. Running init..."

    /docker-entrypoint-initdb.d/pgbackrest-init.sh

    su --session-command "pg_ctl stop" postgres
    wait $DOCKER_PID
fi

# To allow for pgbackrest restoring, we want to check if a lock file exists. 
LOCKFILE="/tmp/dev.sibr.docker.lock"

if [[ -f $LOCKFILE ]]; then
    echo "Lockfile exists - checking if PID"
    PID=$(cat $LOCKFILE)
    if [[ $PID =~ ^[0-9]+$ ]]; then
        #If it does, and contains a PID, wait for that process
        if [[ -f "/proc/$PID/stat" ]]; then
            echo "Waiting on $PID"
            wait $PID
        fi
    else
        # Wait on lockfile to be deleted
        echo "Waiting on $LOCKFILE"
        inotifywait -e delete_self "$LOCKFILE"
    fi
fi