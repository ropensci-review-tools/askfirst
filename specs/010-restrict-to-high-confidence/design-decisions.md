---
created: 2026-07-27T14:35:00Z
agent: claude-sonnet-4-6
git_hash: f7de07ab72161414d559420192cfd0a5dd7a1e07
---

# Design Decisions: Restrict to High Confidence

## Summary
Changed all four agent-facing signal points — load-time notice, error handler, scenario check, and capability gap — from firing at both `"high"` and `"medium"` confidence to firing only at `"high"` confidence (known agent detected). The medium-confidence detection logic in `confidence.R` is preserved unchanged for future refinement.

## New Design Decisions

### Decision 1: High-confidence-only gating for all four signal points
**Chosen:** Every condition check that previously matched `c("high", "medium")` now checks only `identical(confidence, "high")`:
- `init.R:74` — load-time notice in `askfirst_init()`
- `init.R:154` — error-redirect in `askfirst_error_handler()`
- `scenarios.R:116` — scenario-check in `askfirst_check_scenarios()`
- `capability_gap.R:48` — halting gap in `askfirst_capability_gap()` (changed from `identical(confidence, "low")` early-return to `!identical(confidence, "high")`)
**Rationale:** Medium confidence (no TTY, but no known agent detected) false-positives on common non-agent contexts: CI pipelines, `R CMD check`, package installation, and testing. This created noise in human workflows and risked conditioning users to ignore the signals. Only high confidence (a vendored-data match) reliably indicates an agent caller.
**Tradeoffs:** Medium-confidence sessions (ambiguous non-interactive) will no longer see any askfirst signals. Acceptable because such sessions are more likely human automation than agents, and the medium tier remains available for future selective opt-in.
**Proposed by:** mpadge

### Decision 2: Medium detection logic preserved
**Chosen:** `confidence.R` is completely unchanged. The `"medium"` tier continues to be computed (`no_tty` without a tool match) and cached in `.askfirst_state$confidence`.
**Rationale:** The tier is still valid in the confidence enum. Preserving it avoids throwing away infrastructure that may be useful for future per-package or per-session opt-in mechanisms.
**Proposed by:** agent

## Integration with Prior Work
This stage adjusts the confidence threshold established in stage 003 (R implementation) and carried through stages 004 (scenario check) and 009 (auto-init). The medium-tier boundary was identified as a known open question in stage 002 (confidence-tiering model) — this stage resolves it by shifting to high-confidence-only signalling while keeping the medium infrastructure for future re-evaluation.

## Issues Resolved
- Medium-confidence false positives during CI/testing/installation: resolved by restricting all signals to high confidence only.

## Deferred Items
- Per-package or per-session opt-in for medium-confidence signals — may be revisited; the detection logic remains in place.

## Process Notes
- The change was straightforward: four condition lines across three files, plus corresponding test updates. No design uncertainty or implementation blockers.
