#!/usr/bin/env bash
set -euo pipefail

: "${ADMIN_BASE_URL:?Set ADMIN_BASE_URL (e.g. https://your-app.lovable.app)}"
: "${WORKER_TRIGGER_TOKEN:?Set WORKER_TRIGGER_TOKEN}"
: "${DATABASE_URL:?Set DATABASE_URL}"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 1; }

export PGPASSWORD="${DATABASE_PASSWORD:-}"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Rehearsal start: $TS"

RUN_ID=$(curl -sS -X POST "$ADMIN_BASE_URL/api/ops/run-daily" \
  -H "Origin: $ADMIN_BASE_URL" \
  -H "x-worker-token: $WORKER_TRIGGER_TOKEN" | jq -r '.episodeId // .error')

if [[ "$RUN_ID" == "" || "$RUN_ID" == "null" || "$RUN_ID" == "\"\"" ]]; then
  echo "run-daily response: $RUN_ID"
  exit 1
fi

echo "Episode started/returned: $RUN_ID"

PSQL_FLAGS=(--no-align --tuples-only --field-separator=$'\t')

run_sql() {
  psql "$DATABASE_URL" "${PSQL_FLAGS[@]}" -c "$1"
}

expect_between() {
  local value="$1" min="$2" max="$3" label="$4"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "FAIL: $label is not an integer: $value"
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

echo "=== Episode checks ==="
episode_status=$(run_sql "select status from episodes where id='${RUN_ID}';")
estimated=$(run_sql "select coalesce(estimated_seconds,0) from episodes where id='${RUN_ID}';")
expect_eq "$episode_status" "needs_review" "episode status"
expect_between "$estimated" 480 720 "episode duration (estimated_seconds)"

segments=$(run_sql "\
  select count(*)
  from script_segments s
  join scripts sc on sc.id=s.script_id
  where sc.episode_id='${RUN_ID}';")
expect_between "$segments" 5 8 "segment count"
host_count=$(run_sql "\
  select count(distinct speaker)
  from script_segments s
  join scripts sc on sc.id=s.script_id
  where sc.episode_id='${RUN_ID}';")
expect_eq "$host_count" "2" "two-host coverage"
uncovered_segments=$(run_sql "\
  select count(*)
  from script_segments s
  join scripts sc on sc.id=s.script_id
  where sc.episode_id='${RUN_ID}' and jsonb_array_length(coalesce(s.source_urls, '[]'::jsonb)) = 0;")
expect_eq "$uncovered_segments" "0" "segments with zero source URLs"

run_sql "\
  select 'segments',count(*) from script_segments s
  join scripts sc on sc.id=s.script_id where sc.episode_id='${RUN_ID}';"

run_sql "\
  select 'sources',count(distinct jsonb_array_elements_text(source_urls))
  from script_segments s
  join scripts sc on sc.id=s.script_id where sc.episode_id='${RUN_ID}';"

run_sql "\
  select 'final_mix',count(*) from audio_assets where episode_id='${RUN_ID}' and kind='final_mix' and valid=true;"

needs_review_count=$(run_sql "select count(*) from episodes where id='${RUN_ID}' and status='needs_review';")
expect_eq "$needs_review_count" "1" "needs_review row count"

license_count=$(run_sql "\
  select count(*)
  from mix_versions mv
  join music_tracks m on m.id=mv.music_track_id
  where mv.episode_id='${RUN_ID}' and m.rights_confirmed=true;")
expect_eq "$license_count" "1" "licensed music tracks attached"

run_sql "\
  select 'music_tracks_used',coalesce(json_agg(m.id || ':' || m.license_type || ':' || m.license_evidence), '{}')
  from mix_versions mv
  join music_tracks m on m.id=mv.music_track_id
  where mv.episode_id='${RUN_ID}' and m.rights_confirmed=true;"

run_sql "select id,status,estimated_seconds from episodes where id='${RUN_ID}';"
run_sql "select count(*) as needs_review_count from episodes where id='${RUN_ID}' and status='needs_review';"
run_sql "select channel,status,idempotency_key,attempts from publish_deliveries where episode_id='${RUN_ID}' order by created_at asc;"

echo "Next: owner review in admin, then run publish twice manually while PUBLISHING_ENABLED=true on staging."
