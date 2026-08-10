#!/usr/bin/env bash
set -euo pipefail

: "${EPISODE_ID:?Set EPISODE_ID}"
: "${DATABASE_URL:?Set DATABASE_URL}"

command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }

OUT="${OUT_FILE:-docs/rehearsals/${EPISODE_ID}-report.md}"
export PGPASSWORD="${DATABASE_PASSWORD:-}"

run_sql() { psql "$DATABASE_URL" --no-align --tuples-only -c "$1"; }

episode_status=$(run_sql "select status from episodes where id='${EPISODE_ID}';")
created_at=$(run_sql "select created_at from episodes where id='${EPISODE_ID}';")
updated_at=$(run_sql "select updated_at from episodes where id='${EPISODE_ID}';")
approved_at=$(run_sql "select coalesce(to_char(approved_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'),'') from episodes where id='${EPISODE_ID}';")
estimated=$(run_sql "select coalesce(estimated_seconds,0) from episodes where id='${EPISODE_ID}';")
audio_checksum=$(run_sql "select coalesce(audio_checksum,'') from episodes where id='${EPISODE_ID}';")
segments=$(run_sql "select count(*) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}';")
host_count=$(run_sql "select count(distinct speaker) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}';")
source_count=$(run_sql "select count(*) from script_segments s join scripts sc on sc.id=s.script_id where sc.episode_id='${EPISODE_ID}' and jsonb_array_length(coalesce(s.source_urls,'[]'::jsonb)) > 0;")
script_version=$(run_sql "select max(version) from scripts where episode_id='${EPISODE_ID}';")
speech_checksum=$(run_sql "select checksum from audio_assets where episode_id='${EPISODE_ID}' and kind='speech_only' order by created_at desc limit 1;")
final_checksum=$(run_sql "select checksum from audio_assets where episode_id='${EPISODE_ID}' and kind='final_mix' order by created_at desc limit 1;")
final_duration=$(run_sql "select coalesce(duration_seconds,0) from audio_assets where episode_id='${EPISODE_ID}' and kind='final_mix' order by created_at desc limit 1;")
music_info=$(run_sql "select coalesce(json_agg(m.id || '|' || m.license_type || '|' || m.license_evidence), '{}'::text)
  from mix_versions mv
  join music_tracks m on m.id=mv.music_track_id
  where mv.episode_id='${EPISODE_ID}' and m.rights_confirmed=true
  ;")
transistor_row=$(run_sql "select coalesce(public_url,'')||'|'||coalesce(external_id,'')||'|'||status||'|'||coalesce(attempts,0)||'|'||coalesce(last_error,'')
  from publish_deliveries where episode_id='${EPISODE_ID}' and channel='transistor' order by created_at desc limit 1;")
telegram_row=$(run_sql "select coalesce(public_url,'')||'|'||coalesce(external_id,'')||'|'||status||'|'||coalesce(attempts,0)||'|'||coalesce(last_error,'')
  from publish_deliveries where episode_id='${EPISODE_ID}' and channel='telegram' order by created_at desc limit 1;")
cost_sar=$(run_sql "select coalesce(sum(cost_sar),0) from provider_usage where episode_id='${EPISODE_ID}';")
audit_count=$(run_sql "select count(*) from audit_events where entity_type='episode' and entity_id='${EPISODE_ID}';")
host_a_voice="${ELEVENLABS_HOST_A_VOICE_ID:--}"
host_b_voice="${ELEVENLABS_HOST_B_VOICE_ID:--}"
voice_approval="${VOICE_QUALITY_APPROVAL:-required_before_production}"
duplicate_ok="${DUPLICATE_PREVENTION_OK:-required_before_publish}"
commit="$(git rev-parse --short HEAD)"

cat > "$OUT" <<EOF
# Rehearsal Report for Episode ${EPISODE_ID}

## Timing
- Episode created at (UTC): ${created_at}
- Episode updated at (UTC): ${updated_at}
- Episode approved at (UTC): ${approved_at}
- Commit: ${commit}
- Environment: staging
- Auto-publish expected off: true (must confirm after run)

## Generation outcome
- Episode status: ${episode_status}
- Estimated duration seconds: ${estimated}
- Final duration seconds: ${final_duration}
- Segment count: ${segments}
- Segment host diversity: ${host_count}
- Segments with source references: ${source_count}
- Script version: ${script_version}
- Episode audio checksum: ${audio_checksum}
- Speech-only checksum: ${speech_checksum}
- Final checksum: ${final_checksum}

## Music
- Licensed music tracks used: ${music_info}

## Publish outcome
- Transistor row: ${transistor_row}
- Telegram row: ${telegram_row}

## Cost and audit
- Provider cost (SAR): ${cost_sar}
- Audit events for episode: ${audit_count}

## Review checklist
- Voice A ID: ${host_a_voice}
- Voice B ID: ${host_b_voice}
- Saudi-listener approval: ${voice_approval}
- Owner approval timestamp: ${approved_at}
- Duplicate-prevention status: ${duplicate_ok}
EOF

echo "Wrote rehearsal report to $OUT"
