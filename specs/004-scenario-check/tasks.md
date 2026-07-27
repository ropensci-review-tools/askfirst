---
created: 2026-07-27T09:45:00Z
agent: claude-sonnet-5
git_hash: 9a8d6eed1fa7d307db318399a24f34f7c20aadd1
---

# Tasks: scenario-check

`plan.md`'s open questions are resolved here so every task is
implementable without further clarification:

- **Low-confidence return value**: `pkghooks_check_scenarios()` returns
  the registered scenarios as a plain, invisible character vector — no
  condition signalled, no "ask the human" framing (a human calling this
  deliberately doesn't need to be told to ask themselves).
- **Generic instruction opt-out**: not configurable in v1 — the
  "call `pkghooks_check_scenarios()` first" instruction is always folded
  into the load-time notice, regardless of whether the author supplied
  any `scenarios`. Centralizing this (rather than letting each author
  reword it) matches the existing rationale for `pkghooks` owning *how*
  messages are delivered, not just *whether*.
- **Shape of `scenarios`**: a flat `character` vector (one string per
  scenario), not a named list — simplest for authors to write, consistent
  with `notice`'s own plain-string shape.
- **Stage 002's language-neutral model**: left unchanged in this stage.
  This mechanism is implemented and scoped entirely within
  `bindings/r/`; no changes to `agent-detect-spec/` or
  `specs/002-design-agnostic-spec/`.

## T004-1: Extend pkghooks_init() with a scenarios parameter
- [x] T004-1: In `bindings/r/R/init.R`, change `pkghooks_init()`'s
  signature to `pkghooks_init(pkg, notice, on_error = TRUE, scenarios =
  character())`. Validate `scenarios` is a character vector (possibly
  empty; `stopifnot()` alongside the existing `pkg`/`notice` checks).
  Store it in the registry: `.pkghooks_state$packages[[pkg]] <- list(notice
  = notice, on_error = isTRUE(on_error), scenarios = scenarios)`.

## T004-2: Build the combined load-time notice content
- [x] T004-2: In `bindings/r/R/init.R` (or a new
  `bindings/r/R/scenarios.R`, whichever keeps `init.R` from growing too
  large — prefer a small helper `pkghooks_build_notice(notice, scenarios,
  pkg)` in `scenarios.R`, called from `pkghooks_init()`), construct the
  text actually passed to `pkghooks_signal()` for the load-time
  `pkghooks_notice`: the author's own `notice` text, followed by a fixed,
  generic sentence (always included) instructing the LLM to call
  `pkghooks_check_scenarios("{pkg}")` first, or ask the user, if it
  notices itself about to duplicate/extend `pkg`'s functionality —
  followed by a formatted bullet list of `scenarios` (only appended when
  `scenarios` is non-empty). Update `pkghooks_init()` to signal
  `pkghooks_notice` with this combined text instead of the raw `notice`
  argument.

## T004-3: Implement pkghooks_check_scenarios()
- [x] T004-3: In `bindings/r/R/scenarios.R`, write and export
  `pkghooks_check_scenarios(pkg)`. Validate `pkg` is a single string.
  Look up `.pkghooks_state$packages[[pkg]]$scenarios` (error via
  `rlang::abort()` with a clear message if `pkg` was never registered via
  `pkghooks_init()`). Compute confidence via `pkghooks_ensure_detection()`.
  At `"high"`/`"medium"` confidence: signal `pkghooks_scenario_check`
  (via `pkghooks_signal()`, non-fatal, carrying `pkg`) with the scenario
  list plus a reminder to ask the human before implementing a custom
  workaround, formatted the same way as T004-2's bullet list. At `"low"`
  confidence: return the raw `scenarios` character vector via
  `invisible()`, with no condition signalled and no nudge wording.

## T004-4: Regenerate package documentation
- [x] T004-4: Add roxygen2 documentation to `pkghooks_check_scenarios()`
  (parameters, return value, `@examples` demonstrating both a scenario
  list and an empty-scenarios call), and update `pkghooks_init()`'s
  existing roxygen block to document the new `scenarios` parameter,
  including brief guidance on writing effective scenario descriptions
  (specific enough to be actionable; general enough to cover
  unanticipated cases). Run `roxygen2::roxygenise()` from `bindings/r/`
  to regenerate `NAMESPACE` and `man/`.

## T004-5: Write automated tests
- [x] T004-5: Write `bindings/r/tests/testthat/test-scenarios.R`,
  reusing `local_reset_pkghooks_state()`: (a) `pkghooks_init()` stores
  `scenarios` correctly in the registry; (b) the load-time
  `pkghooks_notice` signalled under high confidence includes both the
  generic instruction sentence and the author-supplied scenario text when
  `scenarios` is non-empty; (c) the same notice still includes the
  generic instruction (but no scenario bullets) when `scenarios` is left
  at its default empty vector; (d) `pkghooks_check_scenarios()` signals a
  `pkghooks_scenario_check` condition (class-checked, `pkg` field
  verified, scenario text present in the message) under manually-seeded
  `"high"` and `"medium"` confidence; (e) `pkghooks_check_scenarios()`
  returns the plain scenario vector with no condition signalled under
  `"low"` confidence; (f) calling `pkghooks_check_scenarios()` for a `pkg`
  never registered raises an informative error.

## T004-6: Update the manual testing checklist
- [x] T004-6: Add a new section to `bindings/r/MANUAL_TESTING.md`,
  following its existing structure, with checklist items to verify under
  at least one real agent tool: the load-time notice includes both the
  generic instruction and a registered scenario list; calling
  `pkghooks_check_scenarios()` mid-session surfaces the scenario list and
  ask-the-human reminder; the same call from a plain human R console
  returns the list without any nudge wording.

## T004-7: Verify no regressions
- [x] T004-7: Run the full `testthat` suite and `R CMD check
  --as-cran` on `bindings/r/` after T004-1 through T004-5 are complete;
  confirm 0 errors and 0 warnings (matching stage 003's baseline), and
  that all previously-passing tests (detect/confidence/init/capability-gap)
  still pass unchanged.
