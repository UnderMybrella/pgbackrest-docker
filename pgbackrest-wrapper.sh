#!/usr/bin/env bash

# Before we run our entry script, we want to check to see if *our* init hasn't run yet, but psql is set up
if [[ -s "$PGDATA/PG_VERSION" && ! -s "$PGBACKREST_CONFIG_INCLUDE_PATH/default.conf" ]]; then
    echo "PostgreSQL has already run setup, but we haven't yet"

    /usr/local/bin/pgbackrest-init.sh
fi


# Run our entry script with any arguments we receive
/usr/local/bin/docker-entrypoint.sh "$@"

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