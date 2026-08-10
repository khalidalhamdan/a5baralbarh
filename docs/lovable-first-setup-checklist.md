# Lovable-first setup checklist (بديل Railway)

## What Lovable replaces from Railway

- **Scheduling / jobs orchestration**: use **Lovable Jobs** (cron-like schedules).
- **Lightweight server endpoints**: keep this repo in place and expose endpoint jobs through a Lovable-deployed Next.js control app, or use **Lovable Edge Functions** for short callbacks.
- **Secret handling**: keep all sensitive keys in **Lovable Cloud → Secrets** (not in code).
- **UI deployment**: keep the Arabic admin in Lovable with GitHub-sync (one branch at a time).
- **Project ownership for backend (optional)**: use your own Supabase (your account/risk profile) instead of Lovable Cloud.

Still needed outside Lovable:

- **Long-running audio jobs** (FFmpeg + TTS + mixing) if they exceed Lovable Job runtime limits.
- **Optional external container host** (Cloud Run, ECS, VPS, etc.) for `Dockerfile.worker`.
- **Transistor publishing callbacks/telemetry** to persist external API state and Telegram confirmations (depends on stable external APIs).

## 1) Create source-of-truth linkage

1. In GitHub: keep this repository as the source branch you want Lovable to sync.
2. In Lovable: open **Project settings → Git → GitHub** and connect the same branch.
3. Confirm one-way and two-way sync in settings before deployment.

### Recommended production topology with one control plane

- **Lovable (control plane + admin):** Next.js dashboard, schedule trigger, owner auth, approvals, source management, publishing toggles.
- **Your chosen Supabase project:** DB/auth/RLS/storage.
- **External worker runtime (recommended):** runs `./src/worker.ts`, does RSS ingestion, AI synthesis, FFmpeg mix, object storage writes.
- **Transistor/Telegram:** keep outbound publishing from admin worker API routes so owner can audit every action.

Why external worker remains:
- Audio generation and clipping are long-running; this is the main reason to avoid placing heavy jobs purely in Lovable unless you’ve validated the runtime limits.

## 2) Configure runtime secrets

Set these in Lovable Secrets (no secrets in code or client):

- `DATABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `OWNER_EMAIL`
- `OPENAI_API_KEY`
- `ELEVENLABS_API_KEY`
- `ELEVENLABS_HOST_A_VOICE_ID`
- `ELEVENLABS_HOST_B_VOICE_ID`
- `R2_ENDPOINT`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `TRANSISTOR_API_KEY`
- `TRANSISTOR_SHOW_ID`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `WORKER_TRIGGER_TOKEN`
- `PUBLISHING_ENABLED=false` for rehearsals
- optional: `AZURE_SPEECH_KEY`, `AZURE_SPEECH_REGION`, `APP_TIMEZONE`, `OPENAI_MODEL`

## 3) Schedule run in Lovable

1. Go to **Cloud → Jobs**.
2. Create one job:
   - Schedule: `06:00` in `Asia/Riyadh`
   - Method: `POST`
   - URL: `https://<your-lovable-app-domain>/api/ops/run-daily`
   - Headers: `x-worker-token: <WORKER_TRIGGER_TOKEN>`
3. Save and run once manually first.

## 4) Validate 24/7 readiness

1. Run `pnpm preflight` once in staging (admin machine).
2. Trigger job manually once:
   - expect one `needs_review` episode in 2-8 minutes.
3. Owner approves the episode in admin.
4. Enable publish only for staging rehearsal:
   - set `PUBLISHING_ENABLED=true` temporarily in staging runtime/secret scope,
   - publish once and then again for idempotency proof,
   - set `PUBLISHING_ENABLED=false` immediately after.
5. Keep logs for each run in `docs/rehearsals/README.md`.
