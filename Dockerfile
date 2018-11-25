FROM postgres:11.1
COPY ./init-user-db.sh /docker-entrypoint-initdb.d/init-user-db.sh
COPY ./scripts /tmp/scripts
