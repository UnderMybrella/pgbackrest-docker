FROM postgres:12-buster

# Install our dependencies --

RUN set -eux; \
        apt-get update; \
        apt-get -y install pgbackrest; \
        rm -rf /var/lib/apt/lists/*;

# Create and own our new pgbackrest dirs
RUN set -eux; \
        mkdir -p -m 770 /var/log/pgbackrest; \
        chown postgres:postgres /var/log/pgbackrest; \
        mkdir -p /etc/pgbackrest; \
        mkdir -p -m 770 /etc/pgbackrest/conf.d; \
        touch /etc/pgbackrest/pgbackrest.conf; \
        chmod 640 /etc/pgbackrest/pgbackrest.conf; \
        chown postgres:postgres /etc/pgbackrest/pgbackrest.conf; \
        chown postgres:postgres /etc/pgbackrest/conf.d;

ENV PGBACKREST_REPO /var/lib/pgbackrest/data
RUN mkdir -p "$BACKREST_REPO" && chown -R postgres:postgres "$BACKREST_REPO" && chmod 777 "$BACKREST_REPO"
VOLUME /var/lib/pgbackrest/data

COPY pgbackrest-init.sh /docker-entrypoint-initdb.d/
RUN chmod a+rx /docker-entrypoint-initdb.d/pgbackrest-init.sh