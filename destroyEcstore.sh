#!/bin/bash
set -e
source config

docker stop ${NGINX_NAME}
docker stop ${ECSTORE_NAME}
docker stop ${ECSTORE_MYSQL}
docker rm -v ${NGINX_NAME}
docker rm -v ${ECSTORE_NAME}
docker rm -v ${ECSTORE_MYSQL}
docker rm -v ${ECSTORE_MYSQL_VOLUME}

