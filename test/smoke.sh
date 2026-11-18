#!/bin/bash

set -euo pipefail

IMAGE="${1:-anchor-cloudron:test}"
SUFFIX="${GITHUB_RUN_ID:-local}-${RANDOM}"
NETWORK="anchor-cloudron-${SUFFIX}"
DB_CONTAINER="anchor-cloudron-db-${SUFFIX}"
APP_CONTAINER="anchor-cloudron-app-${SUFFIX}"
DATA_VOLUME="anchor-cloudron-data-${SUFFIX}"

cleanup() {
    docker rm -f "${APP_CONTAINER}" "${DB_CONTAINER}" >/dev/null 2>&1 || true
    docker network rm "${NETWORK}" >/dev/null 2>&1 || true
    docker volume rm "${DATA_VOLUME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "${NETWORK}" >/dev/null
docker volume create "${DATA_VOLUME}" >/dev/null

docker run --detach \
    --name "${DB_CONTAINER}" \
    --network "${NETWORK}" \
    --env POSTGRES_USER=anchor \
    --env POSTGRES_PASSWORD=anchor-test-password \
    --env POSTGRES_DB=anchor \
    postgres:18-alpine >/dev/null

for _ in $(seq 1 60); do
    if docker exec "${DB_CONTAINER}" pg_isready --username anchor --dbname anchor >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
docker exec "${DB_CONTAINER}" pg_isready --username anchor --dbname anchor >/dev/null

start_app() {
    local oidc_enabled="${1:-false}"
    local -a oidc_args=()
    if [[ "${oidc_enabled}" == "true" ]]; then
        oidc_args+=(
            --env CLOUDRON_OIDC_PROVIDER_NAME=Cloudron
            --env CLOUDRON_OIDC_ISSUER=https://my.example.test/openid
            --env CLOUDRON_OIDC_CLIENT_ID=anchor-test-client
            --env CLOUDRON_OIDC_CLIENT_SECRET=anchor-test-secret
            --env CLOUDRON_OIDC_PUBLIC_CLIENT_ID=anchor-test-public-client
        )
    fi

    docker run --detach \
        --name "${APP_CONTAINER}" \
        --network "${NETWORK}" \
        --read-only \
        --tmpfs /run:rw,nosuid,nodev \
        --tmpfs /tmp:rw,nosuid,nodev \
        --volume "${DATA_VOLUME}:/app/data" \
        --env CLOUDRON_POSTGRESQL_URL="postgresql://anchor:anchor-test-password@${DB_CONTAINER}:5432/anchor" \
        --env CLOUDRON_APP_ORIGIN=https://anchor.example.test \
        "${oidc_args[@]}" \
        "${IMAGE}" >/dev/null
}

wait_for_health() {
    for _ in $(seq 1 120); do
        if docker exec "${APP_CONTAINER}" curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
            return 0
        fi
        if [[ "$(docker inspect --format '{{.State.Running}}' "${APP_CONTAINER}")" != "true" ]]; then
            docker logs "${APP_CONTAINER}"
            return 1
        fi
        sleep 1
    done
    docker logs "${APP_CONTAINER}"
    return 1
}

start_app
wait_for_health

docker exec "${APP_CONTAINER}" curl -fsS http://127.0.0.1:3000/api/health | jq -e '.status == "ok" and .app == "anchor"' >/dev/null

if docker exec "${APP_CONTAINER}" ps -eo user,args | awk '/node .*\/app\/code\// && $1 == "root" { found=1 } END { exit found ? 0 : 1 }'; then
    echo "A Node.js process is running as root" >&2
    docker exec "${APP_CONTAINER}" ps -eo user,args >&2
    exit 1
fi

SECRET_BEFORE="$(docker exec "${APP_CONTAINER}" sha256sum /app/data/.jwt_secret | awk '{print $1}')"
docker rm -f "${APP_CONTAINER}" >/dev/null
start_app
wait_for_health
SECRET_AFTER="$(docker exec "${APP_CONTAINER}" sha256sum /app/data/.jwt_secret | awk '{print $1}')"

if [[ "${SECRET_BEFORE}" != "${SECRET_AFTER}" ]]; then
    echo "JWT secret changed after container replacement" >&2
    exit 1
fi

docker rm -f "${APP_CONTAINER}" >/dev/null
start_app true
wait_for_health
docker exec "${APP_CONTAINER}" curl -fsS http://127.0.0.1:3000/api/auth/oidc/config \
    | jq -e '.enabled == true and .providerName == "Cloudron" and .disableInternalAuth == true and .issuerUrl == "https://my.example.test/openid" and .clientId == "anchor-test-public-client"' >/dev/null

echo "Anchor smoke test passed"
