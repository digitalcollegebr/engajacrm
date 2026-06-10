# EngajaCRM — fork do EspoCRM com a identidade visual da Engaja Comunicação
#
# Estágio 1: build completo (composer + npm + grunt) a partir do código deste fork.
# Estágio 2: imagem final PHP 8.3 + Apache servindo o build.

FROM php:8.3-cli AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        git unzip libzip-dev libicu-dev libpng-dev libjpeg-dev libfreetype6-dev \
        curl ca-certificates gnupg \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install zip intl gd exif \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /src
COPY . .

# --ignore-scripts evita o phantomjs-prebuilt (sem binário em algumas arquiteturas);
# os dois scripts de postinstall do EspoCRM são executados manualmente em seguida.
RUN npm ci --no-audit --no-fund --ignore-scripts \
    && node js/scripts/postinstall-cleanup \
    && node js/scripts/prepare-lib-original.js \
    && npm run build \
    && mv build/EspoCRM-* /dist

FROM php:8.3-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
        cron libzip-dev libicu-dev libpng-dev libjpeg-dev libfreetype6-dev \
        libldap2-dev libxml2-dev unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql zip intl gd exif bcmath ldap \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*

# Limites recomendados pelo EspoCRM
RUN { \
        echo 'max_execution_time = 180'; \
        echo 'max_input_time = 180'; \
        echo 'memory_limit = 256M'; \
        echo 'post_max_size = 50M'; \
        echo 'upload_max_filesize = 50M'; \
    } > /usr/local/etc/php/conf.d/engajacrm.ini

# DocumentRoot em public/ com alias para client/ (layout EspoCRM 8+)
RUN sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf \
    && printf '\nAlias /client /var/www/html/client\n<Directory /var/www/html/client>\n    Require all granted\n</Directory>\n<Directory /var/www/html/public>\n    AllowOverride All\n</Directory>\n' >> /etc/apache2/sites-available/000-default.conf

COPY --from=builder --chown=www-data:www-data /dist /var/www/html

# Cron do EspoCRM a cada minuto
RUN echo '* * * * * www-data /usr/local/bin/php /var/www/html/cron.php > /dev/null 2>&1' > /etc/cron.d/engajacrm \
    && chmod 0644 /etc/cron.d/engajacrm

RUN printf '#!/bin/sh\nset -e\ncron\nexec apache2-foreground\n' > /usr/local/bin/start.sh \
    && chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
