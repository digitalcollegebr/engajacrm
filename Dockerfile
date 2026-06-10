# EngajaCRM — fork do EspoCRM com a identidade visual da Engaja Comunicação
#
# Estágio 1: build completo (composer + npm + grunt) a partir do código deste fork.
# Estágio 2: imagem oficial espocrm/espocrm com nossos arquivos sobrepostos —
#            herda o entrypoint oficial (instalação automática via ESPOCRM_*,
#            docker-daemon.sh para cron e docker-websocket.sh para websocket).

# O build (composer + npm + grunt) gera artefatos independentes de arquitetura,
# então roda sempre na plataforma nativa do host ($BUILDPLATFORM).
FROM --platform=$BUILDPLATFORM php:8.3-cli AS builder

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

# Passo separado para expor erros do composer (o grunt suprime a saída dele)
RUN composer install --no-dev --no-interaction || (composer diagnose; exit 1)

# ignore-scripts evita o phantomjs-prebuilt (sem binário em algumas arquiteturas);
# vale também para o npm ci interno do grunt. Os dois scripts de postinstall do
# EspoCRM são executados manualmente em seguida.
RUN echo "ignore-scripts=true" > .npmrc \
    && npm ci --no-audit --no-fund \
    && node js/scripts/postinstall-cleanup \
    && node js/scripts/prepare-lib-original.js \
    && npm run build \
    && mv build/EspoCRM-* /dist

# A versão da imagem base deve acompanhar a tag base deste fork (engaja-stable)
FROM espocrm/espocrm:9.3.8

# O entrypoint oficial copia /usr/src/espocrm para /var/www/html na primeira
# execução do volume; sobrepor aqui leva o tema Engaja e o rebranding junto.
COPY --from=builder /dist/. /usr/src/espocrm/
