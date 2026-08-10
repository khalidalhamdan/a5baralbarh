# Lovable as the all-in control plane (replace Railway)

This is the practical execution sequence for moving from the old Railway mindset to Lovable-first operations with this repo as source of truth.

## What replaces Railway

- **Container/cron runtime:** use **Lovable Jobs** for scheduled triggering, with a short protected API endpoint (`/api/ops/run-daily`) as the caller target.
- **Server-side execution for short ops:** use this same Next.js app’s route handlers (keep inside repo, deployed by Lovable Git sync).
- **Secrets + backend config:** use **Lovable Cloud → Secrets** + your own Supabase project.
- **Dashboard hosting:** deploy the Arabic admin via Lovable Git sync.
- **What still needs external runtime:** long-running FFmpeg/TTS/synthesis jobs if they exceed your Lovable job runtime; keep them in `Dockerfile.worker` on a container host.

## One-time migration setup (in order)

1. Keep your branch clean and push to `main`.
2. In Lovable: create/connect project and enable GitHub sync.
3. In Lovable → project Git settings:
   - confirm repo owner/name
   - confirm synced branch (usually `main`)
4. In Supabase: create/apply project and run migration:
   - `supabase/migrations/0001_initial.sql`
5. In the app, set DB owner email setting:
   - `alter database postgres set app.owner_email = 'owner@email'`.
6. In Lovable → Secrets, add required keys (no secrets in `.env` for production):
   - `DATABASE_URL`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
   - `WORKER_TRIGGER_TOKEN`, `OWNER_EMAIL`, `OPENAI_API_KEY`, `OPENAI_MODEL`
   - `ELEVENLABS_API_KEY`, `ELEVENLABS_HOST_A_VOICE_ID`, `ELEVENLABS_HOST_B_VOICE_ID`
   - `AZURE_SPEECH_KEY`, `AZURE_SPEECH_REGION` (if fallback used)
   - `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`
   - `TRANSISTOR_API_KEY`, `TRANSISTOR_SHOW_ID`
   - `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`
   - `PUBLISHING_ENABLED=false` for rehearsal
   - optional operational values: `APP_TIMEZONE`, `DAILY_CRON`, `OPENAI_MODEL`

## Lovable job wiring

1. In **Cloud → Jobs**, create one schedule:
   - cron/timezone: `06:00` in `Asia/Riyadh`
   - method: `POST`
   - URL: `https://<your-lovable-app>/api/ops/run-daily`
   - headers: `x-worker-token: <WORKER_TRIGGER_TOKEN>`
2. Set job to call only this endpoint; keep all heavy AI/audio generation logic in repo code, not in Lovable prompts.
3. Trigger once manually from job UI and verify:
   - API response `{"ok":true,"episodeId":"..."}`
   - new episode appears in `needs_review`.

## Local rehearsal hard stop

From staging env:

```bash
export ADMIN_BASE_URL=https://<your-staging-lovable-app>
export WORKER_TRIGGER_TOKEN=...
export DATABASE_URL=...
./scripts/staging-preflight.sh
./scripts/staging-rehearsal-operator.sh
```

Approval must happen in owner UI. Publishing remains disabled unless explicitly flipped in staging secrets.

## Idempotency proof for publishing (still required)

1. After approval, set `PUBLISHING_ENABLED=true` temporarily.
2. Set `SESSION_COOKIE` from authenticated owner browser session.
3. Publish once then immediately publish again:

```bash
export EPISODE_ID=<id>
export SESSION_COOKIE='<cookie>'
./scripts/rehearsal-publish.sh
```

4. Confirm no duplicate external IDs and one idempotent row per channel in `publish_deliveries`.
5. Return `PUBLISHING_ENABLED=false`.

## If you still need Railway temporarily

You do not need Railway for control plane, UI hosting, scheduling, or secrets in this plan.
Keep only an external worker host if Lovable job/runtime limits block long FFmpeg work, and treat it as a dedicated media job runner using this repo’s `Dockerfile.worker`.
