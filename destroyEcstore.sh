#!/bin/bash
set -e
source config

docker stop ${NGINX_NAME}
docker stop ${ECSTORE_NAME}
docker stop ${ECSTORE_MARIADB}
docker rm -v ${NGINX_NAME}
docker rm -v ${ECSTORE_NAME}
docker rm -v ${ECSTORE_MARIADB}
docker rm -v ${ECSTORE_MARIADB_VOLUME}

