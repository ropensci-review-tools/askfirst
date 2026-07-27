---
created: 2026-07-27T14:25:00Z
agent: claude-sonnet-4-6
git_hash: 48bc02973317344616693fa348ac72d88da1320a
---

# Plan: restrict-to-high-confidence

## Overview
Restrict all agent-facing signals to high confidence (known agent detected); suppress init message during medium-confidence sessions like installation/CI

## Context

The confidence tiering model (Decision 2 in stage 002) defines three tiers:
- **high**: vendored-data match (known agent detected)
- **medium**: no match, but no TTY attached (ambiguous non-interactive automation — CI, testing, package installation)
- **low**: TTY present (likely human)

Stage 003 (R implementation) implemented `askfirst_init()` to signal the load-time notice at both `"high"` and `"medium"` confidence. The same threshold was applied in `askfirst_error_handler()` (stage 003) and `askfirst_check_scenarios()` (stage 009). Medium confidence was included as a conservative default — non-interactive sessions are more likely to be agents than humans — but it also fires in many non-agent contexts (e.g. `R CMD check`, package installation, CI pipelines), creating noise.

Stage 002 reserved the `"cooperative"` tier for future tool-initiated signals but left the medium-tier boundary as a known open question.

## Design Goals

- Suppress the `askfirst_init()` load-time notice during medium-confidence sessions (installation, CI, testing) where no known agent is detected
- Apply the same high-confidence-only gate to error handler notifications and scenario-check messages, for consistency
- Keep the medium detection logic (in `confidence.R`) intact and unchanged — the tier remains part of the enum for future refinement
- Avoid any changes to detection data, agent matching, or the confidence computation itself

## Proposed Approach

Three one-line condition changes, all following the same pattern: replace `confidence %in% c("high", "medium")` with `identical(confidence, "high")`.

1. **`bindings/r/R/init.R:74`** — `askfirst_init()` load-time notice gating
2. **`bindings/r/R/init.R:154`** — `askfirst_error_handler()` error-redirect gating
3. **`bindings/r/R/scenarios.R:116`** — `askfirst_check_scenarios()` scenario-check gating

The medium-confidence detection path in `bindings/r/R/confidence.R` is left untouched, preserving the full enum for future re-evaluation or opt-in mechanisms.

## Open Questions

None — scope is fully bounded and well-understood from the existing implementation.
