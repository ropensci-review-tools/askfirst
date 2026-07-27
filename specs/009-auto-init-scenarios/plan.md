---
created: 2026-07-27T13:57:50Z
agent: claude
git_hash: 09472857dd9c2f84a14613b186ad972cad3a78e0
---

# Plan: auto-init-scenarios

## Overview
`askfirst_check_scenarios("pkg")` currently errors with "'pkg' has not called askfirst_init() in this session" when the target package hasn't been registered via `askfirst_init()` in the current R session. This means an AI agent working in a persistent session (e.g. Claude Code, opencode) who later runs code via `Rscript` in a subprocess gets a hard failure — the fresh R process has no record of the package's scenarios. The fix: when `check_scenarios()` finds no registration for the given package, automatically load the package's namespace (via `requireNamespace()`) to trigger its `.onLoad()`, which is where `askfirst_init()` is normally called. If the namespace loads but the package still isn't registered (it doesn't adopt askfirst), then error informatively.

## Context
- Stage 004 (scenario-check) introduced `askfirst_check_scenarios()` as an agent-invoked intervention point. It depends on `askfirst_init()` having been called for the target package in the current session.
- The state registry (`R/state.R`) is per-session and in-memory — it does not persist across R processes.
- The current error in `askfirst_check_scenarios()` (`R/scenarios.R:88-93`) is intended to catch genuine misuses (passing a package that never adopted askfirst), but also fires for legitimate cases where `init()` was called in a previous R session but not the current one.
- Loading a package's namespace with `requireNamespace(pkg, quietly = TRUE)` triggers its `.onLoad()`, which is the standard location for calling `askfirst_init()`.

## Design Goals
- `askfirst_check_scenarios(pkg)` must work from any R session (interactive, `Rscript`, agent-tool subprocess) without requiring the caller to explicitly call `init()` first.
- When the package genuinely does not adopt askfirst (no `init()` call after namespace load), a clear, informative error should still be raised.
- The existing behavior for packages that are already registered must be unchanged.
- No fallback to empty or default scenario data — the real scenarios registered by the package author must be used.

## Proposed Approach
- In `askfirst_check_scenarios()`, when `.askfirst_state$packages[[pkg]]` is NULL:
  1. Attempt `requireNamespace(pkg, quietly = TRUE)` to load the package's namespace (which triggers `.onLoad()`).
  2. Re-check `.askfirst_state$packages[[pkg]]` after the load.
  3. If still NULL, error with a message indicating the package does not adopt askfirst (or is not installed).
- Wrap the `requireNamespace` call in `tryCatch()` to handle the case where the package is not installed at all.
- Update the existing test "askfirst_check_scenarios errors informatively for an unregistered package" to reflect the new behaviour (load-then-error instead of immediate error).
- Add a new test case for an askfirst-adopting package that is not yet loaded, confirming the scenarios become available after the namespace load.

## Open Questions
- None — the scope is narrow and the approach is straightforward.
