# Lovable connect + deploy playbook

You can’t import an existing GitHub repository into Lovable directly; Lovable can only export to GitHub and synchronize with it.

Use this exact sequence:

1. In your Lovable workspace, go to **Project settings → Git → GitHub**.
2. Create/confirm a workspace GitHub connection.
3. Connect the project to GitHub and let Lovable create the linked repository.
4. In that same repo, switch to the intended branch (usually `main`) from Lovable’s branch picker.
5. Pull the latest from GitHub and confirm sync in both directions.
6. Push your latest code from local as needed; Lovable should sync back into the project.
7. In Lovable **Cloud → Jobs**, schedule one job at `06:00 Asia/Riyadh` to trigger your daily run endpoint.
8. Store all provider/API secrets in **Cloud → Secrets**.
9. Keep `PUBLISHING_ENABLED=false` while rehearsing.
10. Add `WORKER_TRIGGER_TOKEN` as a secret and configure the job to call `POST /api/ops/run-daily` with header `x-worker-token`.

Important behavior:

- Lovable supports one active synced branch per project at a time.
- If branch editing is needed, switch in Project Git settings before asking Lovable to continue from the same branch.
- A heavy, long-running FFmpeg step may need a dedicated container runtime while job orchestration stays in Lovable.

Useful docs (for details):

- [Lovable GitHub sync](https://docs.lovable.dev/integrations/github)
- [Lovable Jobs](https://docs.lovable.dev/features/jobs)
- [Lovable Edge functions](https://docs.lovable.dev/features/edge-functions)
- [Deploy outside Lovable](https://docs.lovable.dev/tips-tricks/external-deployment-hosting)
