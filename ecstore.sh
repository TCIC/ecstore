#!/bin/bash
set -e
source config

NGINX_CONF=nginx-site.conf

# Start MARIADB VOLUME
docker run \
--name ${ECSTORE_MARIADB_VOLUME} \
-d ${MARIADB_IMAGE} \
echo "mariadb volume"

# Start MARIADB
docker run \
--name ${ECSTORE_MARIADB} \
-P \
-e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
-e MYSQL_DATABASE=${MYSQL_DATABASE} \
-e MYSQL_USER=${MYSQL_USER} \
-e MYSQL_PASSWORD=${MYSQL_PASSWORD} \
--volumes-from ${ECSTORE_MARIADB_VOLUME} \
-d ${MARIADB_IMAGE}

while [ -z "$(docker logs ${ECSTORE_MARIADB} 2>&1 | grep 'port: 3306')" ]; do
    echo "Waiting mariadb ready."
    sleep 1
done

# Start ECSTORE
docker run \
--name ${ECSTORE_NAME} \
--link ${ECSTORE_MARIADB}:${ECSTORE_MARIADB} \
-v ${ECSTORE_SOURCE}:/usr/share/nginx/html \
--mac-address=${MAC_ADDRESS} \
-d ${ECSTORE_IMAGE}

while [ -z "$(docker logs ${ECSTORE_NAME} 2>&1 | grep 'ready to handle connections')" ]; do
    echo "Waiting ecstore php-fpm ready."
    sleep 1
done

# Nginx conf
rm -rf $(pwd)/${NGINX_CONF}
sed -e "s/{ECSTORE_HOST}/${ECSTORE_NAME}/g " $(pwd)/${NGINX_CONF}.template > $(pwd)/${NGINX_CONF}

# Start Nginx
docker run \
-p 80:80 \
--name ${NGINX_NAME} \
--link ${ECSTORE_NAME}:${ECSTORE_NAME} \
-v $(pwd)/nginx-site.conf:/etc/nginx/conf.d/default.conf \
-v ${ECSTORE_SOURCE}:/usr/share/nginx/html \
-d ${NGINX_IMAGE_NAME}

