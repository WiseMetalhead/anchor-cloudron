#!/bin/bash

set -euo pipefail

echo "=> Preparing Anchor data directory"
mkdir -p /app/data/uploads/profiles /app/data/uploads/attachments /run/anchor
chown -R cloudron:cloudron /app/data /run/anchor

JWT_SECRET_FILE=/app/data/.jwt_secret
if [[ ! -s "${JWT_SECRET_FILE}" ]]; then
    echo "=> Generating persistent JWT secret"
    umask 077
    openssl rand -hex 32 > "${JWT_SECRET_FILE}"
    chown cloudron:cloudron "${JWT_SECRET_FILE}"
fi
chmod 600 "${JWT_SECRET_FILE}"

export NODE_ENV=production
export NEXT_TELEMETRY_DISABLED=1
export HOME=/run/anchor
export DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}"
export DATA_DIR=/app/data
export APP_URL="${CLOUDRON_APP_ORIGIN}"
export JWT_SECRET
JWT_SECRET="$(<"${JWT_SECRET_FILE}")"

if [[ -n "${CLOUDRON_OIDC_ISSUER:-}" ]]; then
    echo "=> Enabling Cloudron OpenID Connect"
    export OIDC_ENABLED=true
    export OIDC_PROVIDER_NAME="${CLOUDRON_OIDC_PROVIDER_NAME:-Cloudron}"
    export OIDC_ISSUER_URL="${CLOUDRON_OIDC_ISSUER}"
    export OIDC_CLIENT_ID="${CLOUDRON_OIDC_CLIENT_ID}"
    export OIDC_CLIENT_SECRET="${CLOUDRON_OIDC_CLIENT_SECRET:-}"
    export DISABLE_INTERNAL_AUTH=true
else
    echo "=> Using Anchor-managed authentication"
    unset OIDC_ENABLED OIDC_PROVIDER_NAME OIDC_ISSUER_URL OIDC_CLIENT_ID OIDC_CLIENT_SECRET DISABLE_INTERNAL_AUTH
fi

echo "=> Applying database migrations"
cd /app/code/server
gosu cloudron:cloudron ./node_modules/.bin/prisma migrate deploy

echo "=> Starting Anchor"
exec /usr/bin/supervisord --configuration /etc/supervisor/supervisord.conf --nodaemon -i anchor
