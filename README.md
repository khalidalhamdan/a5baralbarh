# سوالف اليوم — Najdi AI News Podcast

Arabic-first control room and production pipeline for a daily, owner-approved Saudi news podcast.

## Safety model

- Publishing is off by default (`PUBLISHING_ENABLED=false`).
- Only `OWNER_EMAIL` can access the configured Supabase application.
- An episode must be in `approved` state and have a valid final mix before publishing.
- Telegram runs only after Transistor returns a public episode URL.
- Every delivery has a stable idempotency key.

## Local setup

1. Install Node 22, pnpm, Docker, and FFmpeg.
2. Copy `.env.example` to `.env` and add development credentials.
3. Create a Supabase project and apply `supabase/migrations/0001_initial.sql`.
4. Set the Postgres custom setting used by RLS: `alter database postgres set app.owner_email = 'your@email';`.
5. Run `pnpm install`, then `pnpm dev`.
6. Visit `http://localhost:3000`. Without Supabase public variables, the UI runs in local preview mode; production must configure authentication.

## Production topology

- Deploy the Next.js standalone image to Vercel or another Node host.
- Deploy the same repository as a Railway worker with `pnpm worker` and FFmpeg available.
- Schedule the worker daily at `06:00 Asia/Riyadh`; do not run it as a permanently restarting one-shot process.
- Keep private audio in R2. Store only object keys or short-lived signed URLs in the database.
- Configure Supabase backups and point-in-time recovery before launch.

## Voice acceptance gate

Before generating production episodes, assign distinct Saudi Arabic voice IDs and audition dates, numbers, English names, Saudi locations, formal news, and dialogue. Do not enable publishing until a Saudi listener approves both voices as natural and appropriate.

## Launch checklist

- Add and test RSS feeds from the allowlist.
- Upload only music with documented commercial podcast rights.
- Configure OpenAI, ElevenLabs, R2, Transistor, and Telegram secrets.
- Verify owner-only passwordless login and database RLS.
- Generate, review, and publish only to staging destinations.
- Complete seven consecutive supervised drafts.
- Back up the database and successfully test restoration.
- Switch `PUBLISHING_ENABLED=true` only after the checklist passes.

## Current implementation boundary

The repository includes the production schema, dashboard, ingestion, structured AI script generation, segmented ElevenLabs adapter, FFmpeg mix graph, approval endpoint, and idempotent Transistor/Telegram publishing. The worker currently stops at `synthesizing`; storage-backed segment orchestration and the music editor must be connected to real credentials and licensed media before the first end-to-end rehearsal.
