#!/usr/bin/env bash
set -euo pipefail

: "${EPISODE_ID:?Set EPISODE_ID}"
: "${DATABASE_URL:?Set DATABASE_URL}"

command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 1; }

export PGPASSWORD="${DATABASE_PASSWORD:-}"

expect_between() {
  local value="$1" min="$2" max="$3" label="$4"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "FAIL: $label is not numeric: $value"
    exit 1
  fi
  if (( value < min || value > max )); then
    echo "FAIL: $label=$value outside range ${min}..${max}"
    exit 1
  fi
  echo "PASS: $label=$value (range ${min}..${max})"
}

expect_eq() {
  local value="$1" expected="$2" label="$3"
  if [[ "$value" != "$expected" ]]; then
    echo "FAIL: $label is '$value', expected '$expected'"
    exit 1
  fi
  echo "PASS: $label=$value"
}

run_sql() { psql "$DATABASE_URL" --no-align --tuples-only -c "$1"; }

episode_status=$(run_sql "select status from episodes where id='${EPISODE_ID}';")
estimated=$(run_sql "select coalesce(estimated_seconds,0) from episodes where id='${EPISODE_ID}';")
segments=$(run_sql "select count(*) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}';")
host_count=$(run_sql "select count(distinct speaker) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}';")
uncovered=$(run_sql "select count(*) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}' and jsonb_array_length(coalesce(s.source_urls, '[]'::jsonb)) = 0;")
covered=$(run_sql "select count(*) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}' and jsonb_array_length(coalesce(s.source_urls, '[]'::jsonb)) > 0;")
final_mix=$(run_sql "select count(*) from audio_assets where episode_id='${EPISODE_ID}' and kind='final_mix' and valid=true;")
licensed_mix=$(run_sql "select count(*) from mix_versions mv join music_tracks m on m.id=mv.music_track_id where mv.episode_id='${EPISODE_ID}' and m.rights_confirmed=true;")

echo "=== Episode lifecycle checks ==="
expect_eq "$episode_status" "published" "episode status"
expect_between "$estimated" 480 720 "estimated_seconds"
expect_between "$segments" 5 8 "segment count"
expect_eq "$host_count" "2" "host count"
expect_eq "$uncovered" "0" "segments with no source urls"
expect_eq "$covered" "$segments" "segments with source URLs"
expect_eq "$final_mix" "1" "valid final_mix count"
expect_eq "$licensed_mix" "1" "licensed music track count"

echo
echo "=== Publish idempotency checks ==="

for ch in transistor telegram; do
  rows=$(run_sql "select count(*) from publish_deliveries where episode_id='${EPISODE_ID}' and channel='${ch}';")
  ok_rows=$(run_sql "select count(*) from publish_deliveries where episode_id='${EPISODE_ID}' and channel='${ch}' and status='published';")
  distinct_ext=$(run_sql "select count(distinct external_id) from publish_deliveries where episode_id='${EPISODE_ID}' and channel='${ch}' and external_id is not null;")
  distinct_keys=$(run_sql "select count(distinct idempotency_key) from publish_deliveries where episode_id='${EPISODE_ID}' and channel='${ch}';")
  if [[ "$rows" != "1" ]]; then
    echo "FAIL: ${ch} delivery row count is '$rows', expected '1'"
    exit 1
  fi
  if [[ "$ok_rows" != "1" ]]; then
    echo "FAIL: ${ch} published row count is '$ok_rows', expected '1'"
    exit 1
  fi
  if [[ "$distinct_ext" != "1" ]]; then
    echo "FAIL: ${ch} distinct external IDs is '$distinct_ext', expected '1'"
    exit 1
  fi
  if [[ "$distinct_keys" != "1" ]]; then
    echo "FAIL: ${ch} distinct idempotency keys is '$distinct_keys', expected '1'"
    exit 1
  fi
  echo "PASS: ${ch} has one published row, one external ID, and one idempotency key"
done

echo "PASS: rehearsal artifact validation succeeded"
