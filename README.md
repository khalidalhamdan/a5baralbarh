# سوالف اليوم — Najdi AI News Podcast

Arabic-first control room and production pipeline for a daily, owner-approved Saudi news podcast.

## Safety model

- Publishing is off by default (`PUBLISHING_ENABLED=false`).
- Only `OWNER_EMAIL` can access the configured Supabase application.
- An episode must be in `approved` state and have a valid final mix before publishing.
- Telegram runs only after Transistor returns a public episode URL.
- Every delivery has a stable idempotency key.

## Local setup

1. Install Node 22 and pnpm.
2. Copy `.env.example` to `.env` and add development credentials.
3. Create a Supabase project and apply `supabase/migrations/0001_initial.sql`.
4. Set the Postgres custom setting used by RLS: `alter database postgres set app.owner_email = 'your@email';`.
5. Run `pnpm install`, then `pnpm dev`.
6. Visit `http://localhost:3000`. Without Supabase public variables, the UI runs in local preview mode; production must configure authentication.

Run `pnpm preflight` after adding staging credentials. It performs read-only provider checks and fails if public publishing is enabled.

## Production topology

- Build the Arabic admin visually in Lovable and connect it to the same Supabase-compatible database. Keep privileged provider calls server-side.
- Keep worker execution in `src/worker.ts` and schedule it through Lovable **Jobs** (cron trigger), calling your own worker endpoint from the schedule.
- If heavy FFmpeg rendering exceeds job limits, offload that part to a dedicated container worker while still triggering from Lovable.
- Keep private audio in R2. Store only object keys or short-lived signed URLs in the database.
- Configure Supabase backups and point-in-time recovery before launch.
- Use GitHub for source control and CI/CD, but treat Lovable as the deployment host for the UI where possible.

## Voice acceptance gate

Before generating production episodes, assign distinct Saudi Arabic voice IDs and audition dates, numbers, English names, Saudi locations, formal news, and dialogue. Do not enable publishing until a Saudi listener approves both voices as natural and appropriate.

## Launch checklist

- Add and test RSS feeds from the allowlist.
- Upload only music with documented commercial podcast rights.
- Configure OpenAI, ElevenLabs, R2, Transistor, and Telegram secrets.
- Verify owner-only passwordless login and database RLS.
- Generate, review, and publish only to staging destinations.
- Complete seven consecutive supervised drafts.
- Save each run using `docs/rehearsals/README.md` as the evidence checklist.
- Back up the database and successfully test restoration.
- Switch `PUBLISHING_ENABLED=true` only after the checklist passes.

## Staging rehearsal (recommended)

From a machine with `.env` configured for staging:

```bash
export ADMIN_BASE_URL=https://<your-lovable-app>
export WORKER_TRIGGER_TOKEN=<token>
export DATABASE_URL=<postgres-url>
./scripts/staging-rehearsal-operator.sh
```

The operator runs:

- `/api/ops/run-daily`
- pre-publish gates (`needs_review`, 8–12 minutes target, 5–8 sourced segments, two hosts, final mix present, licensed music present)
- pauses for owner approval

Then, for rehearsal publish proof:

```bash
export ADMIN_BASE_URL=https://<your-lovable-app>
export SESSION_COOKIE="<browser session cookie>"
export EPISODE_ID=<episode-id-from-console>
export AUTO_PUBLISH=true
export AUTO_EXIT=true
./scripts/staging-rehearsal-operator.sh
```

This path will publish once, re-publish once for idempotency verification, export a rehearsal report, and run strict DB validation.

## Current implementation boundary

The repository includes the production schema, dashboard, ingestion, structured AI script generation, resumable segmented ElevenLabs synthesis, R2-backed artifacts, FFmpeg music looping/mixing, approval controls, and idempotent Transistor/Telegram publishing. Real staging credentials, allowlisted feeds, licensed music, and listener-approved voices are still required before the first end-to-end rehearsal.

See `docs/deployment.md` for the Lovable, Supabase, and worker orchestration connection sequence.
