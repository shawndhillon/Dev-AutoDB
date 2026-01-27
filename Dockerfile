FROM postgres:16-alpine

# Append replication settings to default postgresql.conf
RUN echo "wal_level = replica" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "max_wal_senders = 10" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "max_replication_slots = 10" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "hot_standby = on" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "wal_keep_size = 256MB" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "listen_addresses = '*'" >> /usr/local/share/postgresql/postgresql.conf.sample

# Primary initialization: create replication user and slots
COPY <<'EOF' /docker-entrypoint-initdb.d/00-init-replication.sh
#!/bin/bash
set -e
if [ "${POSTGRES_REPLICATION_ROLE}" != "replica" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replicator_password';
        SELECT pg_create_physical_replication_slot('replica_slot_1', true);
        SELECT pg_create_physical_replication_slot('replica_slot_2', true);
EOSQL
    echo "host replication replicator 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
    echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
fi
EOF

# Replica initialization: wait for primary, perform base backup, start as standby
COPY <<'EOF' /usr/local/bin/start-replica.sh
#!/bin/bash
set -e
if [ "${POSTGRES_REPLICATION_ROLE}" = "replica" ]; then
    until pg_isready -h "${PRIMARY_HOST:-primary}" -p "${PRIMARY_PORT:-5432}" -U replicator; do
        echo "Waiting for primary..."
        sleep 2
    done

    if [ ! -s "$PGDATA/PG_VERSION" ]; then
        rm -rf "$PGDATA"/*
        PGPASSWORD=replicator_password pg_basebackup \
            -h "${PRIMARY_HOST:-primary}" -p "${PRIMARY_PORT:-5432}" -U replicator \
            -D "$PGDATA" -Fp -Xs -P -R -S "${REPLICATION_SLOT:-replica_slot_1}"
        chmod 700 "$PGDATA"
    fi

    cat > "$PGDATA/postgresql.auto.conf" <<AUTOCONF
primary_conninfo = 'host=${PRIMARY_HOST:-primary} port=${PRIMARY_PORT:-5432} user=replicator password=replicator_password'
primary_slot_name = '${REPLICATION_SLOT:-replica_slot_1}'
AUTOCONF
    touch "$PGDATA/standby.signal"
fi
exec docker-entrypoint.sh postgres
EOF

RUN chmod +x /usr/local/bin/start-replica.sh
