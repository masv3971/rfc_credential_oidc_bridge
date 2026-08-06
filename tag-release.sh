#!/bin/bash
set -euo pipefail

DRAFT="draft-svensson-credential-oidc-bridge"

# Find the latest tag version number
latest=$(git tag -l "${DRAFT}-*" | sed "s/${DRAFT}-//" | sort -n | tail -1)

if [[ -z "$latest" ]]; then
  next="00"
else
  next=$(printf "%02d" $((10#$latest + 1)))
fi

tag="${DRAFT}-${next}"

echo "Tagging: ${tag}"
git tag "$tag"
git push origin "$tag"
