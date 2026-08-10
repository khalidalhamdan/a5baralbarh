#!/usr/bin/env bash
set -euo pipefail

: "${ADMIN_BASE_URL:?Set ADMIN_BASE_URL (e.g. https://your-staging-app.lovable.app)}"
: "${EPISODE_ID:?Set EPISODE_ID from rehearsal run}"
: "${SESSION_COOKIE:?Set SESSION_COOKIE containing authenticated browser session}"
: "${DATABASE_URL:?Set DATABASE_URL}"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 1; }

export PGPASSWORD="${DATABASE_PASSWORD:-}"

publish_once() {
  local tag="$1"
  echo "[$tag] POST /api/episodes/${EPISODE_ID}/publish"
  local tmp
  tmp="$(mktemp)"
  local body
  body="$(curl -sS -X POST "$ADMIN_BASE_URL/api/episodes/$EPISODE_ID/publish" \
    -H "Origin: $ADMIN_BASE_URL" \
    -H "Cookie: $SESSION_COOKIE" \
    -b "$SESSION_COOKIE" \
    -w "\\nHTTP_STATUS=%{http_code}\\n" \
    | tee "$tmp")"
  echo "$body"
  if ! echo "$body" | jq -e '.ok == true or .error != null' >/dev/null 2>&1; then
    echo "Publish response did not contain expected JSON shape"; rm "$tmp"; return 1
  fi
  rm "$tmp"
  echo
}

echo "=== Rehearsal publish idempotency test ==="
publish_once "first"
publish_once "second"

echo "=== DB delivery rows for episode ==="
psql "$DATABASE_URL" --no-align --tuples-only -c "\
  select channel,status,idempotency_key,attempts,external_id,public_url,last_error,updated_at \
  from publish_deliveries \
  where episode_id='${EPISODE_ID}' \
  order by created_at asc;"

echo "Expected invariant: exactly one row per channel, status should be 'published' for both transistor and telegram, attempts should be >=1."
