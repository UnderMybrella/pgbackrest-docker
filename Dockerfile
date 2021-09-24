FROM postgres:12-buster

# Install our dependencies --

RUN set -eux; \
        apt-get update; \
        apt-get -y install pgbackrest; \
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