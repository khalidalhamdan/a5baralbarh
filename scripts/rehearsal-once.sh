#!/usr/bin/env bash
set -euo pipefail

: "${ADMIN_BASE_URL:?Set ADMIN_BASE_URL, e.g. https://your-app.lovable.app}"
: "${WORKER_TRIGGER_TOKEN:?Set WORKER_TRIGGER_TOKEN}"
: "${DATABASE_URL:?Set DATABASE_URL}"
: "${DATABASE_PASSWORD:=}"
: "${OUT_FILE:=}"
: "${AUTO_PUBLISH:=false}"
: "${AUTO_EXIT:=false}"

export DATABASE_PASSWORD

echo "[1/4] Preflight checks"
./scripts/staging-preflight.sh

echo "[2/4] Run rehearsal generation"
export ADMIN_BASE_URL
export WORKER_TRIGGER_TOKEN
export DATABASE_URL
export AUTO_EXIT=false
if [[ "${AUTO_PUBLISH}" == "true" ]]; then
  echo "AUTO_PUBLISH enabled; generation will pause for manual approval first"
else
  echo "AUTO_PUBLISH disabled; generation and pause will stop after needs_review"
fi

OP_OUTPUT="$({ ./scripts/staging-rehearsal-operator.sh; } | tee /dev/stdout)"
EPISODE_ID="$(echo "$OP_OUTPUT" | awk -F 'Episode generated: ' '/Episode generated: / {print $2}' | tail -n1 | tr -d '\r')"
if [[ -z "$EPISODE_ID" ]]; then
  EPISODE_ID="$(echo "$OP_OUTPUT" | awk -F 'Episode started/returned: ' '/Episode started\/returned: / {print $2}' | tail -n1 | tr -d '\r')"
fi
if [[ -z "$EPISODE_ID" ]]; then
  echo "ERROR: Could not determine EPISODE_ID from rehearsal output"
  exit 1
fi

echo "[3/4] Episode candidate: $EPISODE_ID"
echo "Owner approval required before publishing. Open $ADMIN_BASE_URL/episodes/$EPISODE_ID and approve."

if [[ "${AUTO_PUBLISH}" == "true" ]]; then
  echo "Set PUBLISHING_ENABLED=true and run publish step with session cookie."
  echo "Example:"
  echo "  export EPISODE_ID=$EPISODE_ID"
  echo "  export SESSION_COOKIE='...'"
  echo "  AUTO_EXIT=true ./scripts/staging-rehearsal-operator.sh"
else
  echo "Skipping publish test in this run."
fi

export EPISODE_ID

if [[ -n "${OUT_FILE}" ]]; then
  echo "[4/4] Exporting rehearsal report to ${OUT_FILE}"
  OUT_FILE="$OUT_FILE" ./scripts/export-rehearsal-report.sh
else
  echo "[4/4] Export not requested (set OUT_FILE to capture evidence markdown)."
fi

echo "Rehearsal done."
echo "Episode id: $EPISODE_ID"
