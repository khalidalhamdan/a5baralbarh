#!/usr/bin/env bash
set -euo pipefail

: "${ADMIN_BASE_URL:?Set ADMIN_BASE_URL (e.g. https://your-staging-app.lovable.app)}"
: "${WORKER_TRIGGER_TOKEN:?Set WORKER_TRIGGER_TOKEN}"
: "${DATABASE_URL:?Set DATABASE_URL}"
: "${DATABASE_PASSWORD:=}"

export DATABASE_PASSWORD
AUTO_PUBLISH="${AUTO_PUBLISH:-false}"
AUTO_EXIT="${AUTO_EXIT:-false}"
OUT_FILE="${OUT_FILE:-}"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 1; }

echo "=== Stage 0: Preflight ==="
./scripts/staging-preflight.sh

echo "=== Stage 1: Generate and draft-gate rehearsal ==="
export ADMIN_BASE_URL
export WORKER_TRIGGER_TOKEN
export DATABASE_URL
RUN_OUTPUT="$(./scripts/run-staging-rehearsal.sh)"
printf '%s\n' "$RUN_OUTPUT"

EPISODE_ID="$(printf '%s\n' "$RUN_OUTPUT" | awk -F 'Episode started/returned: ' '/Episode started\/returned: / {print $2}' | tail -n 1 | tr -d '\r')"
if [ -z "$EPISODE_ID" ]; then
  echo "ERROR: Could not parse Episode ID from rehearsal output."
  exit 1
fi

echo "Episode generated: ${EPISODE_ID}"
echo "Owner action required: open ${ADMIN_BASE_URL}/episodes/${EPISODE_ID} and approve before publish."

if [ -z "$OUT_FILE" ]; then
  OUT_FILE="docs/rehearsals/${EPISODE_ID}-rehearsal.md"
fi

if [ "${AUTO_PUBLISH}" != "true" ]; then
  EPISODE_ID="$EPISODE_ID" OUT_FILE="$OUT_FILE" ./scripts/export-rehearsal-report.sh
  if [ "${AUTO_EXIT}" == "true" ]; then
    exit 0
  fi
  echo "Stopping at draft checkpoint. Set AUTO_PUBLISH=true to continue with controlled publish test."
  exit 0
fi

if [ "${AUTO_PUBLISH}" == "true" ]; then
  : "${SESSION_COOKIE:?Set SESSION_COOKIE for authenticated browser session}"
fi

echo "=== Stage 2: Controlled publish test ==="

export EPISODE_ID
./scripts/rehearsal-publish.sh

if [ -n "$OUT_FILE" ]; then
  echo "=== Stage 3: Evidence export ==="
  OUT_FILE="$OUT_FILE" ./scripts/export-rehearsal-report.sh
fi

echo "=== Stage 4: Publish verification ==="
EPISODE_ID="$EPISODE_ID" ./scripts/verify-rehearsal.sh

echo "E2E rehearsal completed for episode ${EPISODE_ID}"
