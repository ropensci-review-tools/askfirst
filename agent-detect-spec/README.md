# agent-detect-spec

A vendored, automatically-synced copy of `vercel/detect-agent`'s
language-agnostic AI-agent-caller detection data: which environment
variables, environment values, or filesystem markers identify which AI
coding tool is driving a calling process. `askfirst` (the R package in
this repo) is the first consumer; this directory is kept independent of
the R package's own `R/`, `man/`, `tests/` structure so the vendored data
is unambiguously portable, not R-specific.

## Layout

- **`vendor/agents.json`** and **`vendor/agents.schema.json`** — an
  unmodified copy of `vercel/detect-agent`'s detection-signal
  specification. Consumed as-is, using upstream's own schema — this repo
  does not define a parallel schema for detection signals, since
  duplicating `agents.json` into an `askfirst`-specific shape would just be
  a second thing to keep in sync for no real benefit.
- **`manifest.json`** — versioning and upstream provenance metadata (see
  below).

## Versioning

`manifest.json`'s `version` field (semantic versioning) covers this
directory's own tooling (the sync workflow, the manifest's own structure),
separately from the content of `vendor/agents.json`, whose upstream
provenance is recorded under `manifest.json`'s `vendor_source` key
(`last_synced_commit`, `last_synced_commit_date`, `last_synced_at`). A
`vendor/agents.json` update from the sync workflow does not require
bumping `version` on its own.

## Keeping vendored data current

`.github/workflows/sync-agent-detect-spec.yml` runs weekly (and can be
triggered manually via `workflow_dispatch`). It fetches the current
`agents.json`/`agents.schema.json` from `vercel/detect-agent`, diffs them
against `vendor/`, and — if they differ — opens a pull request updating the
vendored files and `manifest.json`'s `vendor_source` metadata. No
reconciliation logic is needed beyond the diff itself, since `vendor/`
*is* the detection data consumed directly, not an input to a second,
hand-curated file.

When that PR appears: review the diff (what tool entries were added,
removed, or changed), then merge — no other repo changes are required,
since consumers read `vendor/agents.json` directly.
