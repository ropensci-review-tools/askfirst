---
created: 2026-07-27T11:00:00Z
agent: claude-sonnet-5
git_hash: 8c5581344b39993671a30d0242b18083a81cda61
---

# Plan: implement-r-package

## Overview
Build the `pkghooks` R package itself, as a proper R package rooted at
`bindings/r/` in this monorepo (not at the repo root), so the repo can host
`agent-detect-spec/`, `specs/`, and future non-R implementations as
siblings of the R package rather than entangled with it. This stage turns
stages 001–002's design output into real code: session-level LLM-caller
detection (consuming a vendored copy of `agent-detect-spec/vendor/agents.json`),
the confidence-tiering mapping, and all three intervention points
(load-time, error-time, capability-gap-time) from stage 002's
`design.md`/`design-decisions.md`.

## Context
This is the project's third design stage. Stage 001
(`specs/001-detect-llm-callers/`) was research-only: it surveyed detection
signals, evaluated message-delivery mechanisms, and sketched (T001-11) an
API shape (`pkghooks_init()`, `flag_capability_gap()`) without writing
code. Stage 002 (`specs/002-design-agnostic-spec/`) produced
`agent-detect-spec/`, a vendored, upstream-synced copy of
`vercel/detect-agent`'s `agents.json`, and — after two mid-stream scope
reductions — folded the confidence-tiering and intervention-point design
(originally drafted as standalone files) back into stage 002's own
`design.md` (T002-4/T002-5) and `design-decisions.md`, since that
reasoning was unenforced prose with no code consumer. This stage must
therefore consult `specs/002-design-agnostic-spec/design.md` directly for
the confidence/intervention specification, not a file under
`agent-detect-spec/`.

Relevant decisions carried forward:
- **Detection**: a maintained per-tool env-var table (now
  `agent-detect-spec/vendor/agents.json`), evaluated first-match-wins, is
  the primary signal. TTY attachment is a corroborating signal only, never
  standalone. Process-ancestry (via the `ps` package) and `btw` cooperative
  signals were explicitly left as optional/deferred extension points, not
  v1 requirements (stage 001, T001-5).
- **Confidence**: a closed `high`/`medium`/`low`/`cooperative` enum
  (stage 002, T002-4), with `cooperative` reserved and currently
  unimplementable (no known tool exposes such a marker).
- **Intervention points**: `load_time` (once per session, `notice`
  severity), `error_time` (re-triggerable, layered onto existing errors,
  `notice` severity), and `capability_gap_time` (re-triggerable,
  `halt`-capable, requires author instrumentation) — three independent
  points (stage 002, T002-5). `first_call`, `every_call`, and
  `help_access` were explicitly rejected.
- **API sketch** (stage 001, T001-11): a single `pkghooks_init()` call in
  an adopting package's `.onLoad()` (handles detection + load-time notice
  + optional error-time wrapping via `on_error = TRUE`), plus an exported
  `flag_capability_gap()` helper for capability-gap-time. Detection is
  computed once per R session and shared across every adopting package,
  not re-derived per package.
- **Message delivery** (stage 001, Decision 4): a custom, self-describing
  condition class as the primary non-fatal channel, with an actual
  halting error reserved for capability-gap/error-time interventions.
- **Open question resolved this stage** (stage 001's open question 7):
  testing strategy for environment-dependent detection code — see Design
  Goals below.

## Design Goals
- Scaffold a standard R package named `pkghooks` at `bindings/r/` (`DESCRIPTION`,
  `NAMESPACE` via `roxygen2`, `R/`, `man/`, `tests/testthat/`, `inst/`),
  independent of the repo root so future non-R implementations can be
  added as siblings without restructuring this one.
- Vendor `agent-detect-spec/vendor/agents.json` and `agents.schema.json`
  into `bindings/r/inst/agent-detect-spec/` as byte-identical copies, so the R
  package is self-contained and installable independently of this
  monorepo (e.g. from CRAN or a release tarball, or from a checkout of
  `bindings/r/` alone). Root `agent-detect-spec/vendor/` remains the single source
  of truth; a script/CI check keeps the two copies identical, and the
  existing `sync-agent-detect-spec.yml` Action is extended (or paired with
  a second step) to update both locations together rather than letting
  them silently diverge.
- Implement detection logic that reads the vendored `agents.json` and
  evaluates its match tree (`env_set`/`env_value`/`env_matches`/
  `file_exists`/`no_tty` leaves, `anyOf`/`allOf` combinators, first-array-
  entry-wins) against `Sys.getenv()`/`file.exists()`/`isatty()`.
- Implement the confidence-tiering mapping from stage 002's T002-4 exactly
  as specified: `high` on any vendored-data match; `medium` on no match
  but no TTY attached to stdin/stdout; `low` otherwise. `cooperative` and
  `ps`-based process-ancestry corroboration remain documented-but-
  unimplemented extension points in this stage, per stages 001–002's
  explicit deferrals — not built now.
- Implement `pkghooks_init(pkg, notice, on_error = TRUE)`: the
  LLM-detection/confidence result itself is computed **once per R
  session, globally**, and shared across every adopting package (never
  re-derived per package) — but every hook this stage builds
  (`pkghooks_init()`'s load-time notice, its `on_error` wrapping, and
  `flag_capability_gap()`) must explicitly name the specific adopting
  package that triggered it, so a session with multiple `pkghooks`-adopting
  packages produces attributable messages ("package X says: ...") rather
  than a single anonymous notice. This means an internal, package-private
  registry keyed by `pkg` name (storing each package's `notice` text and
  `on_error` setting) sits alongside the one global detection/confidence
  result.
- Implement `flag_capability_gap(pkg, message)`: an exported helper an
  adopting package's own code calls inline at known-limitation branches,
  **explicitly passing its own package name** (a deliberate revision from
  stage 001's T001-11 sketch, which showed it without a `pkg` argument) so
  the emitted condition is attributable to a specific package even when
  several packages have adopted `pkghooks` in the same session. A no-op
  for human/low-confidence sessions; emits a halt-capable redirect
  condition for LLM-driven sessions, per T002-5's `capability_gap_time`
  semantics.
- Define and document the concrete R condition-class hierarchy (e.g.
  `pkghooks_notice`, `pkghooks_capability_gap`) mapping onto T002-5's
  abstract severities: `notice` → a non-fatal signalled condition;
  `halt`-capable → an actual `stop()`/`rlang::abort()`. Every condition
  object carries the triggering package's name as a field (not just in
  the rendered message text), so calling code can programmatically
  distinguish which adopting package raised it.
- Message text in every hook (`pkghooks_init()`'s `notice`,
  `flag_capability_gap()`'s `message`, and any default wording `pkghooks`
  itself supplies) uses `cli`/`glue`-style interpolation syntax (`{pkg}`,
  `{...}`), matching standard modern R package conventions (`cli::cli_abort()`
  and friends), rather than plain-text-only strings or manual `paste0()`.
- Automated tests: `testthat`, using environment-variable/TTY mocking
  (e.g. `withr::with_envvar()`) to deterministically exercise each
  confidence tier and intervention point in CI. Supplement with a
  `MANUAL_TESTING.md` checklist covering verification against each real
  agent tool listed in the vendored data, for whatever automated mocking
  can't fully replicate — resolving stage 001's open question 7.
- Standard package hygiene: `roxygen2`-generated documentation, a clean
  `R CMD check`, and a CI workflow running `R CMD check` plus the
  `testthat` suite.
- Explicitly out of scope for this stage: `ps`-based process-ancestry
  detection, the `cooperative` confidence tier's actual implementation,
  and `btw` cooperative-signal integration — all remain documented
  extension points, not v1 requirements, per stages 001–002.

## Proposed Approach
- **Location**: all package files live under `bindings/r/` (e.g. `bindings/r/DESCRIPTION`,
  `bindings/r/R/`, `bindings/r/man/`, `bindings/r/tests/testthat/`, `bindings/r/inst/`) rather than at the
  repo root, so `agent-detect-spec/` and `specs/` remain siblings rather
  than nested inside the R package.
- **Vendoring**: a small script (e.g. `bindings/r/data-raw/sync-vendor.R` or a
  Makefile target) copies the root `agent-detect-spec/vendor/` files into
  `bindings/r/inst/agent-detect-spec/`. The existing
  `.github/workflows/sync-agent-detect-spec.yml` is extended directly
  (not replaced or paired with a second Action) so the same PR that
  updates the root vendored copy also updates `bindings/r/inst/agent-detect-spec/`
  in one commit, keeping the two locations from silently diverging.
- **Detection**: an internal (non-exported) R function parses
  `bindings/r/inst/agent-detect-spec/agents.json` via `jsonlite`, walks the
  `match` condition tree per entry, and returns the first matching tool
  (or none) — mirroring `vercel/detect-agent`'s own "first-match-wins"
  evaluation semantics exactly, since the vendored data assumes that
  evaluation order.
- **Confidence**: an internal function combines the detection result with
  `isatty(stdin())`/`isatty(stdout())` per T002-4's ordered rules,
  computed once per session and cached in an internal state object (e.g.
  an environment private to the package's namespace), so multiple
  adopting packages calling `pkghooks_init()` in the same session share
  one detection result rather than each re-deriving it. That same internal
  state object also holds a per-package registry (keyed by `pkg`) recording
  each adopting package's `notice` text and `on_error` setting, so the one
  global detection result can still produce package-attributable messages.
- **Messaging**: a small internal condition-signaling helper builds
  `pkghooks`-prefixed condition classes — each carrying the triggering
  `pkg` name as a condition field, not just interpolated into the message
  text — and signals them via `rlang::abort()`/`rlang::cnd_signal()` (or
  base `signalCondition()` where non-fatal signalling is sufficient).
  Message text is built with `cli`/`glue`-style interpolation (e.g. via
  `cli::cli_abort()`/`cli::cli_inform()`, which natively support `{pkg}`-
  style interpolation and condition metadata). `pkghooks_init()` calls it
  non-fatally at load time; `flag_capability_gap()` and the `on_error`
  wrapper call it at their respective points, with capability-gap-time
  using an actual halting call per stage 002's severity mapping.
- **`on_error` wrapping**: implemented as an opt-in helper the adopting
  package's own `.onLoad()` requests via `pkghooks_init(..., on_error =
  TRUE)`, rather than global condition-handler injection, so it only
  layers the redirect message onto the adopting package's own errors
  without altering unrelated error handling elsewhere in the session.
- **Testing**: `testthat` tests use `withr::with_envvar()` to simulate
  each vendored tool's env-var signature (expect `high`), simulate no
  signal plus no TTY (expect `medium`), and simulate a plain interactive
  human session (expect `low`); condition emission is asserted via
  `testthat`'s condition-expectation helpers. `MANUAL_TESTING.md`
  documents a checklist for verifying against real agent tools, which
  automated mocking can approximate but not fully replace.
- **Deferred, not built**: `ps`-based process-ancestry corroboration, the
  `cooperative` tier's actual detection logic, and `btw` integration —
  all remain as documented extension points inherited from stages
  001–002, left for a future stage if a concrete need arises.

## Open Questions
- Exact condition-class name hierarchy (e.g. `pkghooks_notice` /
  `pkghooks_capability_gap` vs. alternative names) — to be finalized
  during implementation; does not block this plan.
