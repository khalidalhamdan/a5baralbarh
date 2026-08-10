#!/usr/bin/env bash
set -euo pipefail

: "${ADMIN_BASE_URL:?Set ADMIN_BASE_URL}"
: "${WORKER_TRIGGER_TOKEN:?Set WORKER_TRIGGER_TOKEN}"
: "${DATABASE_URL:?Set DATABASE_URL}"
: "${EPISODE_ID:=}"
: "${OUT_FILE:=}"
: "${WAIT_APPROVED_SECONDS:=1200}"
: "${POLL_INTERVAL_SECONDS:=10}"

export DATABASE_PASSWORD="${DATABASE_PASSWORD:-}"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

echo "=== Objective rehearsal run (end-to-end) ==="
echo "1) Preflight"
./scripts/staging-preflight.sh

if [[ -n "${EPISODE_ID}" ]]; then
  echo "2) Reusing provided EPISODE_ID: ${EPISODE_ID}"
else
  echo "2) Trigger run + draft gate (needs_review)"
  RUN_OUTPUT="$(./scripts/staging-rehearsal-operator.sh)"
  printf '%s\n' "$RUN_OUTPUT"
  EPISODE_ID="$(printf '%s\n' "$RUN_OUTPUT" \
    | awk -F 'Episode started/returned: ' '/Episode started\/returned: / {print $2}' \
    | tail -n 1 | tr -d '\r')"
  if [[ -z "$EPISODE_ID" ]]; then
    echo "ERROR: Could not determine episode id from rehearsal output."
    exit 1
  fi
fi

echo "Draft episode: ${EPISODE_ID}"
echo "Open the episode for owner approval: ${ADMIN_BASE_URL}/episodes/${EPISODE_ID}"
echo "Waiting up to ${WAIT_APPROVED_SECONDS}s for status='approved'..."

run_sql() { psql "$DATABASE_URL" --no-align --tuples-only -c "$1"; }

deadline=$((SECONDS + WAIT_APPROVED_SECONDS))
while true; do
  status="$(run_sql "select status from episodes where id='${EPISODE_ID}';")"
  if [[ "$status" == "approved" ]]; then
    echo "Status approved."
    break
  fi
  if (( SECONDS >= deadline )); then
    echo "ERROR: Approval timeout reached. Current status: ${status:-unknown}"
    exit 1
  fi
  if [[ "$status" != "needs_review" ]]; then
    echo "Current status: ${status}. Waiting for approval..."
  fi
  sleep "${POLL_INTERVAL_SECONDS}"
done

echo "3) Controlled publish idempotency test"
status="$(curl -fsS "${ADMIN_BASE_URL}/api/health" -H "Origin: ${ADMIN_BASE_URL}" | jq -r '.publishingEnabled // false')"
if [[ "$status" != "true" ]]; then
  echo "ERROR: Controlled publish requires runtime PUBLISHING_ENABLED=true in staging."
  echo "Set it in staging secrets/env first, run:"
  echo "  export PUBLISHING_ENABLED=true"
  echo "  EPISODE_ID=${EPISODE_ID} pnpm rehearsal:staging:objective"
  echo "After publish, set PUBLISHING_ENABLED=false."
  exit 1
fi

: "${SESSION_COOKIE:?Set SESSION_COOKIE for authenticated browser session before controlled publish.}"

AUTO_PUBLISH=true AUTO_EXIT=true OUT_FILE="${OUT_FILE}" ADMIN_BASE_URL="$ADMIN_BASE_URL" WORKER_TRIGGER_TOKEN="$WORKER_TRIGGER_TOKEN" DATABASE_URL="$DATABASE_URL" EPISODE_ID="$EPISODE_ID" SESSION_COOKIE="$SESSION_COOKIE" \
  ./scripts/staging-rehearsal-operator.sh

echo "4) Verify objective invariants"
EPISODE_ID="$EPISODE_ID" ADMIN_BASE_URL="$ADMIN_BASE_URL" DATABASE_URL="$DATABASE_URL" \
  ./scripts/verify-rehearsal.sh

echo "5) Run evidence check"
EPISODE_ID="$EPISODE_ID" ADMIN_BASE_URL="$ADMIN_BASE_URL" DATABASE_URL="$DATABASE_URL" \
  ./scripts/objective-evidence-check.sh

if [[ -n "${OUT_FILE}" ]]; then
  echo "6) Rehearsal report exported to: ${OUT_FILE}"
fi

echo "Objective end-to-end run completed for episode ${EPISODE_ID}"
