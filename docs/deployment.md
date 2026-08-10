# Staging deployment: Lovable + Supabase + managed worker

## What Lovable gives you vs Railway

Use this as your default choice if you want one control plane:

- **Replaces Railway for orchestration:** **Lovable Jobs** (daily schedule), plus GitHub sync to deploy UI code.
- **Replaces Railway for short API execution:** **Lovable Edge Functions** (secure callbacks and lightweight ops).
- **Replaces Railway for DB/auth/storage:** **Supabase backend** (via your own Supabase project).
- **Still needs an external runtime:** long-running FFmpeg/TTS audio mixing and any heavy background container work can continue in `Dockerfile.worker` on your chosen host.

If you use Lovable as control plane, keep this repo as the single source of truth and sync it to the Lovable-linked GitHub branch.

Use Lovable for the Arabic admin experience. For daily podcast generation, use one of:

- **Lovable Jobs**: built-in scheduled background tasks (cron-like) for orchestration + a dedicated API route for heavy rendering in the worker runtime.
- **Lovable Edge Functions**: serverless endpoint calls for short tasks; useful for API callbacks and control-plane actions.
- **External worker runtime**: required if you want predictable FFmpeg-heavy rendering from a long-running process.

Lovable is used as the control plane and UI. Worker execution can stay in this repository and run on any container runtime if needed. Both applications share one staging database. Do not expose service-role or provider secrets to browser code.

## 1. Supabase staging project

1. Create a dedicated staging project in a nearby region.
2. Apply `supabase/migrations/0001_initial.sql` with the Supabase SQL editor or CLI.
3. Set the owner email database setting documented in the root README.
4. Configure passwordless authentication for only the owner email.
5. Record the database URL, public project URL, anonymous key, and service-role key in their respective secret managers. Never commit them.

## 2. Lovable admin project

1. Create a new Lovable project for the Arabic RTL control room.
2. Connect that project to the staging Supabase project.
3. Connect the project to GitHub as usual in Lovable and use the synced repository branch from GitHub (`main` unless you are intentionally on another branch).
   - Important: Lovable can export to GitHub and sync that repo; it does not import an existing GitHub repository into an existing project.
4. Recreate the dashboard views against the existing tables and lifecycle values from the migration.
5. Enforce owner authentication and database RLS on every view and action.
6. Keep approval and publish mutations server-side, protected by authentication and same-origin validation.

## 3. Worker orchestration

### 3.1 Use Lovable only for orchestration (recommended)

1. Keep this repository as the worker source (`src/worker.ts`).
2. In Lovable **Cloud → Jobs**, create a daily scheduled job at `06:00 AM` in `Asia/Riyadh` that triggers the protected endpoint `POST /api/ops/run-daily` with header `x-worker-token: <WORKER_TRIGGER_TOKEN>`. The endpoint calls `collectDaily()` in the worker logic. Use endpoint-driven invocation to avoid editing files directly in Lovable for heavy code.
3. Keep `PUBLISHING_ENABLED=false` for staging preflight and draft-only runs.
4. Add all secrets in Lovable **Secrets** only.
5. Run `pnpm preflight` as a one-off command (staging) and resolve any failed check before enabling jobs.
6. Verify each run produces one `needs_review` episode and exits instead of continuously restarting.

### 3.2 If Jobs cannot execute your full audio rendering load

1. Keep job orchestration in Lovable, but move heavy ffmpeg assembly and TTS mixing to an external worker container.
2. Use the same DB and storage keys, and pass only signed job IDs in payloads.
3. Keep this repository as the source of truth and configure the external worker to pull approved jobs and publish back state to the same tables.

### 3.3 External fallback (container)

If you want an exact container runtime now:

1. Keep worker runtime in `Dockerfile.worker`.
2. Add a one-off scheduled runner with your preferred container host (Cloud Run, ECS, Docker host, etc.) and schedule it daily.
3. Keep Lovable for admin UI + job trigger monitoring only.

## 4. Publishing rehearsal

Draft generation is safe with `PUBLISHING_ENABLED=false`. For an explicitly owner-approved staging publish rehearsal, temporarily enable the publishing switch only on the staging worker/API responsible for the approved request, use staging Transistor and Telegram destinations, then restore the switch to false. Record the evidence in `docs/rehearsals/` and retry the publish action to prove that no duplicate delivery is created.

Production destinations and automatic public publishing remain prohibited until the voice gate and all seven supervised rehearsals pass.

### What does Lovable replace from Railway?

- **Cloud**: database/auth/storage/queues/secrets backend.
- **Jobs**: scheduled workflow execution (cron-like).
- **Edge functions**: short serverless operations and callbacks.

What you still need separately (for now):

- A long-running FFmpeg-capable container process if daily audio rendering is too heavy for your expected Lovable job limits.
- A dedicated container/CI host if you choose not to run mixing in Lovable at this stage.
