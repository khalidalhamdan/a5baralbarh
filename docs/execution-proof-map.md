# Execution proof map (current branch)

Use this to validate the objective end-to-end from your staging environment.

## 1) CI health (must pass before release)

- `pnpm objective:ci` (runs `pnpm typecheck`, `pnpm test`, `pnpm build`)
- or run those commands individually.

Why this repo: scripts and API routes already include:
- `typecheck` gate in `.github/workflows/ci.yml`
- route-level publish safety checks
- rehearsal scripts with SQL assertions

## 2) One allowlisted RSS run creates draft

Run:

```bash
pnpm rehearsal:staging:dry
```

Expected:
- active feed count > 0
- generated episode status `needs_review`
- 5–8 script segments
- speakers include `host_a` and `host_b`
- every segment has at least one source URL
- final mix exists and is valid
- licensed music attached

SQL/command checks are already in `scripts/run-staging-rehearsal.sh`.

You can run the full sequence from one command (including approval wait + publish verification + evidence output) using:

```bash
OUT_FILE=docs/rehearsals/$(date +%F)-objective.md \
SESSION_COOKIE='<browser session cookie>' \
ADMIN_BASE_URL=... WORKER_TRIGGER_TOKEN=... DATABASE_URL=... \
./scripts/objective-e2e.sh
```

Notes for controlled publish window:
- `./scripts/objective-e2e.sh` now requires `ADMIN_BASE_URL` to report `publishingEnabled=true` before step 3.
- Keep publishing disabled for rehearsal draft and enable it only just before publish, then disable immediately after your run.

## 3) Owner approval gate

Open episode in admin, approve, then confirm:
- status `approved`
- latest `audio_assets` row for `kind='final_mix'` is `valid=true`
- `episode.approved` row appears in `audit_events`

Approval route enforces valid final mix + approved snapshot.

## 4) Idempotent publish to Transistor + Telegram

Set `PUBLISHING_ENABLED=true`, provide `SESSION_COOKIE`, then:

```bash
SESSION_COOKIE='<cookie>' AUTO_EXIT=true AUTO_PUBLISH=true pnpm rehearsal:staging:publish
```

Then run:

```bash
./scripts/verify-rehearsal.sh
```

Expected:
- `episodes.status = published`
- both `transistor` and `telegram` each have exactly one row in `publish_deliveries`
- each channel has exactly one `published` row, one external ID, one idempotency key.

## 5) Public auto-publish remains off

Keep `PUBLISHING_ENABLED=false` except during controlled rehearsal publish windows.

`staging-preflight.sh` and `scripts/run-staging-rehearsal.sh` explicitly fail if it is true before drafting.

## 6) Evidence package required after each run

After any publish test:

```bash
OUT_FILE=docs/rehearsals/$(date +%F)-run-01.md ./scripts/export-rehearsal-report.sh
```

Record:
- episode ID
- durations
- checksums
- Transistor/Telegram external IDs
- publish row counts
- cost totals
- owner approval timestamp

You can run a deterministic post-run check:

```bash
EPISODE_ID=<episode-id> DATABASE_URL=... ADMIN_BASE_URL=https://<staging> \
PUBLISHING_LOCK_CHECK=report scripts/objective-evidence-check.sh
```

For an explicit post-publish safety audit requiring lock disabled:

```bash
EPISODE_ID=<episode-id> DATABASE_URL=... ADMIN_BASE_URL=https://<staging> \
PUBLISHING_LOCK_CHECK=require_false scripts/objective-evidence-check.sh
```

## Current known blockers (this execution environment)

- No local Node runtime in this sandbox, so `pnpm objective:ci` cannot execute here.
- No external network access from shell, so GitHub and provider API checks are manual from your staging environment.

## Note on staging preflight

- `scripts/staging-preflight.sh` now fails fast if any required runtime secret is missing:
  - `OPENAI_API_KEY`
  - ElevenLabs keys + both voice IDs
  - Transistor credentials
  - Telegram credentials
  - R2 credentials
