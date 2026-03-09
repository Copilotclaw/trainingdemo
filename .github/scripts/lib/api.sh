#!/usr/bin/env bash
# lib/api.sh — Platform-aware API helper for shell scripts.
#
# Source this file: source "$(dirname "$0")/lib/api.sh"
# Then use: api_get, api_post, api_patch, api_delete
# Exports:  PLATFORM, API_BASE, API_TOKEN

if [ -n "${GITEA_ACTIONS:-}" ] || [ -n "${GITEA_SERVER_URL:-}" ]; then
  PLATFORM="gitea"
  _GITEA_SERVER="${GITHUB_SERVER_URL:-${GITEA_SERVER_URL:-http://localhost:3000}}"
  API_BASE="${_GITEA_SERVER%/}/api/v1"
  # Prefer LOCAL_PAT (full-access) over repo-scoped github.token
  API_TOKEN="${LOCAL_PAT:-${GITHUB_TOKEN:-${GITEA_TOKEN:-}}}"
elif [ -n "${GITHUB_ACTIONS:-}" ]; then
  PLATFORM="github"
  API_BASE="https://api.github.com"
  API_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
else
  PLATFORM="local"
  API_BASE="https://api.github.com"
  API_TOKEN="${GH_TOKEN:-$(gh auth token 2>/dev/null || echo '')}"
fi

# Explicit override: if BILLING_PAT or GH_TOKEN is set, prefer it for GitHub writes
if [ -n "${BILLING_PAT:-}" ] && [ "${PLATFORM:-}" != "gitea" ]; then
  API_TOKEN="$BILLING_PAT"
fi

export PLATFORM API_BASE API_TOKEN

_api_curl() {
  local method="$1" path="$2" data="${3:-}"
  local url="$API_BASE/${path#/}"
  if [ -n "$data" ]; then
    curl -sf -X "$method" \
      -H "Authorization: token $API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      "$url" -d "$data"
  else
    curl -sf -X "$method" \
      -H "Authorization: token $API_TOKEN" \
      -H "Accept: application/json" \
      "$url"
  fi
}

api_get()    { _api_curl GET    "$1"; }
api_post()   { _api_curl POST   "$1" "${2:-}"; }
api_patch()  { _api_curl PATCH  "$1" "${2:-}"; }
api_delete() { _api_curl DELETE "$1" "${2:-}"; }
