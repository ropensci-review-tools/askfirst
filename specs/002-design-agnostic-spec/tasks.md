---
created: 2026-07-27T00:30:00Z
agent: claude-sonnet-5
git_hash: 1a1ff2f4add4a5cc42d2135717b912fb6ed5b24c
---

# Tasks: design-agnostic-spec

Scope was reduced mid-stage: rather than designing an independent
detection-signal schema mirroring `vercel/detect-agent`'s `agents.json`,
this stage vendors that file as-is and adds only what it doesn't already
provide — a confidence-tiering model and an intervention-point model.
This removes the standalone schema/data tasks from the original task list
in favor of a simpler vendor-and-layer approach.

## T002-1: Vendor upstream agents.json
- [x] T002-1: Fetch the current
  https://raw.githubusercontent.com/vercel/detect-agent/main/agents.json
  and save it verbatim, unmodified, as
  `agent-detect-spec/vendor/agents.json`. This file is consumed directly
  using upstream's own schema — no `pkghooks`-specific reformatting or
  parallel schema is created.

## T002-2: Write the spec manifest
- [x] T002-2: Write `agent-detect-spec/manifest.json` with: `name`
  (`agent-detect-spec`), `version` (`0.1.0`, semantic versioning, covering
  this stage's own contribution — the confidence model, intervention
  model, and sync tooling, not the vendored file's content), and
  `vendor_source` (an object recording the upstream URL used for T002-1
  and the date/commit it was fetched at, so later syncs can tell what
  changed).

## T002-3: Build the upstream sync GitHub Action
- [x] T002-3: Write `.github/workflows/sync-agent-detect-spec.yml`: a
  workflow triggered on both a weekly `schedule` (cron) and manual
  `workflow_dispatch`. Steps: fetch the current upstream `agents.json`;
  diff it against `agent-detect-spec/vendor/agents.json`; if they differ,
  commit the updated file to a new branch, update `manifest.json`'s
  `vendor_source` date/commit, and open a pull request with a body
  listing which tool entries changed. If no diff, the workflow is a
  no-op. No reconciliation logic beyond the diff is needed, since
  `vendor/agents.json` is consumed directly rather than feeding a second,
  hand-curated file.

## T002-4: Document the abstract confidence-tiering model
- [x] T002-4: Write `agent-detect-spec/confidence-model.md` describing a
  closed `high` / `medium` / `low` / `cooperative` enum as language-neutral
  mapping rules applied on top of a raw lookup against
  `vendor/agents.json`: `high` = the current environment matches any entry
  in the vendored data (regardless of corroboration); `medium` = no entry
  matched, but a corroborating signal (no-TTY, process-ancestry match) is
  present, i.e. ambiguous non-interactive automation that may or may not
  be agent-driven; `low` = no signals present at all (default
  human/interactive assumption); `cooperative` = reserved for a future
  signal where the calling tool explicitly announces itself (e.g. a
  hypothetical `btw` MCP-server marker per stage 001 T001-4) — currently
  unused by any lookup path, included now purely so adding one later is
  additive, not a breaking change to the enum.

## T002-5: Document the abstract intervention-point model
- [x] T002-5: Write `agent-detect-spec/intervention-model.md` describing
  three named, independent intervention points as language-neutral
  concepts (no R, no code): `load_time` (trigger: package/module
  attach-or-import; cardinality: once per session; default severity:
  `notice`), `error_time` (trigger: an error/exception the calling code
  already raises; cardinality: re-triggerable, once per error; default
  severity: `notice`, layered onto the existing error), and
  `capability_gap_time` (trigger: an explicit author-instrumented
  call-site marking a known limitation was hit; cardinality:
  re-triggerable; default severity: `halt`-capable, i.e. may be delivered
  as a hard stop, per stage 001 Decision 4). Explicitly document
  `first_call`, `every_call`, and `help_access` as rejected points,
  restating stage 001's reasoning (overhead/noise for the first two, no
  hookable extension point in R for the third — noting this last reason
  is R-specific and future language implementations should re-evaluate it
  for their own ecosystem) rather than re-deriving it.

## T002-6: Write the spec directory's README
- [x] T002-6: Write `agent-detect-spec/README.md` explaining: the
  directory's purpose (a language-agnostic confidence + messaging
  contract layered on top of vendored, unmodified upstream detection data,
  R being only its first consumer); the file layout (`manifest.json`,
  `vendor/agents.json`, `confidence-model.md`, `intervention-model.md`);
  the versioning policy (bump `manifest.json`'s `version` on any
  confidence-model or intervention-model change downstream consumers must
  notice, independent of `vendor/agents.json`'s own upstream churn); and
  how the sync workflow (T002-3) works and what to do when it opens a PR
  (review the upstream diff, merge to update `vendor/agents.json`).

## T002-7: Synthesize this stage's design document
- [x] T002-7: Write `specs/002-design-agnostic-spec/design.md`, structured
  1:1 with tasks T002-1 through T002-6 (mirroring stage 001's `design.md`
  convention), summarizing what was actually built in each file, noting
  the mid-stage scope reduction (dropping an independent detection schema
  in favor of vendoring `agents.json` as-is) and why, and confirming the
  confidence-tier enum is closed for v1, ready for
  `/designlens.retrospective` to consume.
