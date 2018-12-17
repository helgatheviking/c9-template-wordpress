FROM php:7.2-apache

ADD ./files /home/ubuntu

# install the PHP extensions we need
RUN set -ex; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libjpeg-dev \
        libpng-dev \
    ; \
    \
    docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
    docker-php-ext-install gd mysqli opcache zip; \
    \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { print $3 }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite expires

RUN cd /home/ubuntu/workspace && \
    rm -rf .git* && \
    curl -L http://wordpress.org/latest.tar.gz | tar xz && \
    mv wordpress/* . && \
    mv wp-config-sample.php wp-config.php && \
    sed -i -e "s/define('DB_NAME',.*/define('DB_NAME', 'c9');/" wp-config.php && \
    sed -i -e "s/define('DB_USER',.*/define('DB_USER', substr(getenv('C9_USER'), 0, 16));/" wp-config.php && \
    sed -i -e "s/define('DB_PASSWORD',.*/define('DB_PASSWORD', '');/" wp-config.php && \
    sed -i -e "s/define('DB_HOST',.*/define('DB_HOST', getenv('IP'));/" wp-config.php && \
    sed -i -e '/define(.WP_DEBUG.*/ a\
    $_SERVER["HTTP_HOST"] = $_SERVER["SERVER_NAME"];' wp-config.php && \
    sed -i -e '/define(.WP_DEBUG.*/ a\
    $_SERVER["HTTP_HOST"] = $_SERVER["SERVER_NAME"];' wp-config.php && \
    sed -i '2iif (isset($_SERVER["HTTP_X_FORWARDED_PROTO"]) && $_SERVER["HTTP_X_FORWARDED_PROTO"] == "https") $_SERVER["HTTPS"] = "on";' wp-config.php && \
    chown -R ubuntu:ubuntu /home/ubuntu

# Install wp-cli
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

ADD ./files/check-environment /.check-environment/wordpress