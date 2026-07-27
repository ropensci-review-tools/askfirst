---
created: 2026-07-27T14:12:50Z
agent: claude
git_hash: c1e68f9ef70c2c83ec853714377cbe6a543226c3
---

# Design Decisions: Auto-Init Scenarios

## Summary
Made `askfirst_check_scenarios()` self-initializing by auto-loading the target package's namespace when no `askfirst_init()` registration exists, so the function works from any R session (interactive, `Rscript`, or agent-tool subprocess) without requiring an explicit `init()` call first. Also fixed an environment-dependent test fragility in `test-init.R`.

## New Design Decisions

### Decision 1: Namespace-loading fallback instead of empty scenarios
**Chosen:** When `.askfirst_state$packages[[pkg]]` is NULL, `askfirst_check_scenarios()` calls `requireNamespace(pkg, quietly = TRUE)` to trigger the package's `.onLoad()` (where `askfirst_init()` is normally called), then re-checks the registry. If the package still isn't registered, it errors with a message indicating the package does not appear to adopt askfirst.
**Rationale:** The user explicitly rejected an empty-scenarios fallback — `check_scenarios()` must use the real scenarios registered by the package author, not deferred empty data. Loading the namespace is the natural way to trigger `init()` because it's the standard location for package initialization code.
**Tradeoffs:** Adds a one-time namespace-load cost on the first `check_scenarios()` call for a package loaded in the current session; the error message for non-askfirst packages differs from the previous message.
**Proposed by:** joint
**Relates to:** Extends stage 004's `askfirst_check_scenarios()` function with namespace-auto-initialization, making it a fully standalone intervention point.

### Decision 2: Internal helper `askfirst_try_load_namespace()` for testability
**Chosen:** The `requireNamespace` call was extracted into an internal helper `askfirst_try_load_namespace()` that wraps it in `tryCatch()` (returning FALSE on failure), so it can be mocked in unit tests via testthat's `local_mocked_bindings()`.
**Rationale:** `requireNamespace` is a base R function — no binding exists for it in the askfirst namespace, so testthat cannot mock it directly. The internal helper creates a mockable binding within the package.
**Tradeoffs:** Adds a trivial `@noRd` helper function.
**Proposed by:** agent

### Decision 3: Explicit confidence in the medium-confidence test
**Chosen:** The medium-confidence test in `test-init.R` now sets `.askfirst_state$confidence <- "medium"` directly (matching the low-confidence test's pattern), instead of relying on the test runner lacking a TTY.
**Rationale:** The previous approach depended on the CI runner's absence of a TTY, which failed when running tests interactively. Explicit confidence makes the test deterministic in any environment.
**Tradeoffs:** The test no longer validates the full detection-to-medium-confidence chain end-to-end, but that path is covered separately in `test-detect.R`.
**Proposed by:** mpadge

## Integration with Prior Work
This stage modifies the `askfirst_check_scenarios()` function introduced in stage 004. The change is additive — it only adds a fallback path for the unregistered-package case; the existing code path (package already registered) is completely unchanged. The `askfirst_try_load_namespace()` helper follows the same `@noRd`/`@keywords internal` pattern as every other internal helper in the package. The test fix aligns `test-init.R` with the existing convention used by the low-confidence test.

## Issues Resolved
- `askfirst_check_scenarios("pkg")` failing in fresh `Rscript` calls because `askfirst_init()` wasn't called yet — resolved by auto-loading the namespace.
- The medium-confidence test being environment-dependent (failing when a TTY is present) — resolved by setting confidence explicitly.

## Deferred Items
- None.

## Process Notes
- The original approach (mocking `requireNamespace` directly in tests) failed because testthat's `local_mocked_bindings` only works for bindings in the package's own namespace, not base functions.
