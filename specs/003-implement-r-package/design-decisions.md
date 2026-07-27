---
created: 2026-07-27T09:35:00Z
agent: claude-sonnet-5
git_hash: 565f3fc188f446727f16a7cf72c7b1c082d16c94
---

# Design Decisions: implement-r-package

## Summary
This stage built the `pkghooks` R package itself at `bindings/r/`, turning stages
001–002's research and design output into working code: session-level
LLM-caller detection, confidence tiering, and all three intervention
points (load-time, error-time, capability-gap-time), backed by 33 passing
`testthat` tests and a clean `R CMD check`.

## New Design Decisions

### Decision 1: Vendor a synced copy of the detection data into bindings/r/inst/
**Chosen:** Root `agent-detect-spec/vendor/` remains the source of truth;
`bindings/r/inst/agent-detect-spec/` holds a committed, byte-identical copy, kept
current by extending the existing `sync-agent-detect-spec.yml` Action (it
now updates both locations in one PR) plus a standalone drift-check script
(`bindings/r/data-raw/check-vendor-sync.R`) wired into CI.
**Rationale:** Makes the R package installable independently of this
monorepo (CRAN, a release tarball, or a checkout of `bindings/r/` alone), which the
detection data being scattered at the repo root would otherwise prevent.
**Tradeoffs:** Two copies of the same data exist; mitigated by automation
(sync Action + CI drift check) rather than manual discipline.
**Relates to:** Directly implements stage 002's vendoring decision; the
R-specific packaging concern (`bindings/r/inst/` vs. repo-root `agent-detect-spec/`)
was this stage's own contribution.

### Decision 2: Global detection cache with explicit per-package attribution
**Chosen:** `pkghooks_init()` computes and caches the session's
confidence/detection result once, shared across every adopting package,
via a package-private state environment. Every hook
(`pkghooks_init()`'s load-time notice, its `on_error` wrapping, and
`flag_capability_gap(pkg, message)`) explicitly takes a `pkg` argument,
attached as a real field on the signalled condition object — not merely
interpolated into message text.
**Rationale:** Avoids redundant re-detection across multiple adopting
packages in one session, while still producing attributable messages
rather than one anonymous notice.
**Tradeoffs:** `flag_capability_gap()`'s signature diverges from stage
001's original sketch, which showed it without a `pkg` argument.

### Decision 3: Three condition classes over a common signaling helper
**Chosen:** `pkghooks_notice` (load-time, non-fatal), `pkghooks_error_redirect`
(error-time, non-fatal, layered onto an existing error), and
`pkghooks_capability_gap` (capability-gap-time, halting) — all built via
one internal helper (`pkghooks_signal()`) that renders `cli`/glue-style
`{}` interpolation before signalling via `rlang::inform()`/`rlang::abort()`,
and always attaches a base `pkghooks_condition` class plus the triggering
`pkg` as a condition field.
**Rationale:** A single helper keeps message formatting and
package-attribution behavior consistent across all three intervention
points, resolving this stage's one open naming question from `plan.md`.
**Tradeoffs:** None significant.

### Decision 4: options(error = ...) instead of globalCallingHandlers()
**Chosen:** Error-time wrapping (`pkghooks_error_redirect`) is installed
via `options(error = ...)`, preserving and chaining to any pre-existing
value, rather than `globalCallingHandlers()` as originally planned in
`plan.md`.
**Rationale:** Discovered during implementation, via an actual
`R CMD INSTALL` failure: `globalCallingHandlers()` cannot be called from
within `.onLoad()`/`.onAttach()`, because R's own `loadNamespace()`/
`attachNamespace()` wrap those hooks in a handler context of their own,
and `globalCallingHandlers()` refuses to install from inside any active
handler context. `options(error = ...)` has no such restriction. Both
mechanisms share the same underlying limitation — they only fire for
errors that propagate uncaught to the top level, not errors an
intervening `tryCatch()`/test runner/agent-tool wrapper catches first —
so switching mechanisms did not narrow coverage.
**Tradeoffs:** None beyond the shared, already-accepted (stage 001,
Decision 4) top-level-only delivery limitation.

## Integration with Prior Work
This stage consumed stage 002's `design.md` (T002-4/T002-5) directly for
the confidence-tiering and intervention-point specification, since that
content was folded back into stage 002's own documents rather than living
in `agent-detect-spec/`. It also consumed `agent-detect-spec/vendor/agents.json`
as the detection-data source, exactly as stage 002 designed it.

## Issues Resolved
- Stage 001's open testing-strategy question: resolved via `testthat` +
  `withr`-based environment/TTY mocking for deterministic unit tests, with
  a `MANUAL_TESTING.md` checklist (one item per vendored tool) for what
  automated mocking cannot verify — real agent-tool harnesses actually
  surfacing the signalled conditions.
- `plan.md`'s one remaining open question (condition-class naming):
  resolved as `pkghooks_condition` base with `pkghooks_notice`/
  `pkghooks_error_redirect`/`pkghooks_capability_gap` subclasses.
- Whether `globalCallingHandlers()` is viable for session-wide error
  wrapping from a package's own load hook: resolved no, empirically.

## Deferred Items
- `ps`-based process-ancestry corroboration (unimplemented, documented
  extension point).
- The `cooperative` confidence tier's actual detection logic (enum value
  exists; no code path produces it).
- `btw` cooperative-signal integration.
- A registry-style (vs. inline) capability-gap declaration mechanism.

## Process Notes
- `pkghooks_detect_confidence()` was refactored mid-implementation to
  accept its `no_tty` determination as an optional parameter (alongside
  the existing `tool` parameter), so all three confidence tiers could be
  tested deterministically without mocking `isatty()` — a test-driven
  implementation improvement, not a behavior change.
- `pkghooks_error_handler()` similarly accepts an injectable
  `originates_from` function, letting tests exercise its registry-lookup
  logic without depending on real call-stack shape (which proved fragile
  to construct artificially in ad hoc test harnesses, though the real
  stack-walking mechanism itself was independently verified via a genuine
  end-to-end uncaught-error test during implementation).
