# Lovable go-live execution guide (Railway replacement)

This is the single operational checklist to move the platform from “code ready” to “running 24/7” using Lovable as the control plane.

## What Lovable replaces

- **Railway app hosting / deploys** → **Lovable hosting** (GitHub sync + deploy)
- **Railway cron jobs** → **Lovable Jobs** (scheduled POST triggers)
- **Railway secret store** → **Lovable Cloud → Secrets**
- **Basic job monitoring** → **Lovable Jobs history + logs**
- **Supabase project linkage** → keep Supabase as your DB/auth/runtime backend (owned by you), then connect it from Lovable
- **(Not replaced)** long-running FFmpeg-heavy work if it exceeds job limits: keep `Dockerfile.worker` on a container host

## Pre-go-live requirements (must be done first)

- Confirm these secrets are set in Lovable (production/staging):
  - `DATABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `WORKER_TRIGGER_TOKEN`
  - `OWNER_EMAIL`
  - `OPENAI_API_KEY`
  - `ELEVENLABS_API_KEY`
  - `ELEVENLABS_HOST_A_VOICE_ID`
  - `ELEVENLABS_HOST_B_VOICE_ID`
  - `R2_ENDPOINT`
  - `R2_ACCESS_KEY_ID`
  - `R2_SECRET_ACCESS_KEY`
  - `R2_BUCKET`
  - `TRANSISTOR_API_KEY`
  - `TRANSISTOR_SHOW_ID`
  - `TELEGRAM_BOT_TOKEN`
  - `TELEGRAM_CHAT_ID`
  - `PUBLISHING_ENABLED=false`
  - optional: `AZURE_SPEECH_KEY`, `AZURE_SPEECH_REGION`, `OPENAI_MODEL`, `APP_TIMEZONE`, `DAILY_CRON`
- Upload at least one licensed default music track with `rights_confirmed=true`.
- Add at least one active RSS feed in the admin sources list.
- Ensure owner authentication works for only your email.
- Have a valid browser session cookie ready for owner-approval and publish rehearsal.

## 24/7 daily run wiring

1. In Lovable → **Cloud → Jobs**, create:
   - Cron: `06:00`  
   - Timezone: `Asia/Riyadh`
   - Method: `POST`
   - URL: `https://<your-lovable-app>/api/ops/run-daily`
   - Header: `x-worker-token: <WORKER_TRIGGER_TOKEN>`
2. Keep `PUBLISHING_ENABLED=false` as default.
3. Run the job once manually.
4. Confirm in UI:
   - new episode created with status `needs_review`
   - status timeline ends at `needs_review` (not failed)
   - episode contains 5–8 sourced segments and both hosts
   - final mix exists and music track is licensed.

## Controlled publish rehearsal (required before production)

1. In Lovable Secrets, temporarily set `PUBLISHING_ENABLED=true`.
2. Approve one episode manually in admin.
3. Set environment `SESSION_COOKIE` from owner browser in your run shell and run:
   - `./scripts/rehearsal-publish.sh`
4. Verify:
   - Transistor episode creates once
   - Telegram sends once
   - second run is idempotent (no duplicates)
5. Immediately revert `PUBLISHING_ENABLED=false`.

## Worker split (if needed)

- If `collectDaily()` takes too long in Lovable jobs, keep Jobs as trigger only and run `Dockerfile.worker` on your external host:
  - host calls the same shared DB and R2
  - keep the endpoint `/api/ops/run-daily` as trigger bridge if desired.

## Failure recovery

- If job runs fail, check:
  - provider quotas (OpenAI/ElevenLabs/Transistor/Telegram)
  - feed fetch errors (`feeds.last_error`)
  - failed jobs in `episodes.status`
- If stuck, pause jobs in Lovable and replay from latest failed episode with explicit manual review.

## What to do with this file

Keep this file as your go-live acceptance checklist. Pair it with:
- `docs/deployment.md`
- `docs/lovable-replaces-railway-playbook.md`
- `README.md` rehearsal commands.
