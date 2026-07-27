---
created: 2026-07-27T00:00:00Z
agent: claude-sonnet-5
git_hash: 1a1ff2f4add4a5cc42d2135717b912fb6ed5b24c
---

# Plan: design-agnostic-spec

## Overview
Design a language-agnostic detection and messaging specification for
`pkghooks`, scoped narrowly to avoid duplicating work `vercel/detect-agent`
already does well. The detection-*signal* data (which env vars/process
facts identify which AI coding tool) is **not** re-designed or
re-schema'd here — it is vendored as-is from `vercel/detect-agent`'s
`agents.json` and kept in sync via an automated GitHub Action. This
stage's actual design contribution is the layer `agents.json` does not
provide: an abstract, language-neutral confidence-tiering model (mapping
a raw signal match, or lack of one, onto a tier `pkghooks` and future
non-R implementations can act on) and an abstract intervention-point model
(load-time / error-time / capability-gap-time messaging semantics). Both
live alongside the vendored data under `agent-detect-spec/` as a versioned
contract, ahead of a follow-up R-specific implementation stage that
consumes it.

## Context
This is the project's second design stage, following `001-detect-llm-callers`
(pure research, no artifact produced — see
`specs/001-detect-llm-callers/design.md` and its `design-decisions.md`).
Relevant decisions and open questions carried forward:

- **Env-var table as primary signal, TTY/ancestry as corroboration only**
  (Decision 1, stage 001): a maintained table of per-tool env-var markers
  (`CLAUDECODE`, `CURSOR_AGENT`, `GEMINI_CLI`, etc.), evaluated first-match-wins,
  is the primary, high-precision signal. TTY attachment and parent-process
  ancestry (via R's `ps` package, but the underlying *check* — no TTY,
  process-ancestry match — is itself language-agnostic) are corroborating
  only, never standalone, since they false-positive on ordinary
  non-interactive human automation (CI, scripted runs).
- **Call-stack introspection rejected; `btw` cooperation deferred**
  (Decision 2): not part of this spec. `btw`-style cooperative signals
  remain a deferred, not-yet-built concept.
- **Three independent message intervention points** (Decision 3): load-time,
  error-time, and capability-gap-time, each independent; first-call and
  every-call explicitly ruled out (overhead + message-fatigue reasoning in
  `design.md` T001-7), help/documentation-access noted but not pursued.
- **Layered message-delivery mechanism** (Decision 4): a custom condition
  class as the primary non-fatal channel, with an actual halting error
  reserved for capability-gap/error-time — but this decision describes an
  *R-specific* mechanism (R's condition system). This stage must extract
  and specify only the language-neutral concepts behind it (trigger,
  severity, cardinality), not the R mechanism itself.
- **R-only package, portable detection data** (Decision 5 / T001-9): direct
  prior art exists outside R for the detection-signal layer
  (`vercel/detect-agent`'s `agents.json`, consumed by Go/JS/TS
  implementations and referenced by `unjs/std-env`). Revisiting this
  stage's own initial approach: rather than modeling *our own* schema on
  `agents.json` (which would just duplicate it under a different shape),
  this stage now consumes `agents.json` directly, unmodified, as the
  detection-data source of truth. Duplicating it into a bespoke schema was
  identified (mid-stage) as redundant busywork with no real benefit over
  vendoring the upstream file as-is.
- **Comparable-repo precedent**: `askahuman` (a separate, unrelated product —
  a phone-approval relay for agent loops — reviewed only for architectural
  precedent, not for its detection logic, which it doesn't have) documents
  in `docs/decisions/architecture/0001_split_repos.md` a decision to split
  into independently-shippable units only once genuinely independent
  consumers exist, and to keep cross-cutting contracts in sync "by tests,
  not a shared module." That precedent directly informs this stage's
  decision to keep the spec inside the `pkghooks` repo for now (R is the
  only consumer today) rather than standing up a separate repo pre-emptively.
- **Process note**: this stage produces a concrete artifact (vendored data
  + two model documents + a manifest + a sync workflow), not a research
  document only — `tasks.md` reflects that the deliverable is actual files
  under `agent-detect-spec/`, not solely prose.

## Design Goals
- Vendor `vercel/detect-agent`'s `agents.json` verbatim into
  `agent-detect-spec/vendor/agents.json`, consumed as-is — no independent
  schema, no reformatting into a `pkghooks`-specific shape. This directly
  resolves stage 001's open question 1 (schema/sync strategy) by avoiding
  the need for one: there is no second schema to keep in sync, only a
  file to keep current.
- Build a real, working GitHub Action on a cron schedule that fetches the
  latest upstream `agents.json`, diffs it against the vendored copy, and
  opens a pull request when it changes — since the vendored file *is* the
  detection data (not an input to a hand-curated second file), the sync
  action is a straight passthrough-and-review, not a reconciliation step
  between two divergent shapes.
- Define an abstract, language-neutral confidence-tiering model — the
  layer `agents.json` itself has no concept of — that maps a raw
  detection outcome (a matching entry in the vendored data, or the
  absence of one, plus optional TTY/ancestry corroboration) onto a tier:
  a closed enum of `high` / `medium` / `low` / `cooperative` (the last
  reserved, currently unused, for a future cooperative signal such as a
  `btw`-style marker per stage 001 T001-4). This resolves stage 001's open
  question 6 and this stage's own confidence-enum question (closed vs.
  open) in favor of closed-for-now, since it is additive to extend later.
- Define an abstract, language-neutral intervention-point model covering
  the three points validated in stage 001 (load-time / error-time /
  capability-gap-time) as named concepts, each specifying: trigger
  semantics, default message severity (notice / halt), cardinality
  (once-per-session vs. re-triggerable), and independence from the other
  two points — without committing to any language's native delivery
  mechanism (R conditions, Python exceptions, JS throws, etc.). Explicitly
  exclude first-call, every-call, and help/documentation-access as
  intervention points, carrying stage 001's rejection reasoning forward
  rather than re-litigating it.
- House the spec at `agent-detect-spec/` at the repo's top level, with a
  semver manifest file (`agent-detect-spec/manifest.json`) versioning
  *this stage's own contribution* (the confidence model + intervention
  model + sync tooling), separately from the vendored file's own upstream
  provenance (recorded as metadata, not a version this repo owns).
- Explicitly out of scope for this stage: any R-specific integration
  mechanics (`.onLoad()`/`.onAttach()` wiring, R condition-class naming,
  the shape of `pkghooks_init()`/`flag_capability_gap()`) — these belong to
  the next, R-specific implementation stage, which consumes this spec
  rather than re-deriving it.

## Proposed Approach
- Treat this stage as research-and-design that produces a concrete
  artifact — distinct from stage 001, which was research-only with no
  files beyond its design document. The deliverable is a spec directory
  containing vendored data, two model documents, a manifest, and a sync
  workflow.
- Location: a top-level `agent-detect-spec/` directory in the `pkghooks`
  repo, kept independent of the R package's own `R/`, `man/`, `tests/`
  structure so it reads unambiguously as "the portable contract," not
  "part of the R package's internals." Following `askahuman`'s
  `0001_split_repos.md` precedent, this stays inside the `pkghooks` repo
  rather than becoming its own repo now, since R remains the only
  consumer; extraction to a standalone repo is deferred until a second,
  genuinely independent language implementation exists.
- Contents to produce:
  - `agent-detect-spec/vendor/agents.json` — an unmodified copy of
    upstream's current `agents.json`. This *is* the detection-signal data;
    consumers read it directly using upstream's own schema (documented in
    the `vercel/detect-agent` repo, not re-documented here).
  - A GitHub Action (`.github/workflows/sync-agent-detect-spec.yml`),
    cron-triggered plus manually dispatchable, that fetches upstream
    `agents.json`, diffs it against the vendored copy, and opens a PR with
    the updated file when they differ. No reconciliation logic is needed
    beyond the diff itself, since there is no second, hand-curated file to
    keep in step with it.
  - `agent-detect-spec/confidence-model.md` — the mapping rules from "a
    vendored-data match / no match, plus optional TTY or process-ancestry
    corroboration" onto the `high`/`medium`/`low`/`cooperative` enum. This
    is the layer that actually adds confidence semantics on top of
    `agents.json`, which carries none itself.
  - `agent-detect-spec/intervention-model.md` — the three-point abstract
    messaging model (load/error/capability-gap-time), entirely independent
    of the detection layer.
  - `agent-detect-spec/manifest.json` — a semantic `version` for this
    stage's own contribution (confidence model + intervention model +
    sync tooling), plus a `vendor_source` field recording the upstream URL
    and last-synced date/commit of `vendor/agents.json`.
  - `agent-detect-spec/README.md` — the directory's entry point,
    explaining layout, versioning policy, and how the sync workflow and PR
    review process work.
- No JSON-Schema validator or fixture-based test suite for *downstream
  consumers* is built in this stage — deferred until an actual second
  consumer needs one. The sync Action's own diff/fetch logic is part of
  the sync deliverable, not a consumer-facing validator.
- Message-*delivery* mechanism specifics (R conditions vs. exceptions vs.
  something else) remain out of this stage entirely; only the abstract
  trigger/severity/cardinality concept per intervention point is specified,
  leaving the concrete R mapping to the next stage.

## Open Questions
None outstanding. The two questions this stage started with — closed vs.
open confidence-tier enum, and flat vs. namespaced detection-data shape —
are both resolved: the confidence enum is closed (`high`/`medium`/`low`/
`cooperative`) per Design Goals above, and the data-shape question is now
moot, since this stage vendors `agents.json` in whatever shape upstream
defines rather than inventing a parallel one.
