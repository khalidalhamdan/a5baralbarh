#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL}"

export PGPASSWORD="${DATABASE_PASSWORD:-}"

command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 1; }

echo "Staging preflight checks"
echo "------------------------"

check_flag() {
  local label="$1" value="$2" expected="$3" op="$4"
  if [[ "${op}" == "eq" && "${value}" == "${expected}" ]]; then
    echo "PASS: ${label} = ${value}"
  elif [[ "${op}" == "gt0" && "${value}" -gt 0 ]]; then
    echo "PASS: ${label} = ${value}"
  elif [[ "${op}" == "gt0" && "${value}" -le 0 ]]; then
    echo "FAIL: ${label} = ${value}, expected > 0"
    exit 1
  else
    echo "WARN: ${label} = ${value}, expected ${expected}"
  fi
}

run_sql() { psql "$DATABASE_URL" --no-align --tuples-only -c "$1"; }

feeds_active=$(run_sql "select count(*) from feeds where active=true;")
check_flag "active feeds" "$feeds_active" ">" "gt0"

licensed_music=$(run_sql "select count(*) from music_tracks where is_default=true and rights_confirmed=true;")
check_flag "default licensed music tracks" "$licensed_music" ">" "gt0"

if [ -n "${OPENAI_API_KEY:-}" ]; then
  echo "PASS: OPENAI_API_KEY present"
else
  echo "WARN: OPENAI_API_KEY missing"
fi

if [ -n "${ELEVENLABS_API_KEY:-}" ] && [ -n "${ELEVENLABS_HOST_A_VOICE_ID:-}" ] && [ -n "${ELEVENLABS_HOST_B_VOICE_ID:-}" ]; then
  echo "PASS: ElevenLabs credentials present"
else
  echo "WARN: ElevenLabs creds incomplete"
fi

if [ -n "${TRANSISTOR_API_KEY:-}" ] && [ -n "${TRANSISTOR_SHOW_ID:-}" ]; then
  echo "PASS: Transistor credentials present"
else
  echo "WARN: Transistor creds incomplete"
fi

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "PASS: Telegram creds present"
else
  echo "WARN: Telegram creds incomplete"
fi

if [ -n "${WORKER_TRIGGER_TOKEN:-}" ]; then
  echo "PASS: WORKER_TRIGGER_TOKEN present"
else
  echo "WARN: WORKER_TRIGGER_TOKEN missing"
fi

if [ "${PUBLISHING_ENABLED:-false}" = "false" ]; then
  echo "PASS: PUBLISHING_ENABLED is false (safety lock on)"
else
  echo "FAIL: PUBLISHING_ENABLED is true (auto publish enabled)"
  exit 1
fi

echo
echo "Preflight complete."
echo "Recommended next step: run ./scripts/staging-rehearsal-operator.sh"
