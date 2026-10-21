#!/usr/bin/env bash
set -euo pipefail

case "$EVENT_NAME" in
  pull_request)
    printf 'publish=false\n'
    exit 0
    ;;
  push|workflow_dispatch) ;;
  *)
    printf 'Unsupported image build event\n' >&2
    exit 1
    ;;
esac

if [[ ! "$SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'SOURCE_SHA must be a full Git commit SHA\n' >&2
  exit 1
fi

registry=europe-west3-docker.pkg.dev/prokube
image=mlflow-oidc-auth

if [[ "$EVENT_NAME" == push && "$REF_TYPE" == tag ]]; then
  if [[ ! "$REF_NAME" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)_v[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?$ ]]; then
    printf 'Release tag must match vA.B.C_vX.Y.Z or vA.B.C_vX.Y.Z-rcN\n' >&2
    exit 1
  fi
  if [[ "${BASH_REMATCH[1]}" != "$OIDC_VERSION" ]]; then
    printf 'Release tag upstream version does not match the built OIDC version\n' >&2
    exit 1
  fi
  printf 'publish=true\nrelease=true\nimage_tag=%s/releases/%s:%s\n' "$registry" "$image" "$REF_NAME"
  printf 'commit_tag=\n'
else
  safe_ref=$(printf '%s' "$REF_NAME" | LC_ALL=C tr -c 'A-Za-z0-9_.-' '-')
  printf 'publish=true\nrelease=false\nimage_tag=%s/development/%s:branch-%.121s\n' "$registry" "$image" "$safe_ref"
  printf 'commit_tag=%s/development/%s:commit-%s\n' "$registry" "$image" "$SOURCE_SHA"
fi
