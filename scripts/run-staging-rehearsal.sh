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
  echo "run-daily response: $RUN_ID"; exit 1
fi

echo "Episode started/returned: $RUN_ID"

PSQL_FLAGS=(--no-align --tuples-only)

psql "$DATABASE_URL" "${PSQL_FLAGS[@]}" -c "\
  select id,status,estimated_seconds,audio_checksum from episodes where id='${RUN_ID}';"

echo "=== Episode checks ==="
psql "$DATABASE_URL" "${PSQL_FLAGS[@]}" -c "\
  select 'segments',count(*) from script_segments s 
  join scripts sc on sc.id=s.script_id where sc.episode_id='${RUN_ID}';"

psql "$DATABASE_URL" "${PSQL_FLAGS[@]}" -c "\
  select 'sources',count(distinct jsonb_array_elements_text(source_urls)) 
  from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${RUN_ID}';"

psql "$DATABASE_URL" "${PSQL_FLAGS[@]}" -c "\
  select 'final_mix',count(*) from audio_assets where episode_id='${RUN_ID}' and kind='final_mix' and valid=true;"

psql "$DATABASE_URL" "${PSQL_FLAGS[@]}" -c "\
  select 'needs_review_count',count(*) from episodes where id='${RUN_ID}' and status='needs_review';"

psql "$DATABASE_URL" "${PSQL_FLAGS[@]}" -c "\
  select 'music_tracks_used',coalesce(json_agg(m.id || ':' || m.license_type || ':' || m.license_evidence), '{}') 
  from mix_versions mv 
  join music_tracks m on m.id=mv.music_track_id 
  where mv.episode_id='${RUN_ID}' and m.rights_confirmed=true;"

psql "$DATABASE_URL" <<SQL
select id,status,estimated_seconds from episodes where id='${RUN_ID}';
select count(*) as needs_review_count from episodes where id='${RUN_ID}' and status='needs_review';
select channel,status,idempotency_key,attempts from publish_deliveries where episode_id='${RUN_ID}' order by created_at asc;
SQL

echo "Next: owner review in admin, then run publish twice manually while PUBLISHING_ENABLED=true on staging."
