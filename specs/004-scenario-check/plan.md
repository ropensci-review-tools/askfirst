---
created: 2026-07-27T09:41:18Z
agent: claude-sonnet-5
git_hash: 9a8d6eed1fa7d307db318399a24f34f7c20aadd1
---

# Plan: scenario-check

## Overview
Add a new, independent messaging mechanism for LLM/AI-agent callers who
might be extending or duplicating a `pkghooks`-adopting package's
functionality externally (writing new code in their own project to
achieve a result), rather than asking whether that capability should be
added to the package itself. This complements — and leaves entirely
unchanged — the existing author-driven `flag_capability_gap()`. Unlike
`flag_capability_gap()`, this mechanism does not depend on the author
having pre-instrumented a specific known-gap call site, and unlike
`error_time`, it must work in cases where nothing ever errors (the
extension code the LLM writes typically runs outside the package
entirely, so the package has no execution-time visibility into it at
all). The mechanism has two parts: a strengthened load-time notice
carrying an author-supplied list of "plausible extension scenarios," and
a new, actively-queryable exported function the LLM can call at any point
in a session to check whether its current task matches a known scenario
— giving it a concrete tool to consult before writing a workaround,
rather than relying solely on remembering a notice from session start.

## Context
This is the project's fourth design stage, extending the `pkghooks` R
package built in stage 003 (`bindings/r/`). Relevant prior decisions:

- **Stage 001, T001-8**: capability-gap detection (a case where a call
  "succeeds" but doesn't meet the actual need, with nothing erroring)
  requires author opt-in; no mechanical/heuristic alternative was found
  that avoided false positives or reimplementing domain knowledge only
  the author has. This stage does not contradict that finding — inline,
  author-instrumented markers (`flag_capability_gap()`) remain the only
  way to flag a *specific, already-recognized* gap at its exact call
  site. This stage instead targets a different, broader case: gaps the
  author *hasn't* anticipated well enough to instrument inline, where the
  LLM itself is the one in a position to notice "what I'm about to write
  duplicates or extends this package."
- **This session's own investigation**: mechanical detection of
  in-progress workaround behavior (e.g. `assignInNamespace()`, `trace()`,
  namespace/environment monkey-patching targeting the adopting package)
  was considered and rejected — such calls are rare in practice, and in
  any case the code an LLM writes to "extend" a package's functionality
  typically lives entirely in the calling project, never touching the
  package's own namespace or triggering any observable R-level event
  `pkghooks` could hook into. There is no reliable execution-time trigger
  for this scenario, mechanical or otherwise.
- **Stage 002's abstract intervention-point model**
  (`specs/002-design-agnostic-spec/design.md`, T002-5) defines three
  points, all *system-triggered* (load-time, error-time, capability-gap-time
  — each fires because `pkghooks`'s own code decides to fire it). This
  stage introduces a conceptually different, fourth kind of point:
  *agent-invoked* — it fires only because the calling LLM chooses to call
  it, not because `pkghooks` detected anything. Whether to formally add
  this to stage 002's language-neutral model, or treat it as an
  R-specific experiment for now, is an open question below.
- **Stage 003's implementation**: `pkghooks_init(pkg, notice, on_error)`
  computes and caches session confidence once globally, keeps a
  per-package registry, and delivers messages via `pkghooks_signal()`
  (cli/glue-style interpolation, condition classes rooted at
  `pkghooks_condition`, each carrying `pkg` as a real field). This stage
  extends that same registry and signaling helper rather than building
  parallel infrastructure.
- **Decisions reached this session** (in conversation, before this plan):
  the new mechanism is fully independent of `flag_capability_gap()`
  (neither replaces nor modifies it); delivery is a strengthened load-time
  notice plus an on-demand query function (not load-time alone, and not a
  repeated/every-call notice); severity is non-fatal (a nudge, not a
  halting condition), since heuristic/self-assessed triggers carry more
  false-positive risk than an author-confirmed gap.

## Design Goals
- Extend `pkghooks_init()` with a new `scenarios` parameter (a character
  vector of author-supplied, free-text descriptions of situations where
  an LLM writing new/duplicate code likely means a capability belongs in
  the package instead), stored in the existing per-package registry
  (`.pkghooks_state$packages[[pkg]]$scenarios`).
- Fold the registered scenario list into the existing load-time notice
  automatically when non-empty, so it's visible from the start of the
  session alongside the author's own `notice` text — extending the
  existing `load_time` point's content, not adding a new one for this
  part.
- Add a new exported function (working name `pkghooks_check_scenarios(pkg)`)
  the LLM can call at any point in a session to retrieve/re-display `pkg`'s
  registered scenario list plus a reminder to ask the human before
  implementing a custom workaround. This is the mechanism's actual novel
  contribution: an *agent-invoked* intervention point, fired by the LLM's
  own choice to consult it rather than by `pkghooks` detecting anything.
- Bake a generic instruction into every load-time notice (not
  author-specific, not conditional on whether the author supplied
  scenarios) telling the LLM: if you notice yourself about to write code
  that duplicates, wraps, or extends `{pkg}`'s functionality to achieve a
  result, call `pkghooks_check_scenarios("{pkg}")` first, or ask your user
  whether the capability belongs in `{pkg}` itself — making the on-demand
  tool discoverable from the very first message the LLM receives, so it
  can be recalled later in a long session even after the initial notice
  has scrolled out of context.
- Confidence-gate the new function consistently with existing hooks:
  full scenario-list-plus-ask-the-human framing at `"high"`/`"medium"`
  confidence; a plain, un-nudged response at `"low"` confidence (a human
  deliberately calling this function should just see the list, not be
  told to "ask the human" — they *are* the human).
- Deliver via a new non-fatal condition class, `pkghooks_scenario_check`
  (rooted at the existing `pkghooks_condition` base, alongside
  `pkghooks_notice`/`pkghooks_error_redirect`/`pkghooks_capability_gap`),
  signalled through the existing `pkghooks_signal()` helper — no new
  signaling infrastructure.
- Leave `flag_capability_gap()`, `on_error` wrapping, and all existing
  condition classes completely unchanged. This is a purely additive
  mechanism.
- Explicitly out of scope: any mechanical/heuristic detection of
  in-progress workaround behavior (monkey-patching, namespace
  manipulation, call-pattern heuristics) — considered and rejected this
  session as unreliable and, in the common case, entirely invisible to
  the package at runtime.
- Document, in the new function's own roxygen docs, guidance for authors
  on writing effective scenario descriptions: specific enough to be
  actionable (naming concrete situations, not vague generalities), general
  enough to cover cases the author didn't precisely anticipate.

## Proposed Approach
- New file `bindings/r/R/scenarios.R` housing the new function and the
  load-time notice extension logic, alongside the existing `init.R`,
  `capability_gap.R`, `conditions.R`.
- `pkghooks_init(pkg, notice, on_error = TRUE, scenarios = character())`:
  store `scenarios` in the registry entry for `pkg`. When signalling the
  load-time `pkghooks_notice`, append a formatted scenario list (if
  non-empty) and the generic "call `pkghooks_check_scenarios()` first"
  instruction (always, regardless of whether `scenarios` is empty) to the
  author's own `notice` text before interpolation, rather than requiring
  the author to include this boilerplate themselves.
- `pkghooks_check_scenarios(pkg)`: look up `pkg`'s registered scenarios
  from `.pkghooks_state$packages[[pkg]]$scenarios`. At `"high"`/`"medium"`
  confidence, signal `pkghooks_scenario_check` (non-fatal, via
  `pkghooks_signal()`) with the scenario list plus the ask-the-human
  reminder. At `"low"` confidence, return the scenario list directly
  (invisibly or printed, to be settled in tasks) without the nudge
  framing, since a human calling this deliberately doesn't need to be
  told to ask themselves.
- Testing: extend the existing `testthat` suite (reusing
  `local_reset_pkghooks_state()`, `withr::local_envvar()`, and the
  confidence-forcing pattern already used for `flag_capability_gap()`'s
  tests) to cover scenario registration, notice-folding content, and
  `pkghooks_check_scenarios()`'s confidence-gated behavior — no new test
  infrastructure needed.
- Documentation: roxygen docs for `pkghooks_check_scenarios()` and the
  updated `pkghooks_init()` signature, regenerated via
  `roxygen2::roxygenise()`, following the existing pattern from stage 003.
- Add scenario-check verification items to `bindings/r/MANUAL_TESTING.md`,
  following its existing per-feature checklist structure.
- Do not modify `agent-detect-spec/` or stage 002's design documents in
  this stage — this mechanism is implemented and scoped entirely within
  the R package for now; whether to formalize it as a fourth,
  language-neutral intervention point in stage 002's abstract model is
  left as an open question (below), not decided here.

## Open Questions
- Exact behavior of `pkghooks_check_scenarios()` at `"low"` confidence:
  return the scenario list as a plain character vector, print it via
  `cli`, or something else? Needs a concrete decision before/during task
  breakdown.
- Should the generic "call `pkghooks_check_scenarios()` first" instruction
  be unconditionally included in every load-time notice, or should authors
  be able to opt out (e.g. if they'd rather word this guidance themselves)?
- Final function/parameter naming: `pkghooks_check_scenarios()` vs.
  alternatives; `scenarios` vs. a more structured shape (e.g. a named list
  mapping a short scenario label to its description, rather than a flat
  character vector) — affects both the `pkghooks_init()` signature and
  what `pkghooks_check_scenarios()` returns/displays.
- Should stage 002's language-neutral intervention-point model
  (`specs/002-design-agnostic-spec/design.md`, T002-5) be updated now to
  formally add this as a fourth, "agent-invoked" point — relevant to any
  future non-R implementation — or deferred until a second language
  implementation actually needs the same concept? This stage's own scope
  (per Proposed Approach) is R-only regardless of how this resolves.
