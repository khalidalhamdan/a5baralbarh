#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL}"
: "${DATABASE_PASSWORD:=}"
export PGPASSWORD="${DATABASE_PASSWORD}"
: "${EPISODE_ID:=}"

run_sql() {
  psql "$DATABASE_URL" --no-align --tuples-only -c "$1"
}

need_num() {
  local got="$1" expected="$2" label="$3"
  if [[ "$got" != "$expected" ]]; then
    echo "FAIL: ${label}: got='${got}', expected='${expected}'"
    exit 1
  fi
  echo "PASS: ${label}: ${got}"
}

need_in_range() {
  local got="$1" lo="$2" hi="$3" label="$4"
  if ! [[ "$got" =~ ^[0-9]+$ ]] || (( got < lo || got > hi )); then
    echo "FAIL: ${label}: got='${got}', expected between ${lo}..${hi}"
    exit 1
  fi
  echo "PASS: ${label}: ${got}"
}

if [[ -z "$EPISODE_ID" ]]; then
  echo "INFO: EPISODE_ID not provided; using latest needs_review/approved/publishing/published episode."
  EPISODE_ID="$(run_sql "select id from episodes where status in ('needs_review','approved','publishing','published') order by created_at desc limit 1")"
  if [[ -z "$EPISODE_ID" ]]; then
    echo "FAIL: no episode found in expected statuses"
    exit 1
  fi
fi

echo "Evaluating episode: ${EPISODE_ID}"

status="$(run_sql "select status from episodes where id='${EPISODE_ID}'")"
echo "status: ${status}"
segments="$(run_sql "select count(*) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}'")"
host_count="$(run_sql "select count(distinct speaker) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}'")"
covered="$(run_sql "select count(*) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}' and jsonb_array_length(coalesce(s.source_urls, '[]'::jsonb)) > 0")"
final_mix_valid="$(run_sql "select count(*) from audio_assets where episode_id='${EPISODE_ID}' and kind='final_mix' and valid=true")"
licensed_music="$(run_sql "select count(*) from mix_versions mv join music_tracks m on m.id=mv.music_track_id where mv.episode_id='${EPISODE_ID}' and m.rights_confirmed=true")"
estimated="$(run_sql "select coalesce(estimated_seconds,0) from episodes where id='${EPISODE_ID}'")"
created_at="$(run_sql "select created_at from episodes where id='${EPISODE_ID}'")"

echo "segment_count=${segments}"
echo "host_count=${host_count}"
echo "covered_segments=${covered}"
echo "final_mix_valid=${final_mix_valid}"
echo "licensed_music_used=${licensed_music}"
echo "estimated_seconds=${estimated}"
echo "created_at=${created_at}"

if (( segments < 5 || segments > 8 )); then
  echo "FAIL: segment_count=${segments} (expected 5..8)"; exit 1
fi

if (( host_count != 2 )); then
  echo "FAIL: host_count=${host_count} (expected 2: host_a, host_b)"; exit 1
fi

need_num "$covered" "$segments" "segments_with_sources" >/dev/null
need_num "$final_mix_valid" "1" "valid_final_mix" >/dev/null
if (( licensed_music < 1 )); then
  echo "FAIL: licensed_music_used=${licensed_music} (expected >=1)"; exit 1
fi
need_in_range "$estimated" 480 720 "estimated_seconds"

echo "PASS: episode draft/pipeline constraints"

echo "Checking auto-publish lock (admin health if ADMIN_BASE_URL set)."
if [[ -n "${ADMIN_BASE_URL:-}" ]]; then
  lock="$(curl -fsS "${ADMIN_BASE_URL}/api/health" | jq -r '.publishingEnabled // false')"
  echo "admin_publishingEnabled=${lock}"
  if [[ "$lock" == "false" ]]; then
    echo "PASS: publishing lock is disabled (false)"
  else
    echo "FAIL: publishing lock is true"; exit 1
  fi
fi

echo "Checking publish deliveries (if any)."
for ch in transistor telegram; do
  rows="$(run_sql "select count(*) from publish_deliveries where episode_id='${EPISODE_ID}' and channel='${ch}'")"
  published="$(run_sql "select count(*) from publish_deliveries where episode_id='${EPISODE_ID}' and channel='${ch}' and status='published'")"
  ext_count="$(run_sql "select count(distinct external_id) from publish_deliveries where episode_id='${EPISODE_ID}' and channel='${ch}' and external_id is not null")"
  key_count="$(run_sql "select count(distinct idempotency_key) from publish_deliveries where episode_id='${EPISODE_ID}' and channel='${ch}'")"
  echo "${ch}: rows=${rows}, published=${published}, external_ids=${ext_count}, idempotency_keys=${key_count}"
  if [[ "${rows}" == "0" ]]; then
    echo "INFO: no publish attempts for ${ch} yet"
  elif (( rows != 1 || published != 1 || ext_count != 1 || key_count != 1 )); then
    echo "FAIL: publish invariants not met for ${ch}"; exit 1
  fi
done

echo "Objective evidence checks completed for episode ${EPISODE_ID}"
