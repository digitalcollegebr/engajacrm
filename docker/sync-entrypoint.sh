#!/bin/sh
# Wraps the official EspoCRM entrypoint. This image mounts the whole
# /var/www/html as a persistent volume, so the official entrypoint only
# copies /usr/src/espocrm into it on the very first boot (empty volume) and
# never again — meaning every later deploy builds a fresh image but the
# running container keeps serving whatever code was there before.
#
# Here we re-sync the built application code into an *already installed*
# volume on every start, so deploys actually take effect. data/ (config,
# uploads, cache, logs) and custom/ (user customizations) are never touched.
# Fresh (empty) volumes are left alone entirely — the official entrypoint's
# own first-install logic handles those.
set -e

if [ -f /var/www/html/data/config.php ] && [ -d /usr/src/espocrm ]; then
    echo "sync-entrypoint: syncing application code into the existing volume..."
    find /usr/src/espocrm -mindepth 1 -maxdepth 1 ! -name data ! -name custom \
        -exec cp -rf {} /var/www/html/ \;
fi

exec "$@"
