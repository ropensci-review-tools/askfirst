---
created: 2026-07-27T12:45:00Z
agent: claude-sonnet-5
git_hash: 4ad61d730ecbc7fe73df85d64dc487e608b3320a
---

# Design Decisions: Realistic Demo

## Summary
Replaced the abstract placeholder scenarios, capability-gap message, and error message in the askfirst-development vignette's tokenpkg demo with a concrete, useful version-parsing function (`tokenpkg_parse_version()`) and realistic version-parsing scenarios, making the demo a meaningful test of whether askfirst's signals guide an AI agent toward appropriate real-world behaviour rather than just testing text visibility.

## New Design Decisions

### Decision 1: Single-function vignette scope for all demo changes
**Chosen:** Every change — the new `tokenpkg_parse_version()` standalone code chunk, the revised `R/tokenpkg.R` code block, the NAMESPACE export addition, and updated verification descriptions — lives entirely within `bindings/r/vignettes/askfirst-development.Rmd`. No real source files outside the vignette were modified.
**Rationale:** The vignette is a testing document, not production code. Modifying the actual `bindings/r/R/tokenpkg.R` source would couple the demo's content to the package's real runtime code, creating a maintenance dependency each time the real `tokenpkg.R` changes. Keeping everything inside the vignette preserves the existing separation between "demo fixture" and "real package code" established by earlier stages.
**Tradeoffs:** The vignette's `R/tokenpkg.R` block must manually track any future changes to the real `bindings/r/R/tokenpkg.R` if the demo is to remain representative of actual package development.
**Proposed by:** mpadge
**Relates to:** Builds on stage 006's vignette infrastructure by enhancing rather than replacing the existing demo content.

### Decision 2: Concrete error via real input validation, not synthetic stop()
**Chosen:** `tokenpkg_uncaught_error_demo()` now triggers a real error by calling `tokenpkg_parse_version("not.a.version")`, which fails the function's own input-validation check (exactly three dot-separated components required). The old body was a bare `stop("a deliberately uncaught error for manual testing")`.
**Rationale:** A genuine input-validation error gives the AI agent realistic context to parse and respond to — the error message comes from the function's own `@param x` documentation and validation logic, not from a synthetic placeholder. This makes the error-redirect intervention point testable for whether an agent can interpret a real R error rather than a pre-written message.
**Tradeoffs:** None — the new error path exercises the same `stop()` code path, just with a data-driven message instead of a literal string.
**Proposed by:** mpadge

### Decision 3: Capability-gap message references a specific, plausible limitation
**Chosen:** The `tokenpkg_capability_gap_demo()` message now states that pre-release version suffixes (e.g., `"1.2.3-alpha"`) are not supported and asks the agent to ask the user about contributing support to tokenpkg, rather than the previous placeholder "this is a deliberately flagged capability gap for manual testing".
**Rationale:** A concrete, plausible limitation (no pre-release handling) gives the agent something meaningful to act on — discuss scope with the user, contribute a PR, or implement a workaround — rather than an abstract wall of text that only tests whether halt-and-display works.
**Tradeoffs:** None significant; the limitation is realistic and small enough to be a credible feature gap.
**Proposed by:** mpadge

## Integration with Prior Work
This stage is the first to modify the tokenpkg demo content since the vignette infrastructure was introduced in stage 006. It builds on the four-intervention-point architecture (load-time notice, capability-gap halt, error redirect, scenario check) from stages 003–004 and the structured-messaging format from stage 007 — the new concrete messages use the same `askfirst::r::tokenpkg::<type>` prefix format — while replacing only the paragraph-level content within each intervention point, not the mechanism that delivers it.

## Issues Resolved
- The abstract placeholder messages from stage 006's vignette (generic "capability gap" and "uncaught error" text that tested only visibility, not agent reasoning) — resolved by replacing them with concrete version-parsing content.

## Deferred Items
- None — the scope was self-contained and all tasks were completed within this stage.

## Process Notes
- All changes are confined to a single file (`bindings/r/vignettes/askfirst-development.Rmd`), consistent with the stage's decision to treat the vignette as a self-contained demo fixture rather than touching real package sources.
