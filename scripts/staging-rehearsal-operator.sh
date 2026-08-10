#!/usr/bin/env bash
set -euo pipefail

: "${ADMIN_BASE_URL:?Set ADMIN_BASE_URL}"
: "${WORKER_TRIGGER_TOKEN:?Set WORKER_TRIGGER_TOKEN}"
: "${DATABASE_URL:?Set DATABASE_URL}"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 1; }

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_EXIT="${AUTO_EXIT:-false}"
PUBLISH="${AUTO_PUBLISH:-false}"
REPORT_FILE="${REPORT_FILE:-}"

echo "Starting rehearsal operator..."
echo "Target: $ADMIN_BASE_URL"

if [[ "${AUTO_EXIT}" != "true" ]]; then
  echo
  echo "This operator executes: collect → gated review checks → (manual review) → optional publish"
  echo "Set AUTO_EXIT=true to avoid pauses (for CI-like automation)."
fi

RUN_OUTPUT="$("$DIR/run-staging-rehearsal.sh" | tee /dev/stdout)"
EPISODE_ID="$(echo "$RUN_OUTPUT" | awk -F 'Episode started/returned: ' '/Episode started\/returned: / {print $2}' | tail -n1 | tr -d '\r')"
if [[ -z "$EPISODE_ID" ]]; then
  EPISODE_ID="$(echo "$RUN_OUTPUT" | awk -F 'Episode started/returned: ' '/Episode started\/returned: / {print $2}' | tail -n1 | tr -d '\r')"
fi
if [[ -z "${EPISODE_ID}" ]]; then
  echo "Missing EPISODE_ID from run-staging-rehearsal output. Aborting."
  exit 1
fi
export EPISODE_ID

echo
echo "Episode generated: ${EPISODE_ID}"
echo "Open admin at ${ADMIN_BASE_URL}/episodes/${EPISODE_ID} and complete owner approval."

if [[ "${AUTO_EXIT}" != "true" ]]; then
  read -r -p "Have you approved episode ${EPISODE_ID} in admin? (y/N) " ok
  if [[ "${ok}" != "y" && "${ok}" != "Y" ]]; then
    echo "Stopped after review checkpoint. Resume publish later with:"
    echo "  EPISODE_ID=${EPISODE_ID} SESSION_COOKIE=<cookie> DATABASE_URL=... ${DIR}/rehearsal-publish.sh"
    echo "  ${DIR}/export-rehearsal-report.sh (optional)"
    echo "  EPISODE_ID=${EPISODE_ID} DATABASE_URL=... ${DIR}/verify-rehearsal.sh"
    exit 0
  fi
fi

if [[ "${PUBLISH}" != "true" ]]; then
  echo "Skipping publish by default. To publish in rehearsal mode, set AUTO_PUBLISH=true."
  echo "If publishing is enabled, provide SESSION_COOKIE and rerun:"
  echo "  AUTO_PUBLISH=true AUTO_EXIT=true EPISODE_ID=${EPISODE_ID} SESSION_COOKIE=... ${DIR}/staging-rehearsal-operator.sh"
  exit 0
fi

: "${SESSION_COOKIE:?Set SESSION_COOKIE before publish}"

"$DIR/rehearsal-publish.sh"

if [[ -n "${REPORT_FILE}" ]]; then
  OUT_FILE="${REPORT_FILE}" "$DIR/export-rehearsal-report.sh"
else
  "$DIR/export-rehearsal-report.sh"
fi

echo
echo "Running strict verifier (post-publish)."
"$DIR/verify-rehearsal.sh"

echo "Done."
