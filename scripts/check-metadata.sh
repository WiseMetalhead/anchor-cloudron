#!/bin/bash

set -euo pipefail

manifest_version="$(jq -r '.upstreamVersion' CloudronManifest.json)"
docker_version="$(sed -n 's/^ARG ANCHOR_VERSION=//p' Dockerfile)"
package_version="$(jq -r '.version' CloudronManifest.json)"

if [[ "${manifest_version}" != "${docker_version}" ]]; then
    echo "CloudronManifest upstreamVersion (${manifest_version}) does not match Dockerfile ANCHOR_VERSION (${docker_version})" >&2
    exit 1
fi

if ! grep -q "^\[${package_version//./\\.}\]$" CHANGELOG; then
    echo "CHANGELOG has no section for package version ${package_version}" >&2
    exit 1
fi

if [[ "$(jq -r '.stable' CloudronVersions.json)" != "true" ]]; then
    echo "CloudronVersions.json must have stable=true" >&2
    exit 1
fi

echo "Package ${package_version} targets Anchor ${manifest_version}"
