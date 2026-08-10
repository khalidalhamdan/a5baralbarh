# Staging rehearsal evidence

Create one Markdown file per supervised run named `YYYY-MM-DD-run-N.md`. Never include API keys, tokens, signed URLs, or private credentials.

Record:

- UTC and Asia/Riyadh start/end times
- exact Git commit and environment (`staging` only)
- enabled RSS feeds and selected source URLs
- episode ID, script version, segment count, and both voice IDs (last four characters only)
- speech-only and final audio checksums
- final duration; acceptable range is 480–720 seconds
- licensed music track ID and license evidence reference
- Saudi-listener voice decision for each host: approve/revise
- owner approval timestamp
- Transistor staging external ID and Telegram staging message ID
- idempotency retry result: no duplicate delivery
- failures, retries, cost, and final decision

Public auto-publishing must remain disabled throughout all seven rehearsals.

## How to run one rehearsal (operator sequence)

1. Confirm secrets and safety
   - `PUBLISHING_ENABLED=false`
   - `WORKER_TRIGGER_TOKEN`, provider keys, Supabase URL/key, and `WORKER_TRIGGER_TOKEN` are set
   - one default music track has `rights_confirmed=true`
2. Trigger one daily run from staging admin/job:

   ```bash
   curl -X POST "$ADMIN_BASE_URL/api/ops/run-daily" \
     -H "x-worker-token: $WORKER_TRIGGER_TOKEN" \
     -H "Origin: $ADMIN_BASE_URL"
   ```

   You can also run:

   ```
   ./scripts/run-staging-rehearsal.sh
   ```

   The helper script validates and exits with failure if any gate fails:

   - episode entered `needs_review`
   - both `host_a` and `host_b` are present
   - `estimated_seconds` is `480..720`
   - at least 5 and at most 8 segments exist
   - each segment has at least one source URL
   - final mix exists and is valid
   - at least one licensed music track was attached
   - prints publish delivery rows (if any) for idempotency verification

3. Verify run outcome in DB:

   - latest episode status is `needs_review`
   - `duration_seconds` between `480` and `720` in latest final mix
   - at least one `music_tracks.rights_confirmed=true` row exists and was used
   - final asset has `kind='final_mix'`

4. Owner approval:

   - open episode in admin and click approve
   - ensure `episode.approved` event appears in `audit_events`

5. Enable staging publish once for this run:

   - set `PUBLISHING_ENABLED=true` in staging runtime only for the approved run

6. Call publish twice to verify idempotency:

   ```bash
   curl -X POST "$ADMIN_BASE_URL/api/episodes/{episodeId}/publish" \
     -b "$COOKIE" \
     -H "Origin: $ADMIN_BASE_URL"
   # call the exact same request again within seconds/minutes
   ```

7. In DB, confirm:

   - only one published row per channel in `publish_deliveries` by unique `idempotency_key`
   - no duplicate Telegram/transistor external IDs were appended

8. Capture evidence in `docs/rehearsals/YYYY-MM-DD-run-N.md` (timestamps, IDs, checksums, costs, failures/retries, final status)

9. Immediately set `PUBLISHING_ENABLED=false` again.
