FROM postgres:12-buster

# Install our dependencies --

RUN set -eux; \
        apt-get update; \
        apt-get -y install pgbackrest inotify-tools; \
        rm -rf /var/lib/apt/lists/*;

ENV PGBACKREST_DIR /var/lib/pgbackrest
ENV PGBACKREST_CONFIG_INCLUDE_PATH ${PGBACKREST_DIR}/conf.d
ENV PGBACKREST_CONFIG ${PGBACKREST_DIR}/pgbackrest.conf

# Create and own our new pgbackrest dirs
RUN set -eux; \
        mkdir -p -m 770 /var/log/pgbackrest; \
        chown postgres:postgres /var/log/pgbackrest; \
        mkdir -p ${PGBACKREST_DIR}; \
        mkdir -p -m 770 ${PGBACKREST_CONFIG_INCLUDE_PATH}; \
        touch ${PGBACKREST_CONFIG}; \
        chmod 640 ${PGBACKREST_CONFIG}; \
        chown postgres:postgres ${PGBACKREST_CONFIG_INCLUDE_PATH}; \
        chown postgres:postgres ${PGBACKREST_CONFIG};

ENV BACKREST_REPO ${PGBACKREST_DIR}/data
RUN mkdir -p "$BACKREST_REPO" && chown -R postgres:postgres "$BACKREST_REPO" && chmod 777 "$BACKREST_REPO"
VOLUME ${PGBACKREST_DIR}

COPY pgbackrest-init.sh /docker-entrypoint-initdb.d/
RUN chmod a+rx /docker-entrypoint-initdb.d/pgbackrest-init.sh


COPY pgbackrest-wrapper.sh /usr/local/bin/
RUN chmod a+rx /usr/local/bin/pgbackrest-wrapper.sh

ENTRYPOINT ["pgbackrest-wrapper.sh"]

# Copied from https://github.com/docker-library/postgres/blob/master/12/bullseye/Dockerfile

# We set the default STOPSIGNAL to SIGINT, which corresponds to what PostgreSQL
# calls "Fast Shutdown mode" wherein new connections are disallowed and any
# in-progress transactions are aborted, allowing PostgreSQL to stop cleanly and
# flush tables to disk, which is the best compromise available to avoid data
# corruption.
#
# Users who know their applications do not keep open long-lived idle connections
# may way to use a value of SIGTERM instead, which corresponds to "Smart
# Shutdown mode" in which any existing sessions are allowed to finish and the
# server stops when all sessions are terminated.
#
# See https://www.postgresql.org/docs/12/server-shutdown.html for more details
# about available PostgreSQL server shutdown signals.
#
# See also https://www.postgresql.org/docs/12/server-start.html for further
# justification of this as the default value, namely that the example (and
# shipped) systemd service files use the "Fast Shutdown mode" for service
# termination.
#
STOPSIGNAL SIGINT
#
# An additional setting that is recommended for all users regardless of this
# value is the runtime "--stop-timeout" (or your orchestrator/runtime's
# equivalent) for controlling how long to wait between sending the defined
# STOPSIGNAL and sending SIGKILL (which is likely to cause data corruption).
#
# The default in most runtimes (such as Docker) is 10 seconds, and the
# documentation at https://www.postgresql.org/docs/12/server-start.html notes
# that even 90 seconds may not be long enough in many instances.

EXPOSE 5432
CMD ["postgres"]