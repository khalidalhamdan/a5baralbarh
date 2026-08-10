# Lovable connect + deploy playbook

Important: Lovable does not import an existing GitHub repo into an existing project in place.
It syncs code from Lovable to GitHub and then keeps one synced repo/branch.
For this repo, the practical approach is: keep this GitHub repo as source of truth, and
let the Lovable project sync against the branch you want it to run.

Use this exact sequence:

1. In GitHub, keep changes on the branch you want deployed (usually `main`).
2. In your Lovable workspace, open **Project settings → Git → GitHub** and connect
   the workspace to GitHub.
3. Create/confirm the connection target for this branch.
4. In **Project settings → Git → GitHub**, confirm the linked repository and branch.
   - Lovable supports one active synced branch per project.
   - If branch switching is required, switch the branch in Project Git settings first.
5. Push one small local commit from this repo and confirm it appears in the linked Lovable project.
6. In GitHub, confirm sync history exists on the Lovable-linked repository side.
7. In Lovable **Cloud → Jobs**, set one schedule for `06:00 Asia/Riyadh`.
8. Configure the job to hit `POST /api/ops/run-daily` with header `x-worker-token`.
9. Set runtime secrets in **Cloud → Secrets** and keep `PUBLISHING_ENABLED=false` while rehearsing.
10. Add `WORKER_TRIGGER_TOKEN` and all provider keys in Secrets.
11. Trigger the job manually once and confirm:
    - a new episode lands in `needs_review`,
    - the owner approves it in UI,
    - optional: set publish on only for controlled rehearsal.

Important behavior:

- You can confirm jobs and run history in **Cloud → Jobs** (status, last run, run history table).
- If the daily job needs long-running FFmpeg + TTS work, keep orchestration in Lovable and
  run heavy mixing/synthesis in an external container worker.
- `git sync`, `jobs`, and `secrets` are the only moving pieces to link to this repo.

Useful docs (official):

- [Lovable GitHub sync](https://docs.lovable.dev/integrations/github)
- [Lovable Jobs](https://docs.lovable.dev/features/jobs)
- [Lovable Edge functions](https://docs.lovable.dev/features/edge-functions)
- [Lovable Supabase integration](https://docs.lovable.dev/integrations/supabase)
