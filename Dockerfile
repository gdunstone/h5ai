ARG TARGETPLATFORM
FROM --platform=$TARGETPLATFORM alpine:latest
RUN echo "building on $BUILDPLATFORM for $TARGETPLATFORM"

LABEL Maintainer="kekel87 <https://github.com/kekel87>" \
      Description="Lightweight container with Nginx 1.10 & PHP-FPM 7.1 based on Alpine Linux."

# ARG allow it to be overridden at build time
ARG IMAGICK_EXT_VERSION=3.4.2
ARG H5AI_VERSION=0.29.0

ENV HTTPD_USER www-data
RUN deluser xfs && \
    addgroup -g 33 ${HTTPD_USER} && \
    adduser -H -s /sbin/nologin -S -u 33 -G ${HTTPD_USER} ${HTTPD_USER}

COPY class-setup.php.patch class-setup.php.patch

# these packages are in stable repos now
RUN apk add --no-cache --virtual .build-deps \
    unzip \
    openssl \
    ca-certificates \
    wget \
    patch

 # Install packages from stable repo's
RUN apk --no-cache add \
    supervisor curl \
    nginx \
    php7-mbstring \
    php7-fpm \
    php7-exif \
    php7-gd \
    php7-json \
    php7-zip \
    php7-session \
    supervisor  \
    zip \
    acl \
    ffmpeg \
    imagemagick

 # Install h5ai
 # and patch h5ai because we want to deploy it ouside of the document root and use /var/www as root for browsing

 RUN wget --no-check-certificate  https://release.larsjung.de/h5ai/h5ai-${H5AI_VERSION}.zip -P /tmp \
    && unzip /tmp/h5ai-${H5AI_VERSION}.zip -d /usr/share/h5ai \
    && patch -p1 -u -d /usr/share/h5ai/_h5ai/private/php/core/ -i /class-setup.php.patch
 
RUN apk del .build-deps \
 && rm -rf /var/cache/apk/* /tmp/* /class-setup.php.patch

# Configure H5AI
COPY config/h5ai.options.json /usr/share/h5ai/_h5ai/private/conf/options.json

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom.ini

# make the cache writable
RUN chmod -R 777 /usr/share/h5ai/_h5ai/public/cache/
RUN chmod -R 777 /usr/share/h5ai/_h5ai/private/cache/

# use supervisor to monitor all services
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD supervisord -c /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80 443
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# expose path
WORKDIR /var/www