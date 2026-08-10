# Najdi MVP Objective Audit

## Requirement: GitHub CI passes
Evidence required:
- `.github/workflows/ci.yml` includes `pnpm typecheck`, `pnpm test`, `pnpm build`.
- A CI run that passes all three steps.

Current evidence:
- Present in repo: `.github/workflows/ci.yml` has all three commands.
- Local execution is blocked by missing Node runtime (`node: not found`), so checks cannot complete here.

Remaining action:
- Run CI-equivalent checks in Node-enabled environment: `pnpm typecheck`, `pnpm test`, `pnpm build`, or run a GitHub Actions run and capture passing logs.

## Requirement: allowlisted RSS run produces one sourced 8–12 minute two-host needs_review episode with licensed looping music
Evidence required:
- one staged run from active feeds only (`feeds.active=true`)
- episode ends in `needs_review`
- 5–8 segments, both `host_a` and `host_b`, each with source URLs
- final mix valid and one licensed `default` music track attached

Current evidence:
- Worker run path checks active feeds and transforms into episode script using `fetchFeed` and open-ended feed allowlist.
- `src/worker.ts` enforces 5..8 segments, both hosts, source URL presence, and 480..720 second draft length.
- `src/lib/audio.ts` mixes with looped background via `-stream_loop -1` and enforces target duration.
- `scripts/run-staging-rehearsal.sh` validates status, segment constraints, source coverage, and licensed music usage before review.

Remaining action:
- Run `pnpm rehearsal:staging:dry` on staging DB with active allowlist and licensed music.

## Requirement: owner approval publishes idempotently to staging Transistor and Telegram
Evidence required:
- one episode approved by owner
- publish called twice yields one final published row per channel and one idempotency key each
- no duplicate public delivery IDs for either channel

Current evidence:
- `/api/episodes/[id]/publish` requires owner auth and approved+valid final mix.
- idempotent keys used: `episode:${id}:transistor` and `episode:${id}:telegram`.
- `scripts/rehearsal-publish.sh` and `scripts/verify-rehearsal.sh` already perform the publish-x2 and invariants check.

Remaining action:
- run `pnpm rehearsal:staging:publish` with valid `SESSION_COOKIE`.
- keep output and run `scripts/verify-rehearsal.sh`.

## Requirement: public auto-publishing remains disabled
Evidence required:
- rehearsal drafting has `PUBLISHING_ENABLED=false`
- publish can only happen intentionally in controlled rehearsal window

Current evidence:
- `src/preflight.ts` hard-fails when `PUBLISHING_ENABLED=true`.
- `staging-preflight.sh` and `run-staging-rehearsal.sh` block when publishing flag is true.
- publish route checks `if (!env.PUBLISHING_ENABLED) throw` to enforce explicit enable.

Remaining action:
- verify this guard by running dry rehearsal with `PUBLISHING_ENABLED=false` and controlled publish rehearsal with immediate re-disable.

## Requirement: typecheck + tests + production build + complete rehearsal evidence
Evidence required:
- local/CI outputs for `pnpm typecheck`, `pnpm test`, `pnpm build`
- one completed markdown report in `docs/rehearsals/` with IDs/checksums/IDs/status/logs

Current evidence:
- `pnpm` tasks are wired in `package.json`; output currently unavailable because Node is missing locally (`node: not found`).
- Rehearsal checklist and templates are in place (`docs/rehearsals/README.md`, `docs/execution-proof-map.md`).

Remaining action:
1. Run locally or in CI: `pnpm typecheck`, `pnpm test`, `pnpm build`.
2. Run `pnpm rehearsal:staging:publish` and export report:
   `OUT_FILE=docs/rehearsals/<date>-run-N.md ./scripts/staging-e2e.sh`
3. Store filled report and keep it as proof of end-to-end rehearsal.
