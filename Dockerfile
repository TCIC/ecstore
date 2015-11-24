FROM debian:jessie
MAINTAINER mengzhaopeng <qiuranke@gmail.com>

# persistent / runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      libmcrypt-dev \
      libmemcached-dev \
      libmysqlclient-dev \
      libpcre3 \
      librecode0 \
      libsqlite3-0 \
      libxml2 \
    && apt-get clean \
    && rm -r /var/lib/apt/lists/*

# phpize deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      autoconf \
      file \
      g++ \
      gcc \
      libc-dev \
      make \
      pkg-config \
      re2c \
    && apt-get clean \
    && rm -r /var/lib/apt/lists/*

ENV PHP_INI_DIR /usr/local/etc
RUN mkdir -p $PHP_INI_DIR/conf.d

ENV GPG_KEYS 0B96609E270F565C13292B24C13C70B87267B52D 0A95E9A026542D53835E3F3A7DEC4E69FC9C83D7 0E604491
RUN set -xe \
  && for key in $GPG_KEYS; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done

# compile openssl, otherwise --with-openssl won't work
RUN OPENSSL_VERSION="1.0.2d" \
      && cd /tmp \
      && mkdir openssl \
      && curl -sL "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz \
      && curl -sL "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz.asc" -o openssl.tar.gz.asc \
      && gpg --verify openssl.tar.gz.asc \
      && tar -xzf openssl.tar.gz -C openssl --strip-components=1 \
      && cd /tmp/openssl \
      && ./config && make && make install \
      && rm -rf /tmp/*

ENV PHP_VERSION 5.3.29
ENV MEMCACHE_VERSION 2.2.0
ENV REDIS_VERSION 2.2.7

# php 5.3 needs older autoconf
RUN buildDeps=" \
                autoconf2.13 \
                libcurl4-openssl-dev \
                libpcre3-dev \
                libpng-dev \
                libreadline6-dev \
                librecode-dev \
                libsqlite3-dev \
                libssl-dev \
                libxml2-dev \
                xz-utils \
      " \
      && set -x \
      && apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
      && curl -SL "http://php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" -o php.tar.xz \
      && curl -SL "http://php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror" -o php.tar.xz.asc \
      && gpg --verify php.tar.xz.asc \
      && mkdir -p /usr/src/php \
      && tar -xof php.tar.xz -C /usr/src/php --strip-components=1 \
      && rm php.tar.xz* \
      && cd /usr/src/php \
      && ./configure \
            --with-config-file-path="$PHP_INI_DIR" \
            --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
            --enable-fpm \
            --with-fpm-user=www-data \
            --with-fpm-group=www-data \
            --disable-cgi \
            --enable-ftp \
            --enable-mysqlnd \
            --with-curl \
            --with-gd \
            --with-mcrypt \
            --with-mhash \
            --with-mysql \
            --with-openssl=/usr/local/ssl \
            --with-readline \
            --with-recode \
            --with-zlib \
      /usr/local/etc/php-fpm.conf&& make -j"$(nproc)" \
      && make install \
      && cd /tmp && curl -SL "http://pecl.php.net/get/memcached-$MEMCACHE_VERSION.tgz" -o memcached.tgz \
      && tar zxf memcached.tgz && cd /tmp/memcached-$MEMCACHE_VERSION && phpize \
      && ./configure --enable-memcache --with-php-config=/usr/local/bin/php-config \
      && make && make install \
      && cp -p /usr/src/php/php.ini-production $PHP_INI_DIR/php.ini \
      && sed -i "/;extension=php_zip.dll/a\extension=\/usr\/local\/lib\/php\/extensions\/no-debug-non-zts-20090626\/memcached.so" /usr/local/etc/php.ini \
      && rm -rf /tmp/memcached* \
      && cd /tmp && curl -SL "http://pecl.php.net/get/redis-$REDIS_VERSION.tgz" -o redis.tgz \
      && tar zxf redis.tgz && cd /tmp/redis-$REDIS_VERSION && phpize \
      && ./configure --with-php-config=/usr/local/bin/php-config && make && make install \
      && sed -i "/;extension=php_zip.dll/a\extension=\/usr\/local\/lib\/php\/extensions\/no-debug-non-zts-20090626\/redis.so" /usr/local/etc/php.ini \
      && rm -rf /tmp/redis* \
      && { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
      && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps \
      && cd /usr/src/php && make clean

# php-fpm config
ENV PHPFPM_CONF /usr/local/etc/php-fpm.conf
RUN cp -p $PHPFPM_CONF.default $PHPFPM_CONF && \
    sed -i "s/;error_log = log\/php-fpm.log/error_log = \/proc\/self\/fd\/2/g" $PHPFPM_CONF && \
    sed -i "s/;daemonize = yes/daemonize = no/g" $PHPFPM_CONF && \
    sed -i "s/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/g" $PHPFPM_CONF && \
    sed -i "s/;access.log = log\/\$pool.access.log/access.log = \/proc\/self\/fd\/2/g" $PHPFPM_CONF

# start shell
ENV RC_START /start.sh
RUN echo "#!/bin/bash" >> $RC_START && \
    echo "chown -Rf www-data.www-data /usr/share/nginx/html" >> $RC_START && \
    echo "exec php-fpm" >> $RC_START && \
    chmod 755 $RC_START

# setup volume
VOLUME ["/usr/share/nginx/html"]

# ecstore config
RUN cd /tmp && \
    curl -sL "http://downloads.zend.com/guard/5.5.0/ZendGuardLoader-php-5.3-linux-glibc23-x86_64.tar.gz" -o ZendGuardLoader.tar.gz && \
    mkdir -p /usr/local/ext/php5 && tar zxf ZendGuardLoader.tar.gz && \
    cp -p /tmp/ZendGuardLoader-php-5.3-linux-glibc23-x86_64/php-5.3.x/ZendGuardLoader.so /usr/local/ext/php5 && \
    rm -rf /tmp/ZendGuardLoader* && \
    echo "[Zend Optimizer]" >> $PHP_INI_DIR/php.ini && \
    echo "zend_extension=/usr/local/ext/php5/ZendGuardLoader.so" >> $PHP_INI_DIR/php.ini && \
    echo "zend_loader.enable=1" >> $PHP_INI_DIR/php.ini && \
    echo "zend_loader.disable_licensing=0" >> $PHP_INI_DIR/php.ini && \
    echo "zend_loader.obfuscation_level_support=3" >> $PHP_INI_DIR/php.ini && \
    echo "zend_loader.license_path=/usr/share/nginx/html/config/developer.zl" >> $PHP_INI_DIR/php.ini

# expose Ports
EXPOSE 9000

CMD ["/bin/bash", "/start.sh"]
