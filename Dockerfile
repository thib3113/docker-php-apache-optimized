FROM php:7.1-apache

ENV DEBIAN_FRONTEND noninteractive

RUN apt update && apt upgrade -y && apt install wget ssl-cert sendmail gnupg libcurl3-dev apt-utils -my

# enable extra Apache modules
RUN a2enmod rewrite \
  && a2enmod headers 

# install the PHP extensions we need
RUN echo 'deb http://deb.debian.org/debian jessie-backports main' > /etc/apt/sources.list.d/backports.list \
  && apt-get update \
  && curl -sL https://deb.nodesource.com/setup_8.x | bash \
  && apt-get install -y git zip zlib1g-dev libpng-dev libjpeg-dev libxml2-dev libxslt-dev libgraphicsmagick1-dev graphicsmagick libldap2-dev mcrypt libmcrypt-dev libltdl7 mariadb-client \
  && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
  && docker-php-ext-install gd json mysqli pdo pdo_mysql opcache gettext exif calendar soap sockets wddx mcrypt zip mbstring dom

# install APCu from PECL
RUN pecl -vvv install apcu && docker-php-ext-enable apcu

# install curl
RUN docker-php-ext-install curl

# install GMagick from PECL
RUN pecl -vvv install gmagick-beta && docker-php-ext-enable gmagick

# NodeJS Build Stack dependencies
# RUN apt-get install -y -t jessie-backports ca-certificates-java openjdk-8-jre-headless libbatik-java \
#   && apt-get install -y nodejs fontforge \
#   && npm i -g ttf2eot \
#   && rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
  } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# increase upload size
# see http://php.net/manual/en/ini.core.php
RUN { \
    echo "upload_max_filesize = 25M"; \
    echo "post_max_size = 50M"; \
  } > /usr/local/etc/php/conf.d/uploads.ini

# Iron the security of the Docker
RUN { \
    echo "expose_php = Off"; \
    echo "display_startup_errors = off"; \
    echo "display_errors = off"; \
    echo "html_errors = off"; \
    echo "log_errors = on"; \
    echo "error_log = /dev/stderr"; \
    echo "ignore_repeated_errors = off"; \
    echo "ignore_repeated_source = off"; \
    echo "report_memleaks = on"; \
    echo "track_errors = on"; \
    echo "docref_root = 0"; \
    echo "docref_ext = 0"; \
    echo "error_reporting = -1"; \
    echo "log_errors_max_len = 0"; \
  } > /usr/local/etc/php/conf.d/security.ini

RUN { \
    echo "ServerSignature Off"; \
    echo "ServerTokens Prod"; \
    echo "TraceEnable off"; \
  } >> /etc/apache2/apache2.conf

# Cleanup
RUN apt-get purge -y --auto-remove libpng12-dev libjpeg-dev libxml2-dev libxslt-dev libgraphicsmagick1-dev libldap2-dev libmcrypt-dev openjdk-7-jre openjdk-7-jre-headless

VOLUME /var/www/html


#add mod-pagespeed
RUN \
    wget -q https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-stable_current_amd64.deb && \
    dpkg -i mod-pagespeed-*.deb && \
    apt-get -f install -y && \
    rm mod-pagespeed-*.deb

#add SSL
RUN \
    make-ssl-cert generate-default-snakeoil && \
    usermod --append --groups ssl-cert www-data && \
    ls -l /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/private/ssl-cert-snakeoil.key && \
    a2enmod ssl && \
    a2ensite default-ssl

#set sendmail
RUN { \
    echo "sendmail_path = /usr/sbin/sendmail -t -i"; \
  } > /usr/local/etc/php/conf.d/mail.ini

RUN update-rc.d sendmail defaults


RUN apt remove --purge -y wget && \
    apt-get autoremove -y && \
    apt-get clean

EXPOSE 80 443