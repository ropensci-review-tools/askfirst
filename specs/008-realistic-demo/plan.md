---
created: 2026-07-27T12:45:00Z
agent: claude-sonnet-5
git_hash: dc8d969f815eacd4368658346c5c36e90da58114
---

# Plan: realistic-demo

## Overview
The askfirst-development vignette's tokenpkg demo currently uses generic
placeholder text ("this is a deliberately flagged capability gap for manual
testing") and abstract scenarios ("Writing a custom date-parsing helper").
An AI agent testing this has no meaningful context to act on, so the demo
just tests whether text appears — not whether askfirst's signals guide an
agent toward appropriate real-world behaviour. This stage adds a concrete,
useful example function (`tokenpkg_parse_version()`), ties the scenarios,
capability-gap message, and error message to realistic development
situations, and updates the NAMESPACE to export the new function.

## Context
- Stage 007 revised the messaging format to use structured
  `askfirst::<language>::<pkg>::<type>` prefixes, but did not change the
  token package's demo content — the scenarios and messages remained
  abstract placeholders from earlier stages.
- The current tokenpkg demo has no useful function for an agent to
  interact with; the entire exercise is "load package → see text" with no
  meaningful computation or realistic capability gap.
- Stage 006 introduced the vignette infrastructure and the two-vignette
  structure (development + consumer).

## Design Goals
- **Realistic example function:** Add `tokenpkg_parse_version()` that
  parses dot-separated version strings into components — a simple,
  understandable task that an AI agent might genuinely be asked to
  implement, and where a real limitation (no pre-release suffix support)
  is plausible.
- **Concrete scenarios:** Replace the abstract date-parsing and aggregation
  scenarios with version-parsing scenarios: contributing pre-release
  support to the package, and avoiding duplicating the parser for
  cross-package comparisons.
- **Concrete capability-gap message:** Instead of "this is a deliberately
  flagged capability gap", tell the agent the specific limitation (no
  pre-release suffix handling) and what to do (ask the user about
  contributing support to tokenpkg itself).
- **Concrete error message:** Replace the generic "a deliberately uncaught
  error" with the actual error from passing an invalid version string,
  giving the agent realistic context to respond to.
- **Update NAMESPACE:** Export `tokenpkg_parse_version()` alongside the
  existing demo functions.
- **Update verification steps:** The Step 2-3 verification instructions
  should reference the concrete version-parsing scenarios rather than the
  old abstract ones.

## Proposed Approach
- Add a standalone code chunk at the top of Step 1 in
  `bindings/r/vignettes/askfirst-development.Rmd` showing just the
  `tokenpkg_parse_version()` function — so the tester first sees the
  useful function, then wraps it in a package.
- In `R/tokenpkg.R`:
  - Add `tokenpkg_parse_version()` as the core function.
  - Replace `.onLoad()` scenario entries with version-parsing scenarios:
    writing a pre-release version parser instead of contributing to the
    package, and implementing cross-package version comparisons that
    duplicate the parser.
  - Replace the capability-gap message in
    `tokenpkg_capability_gap_demo()` to say that pre-release suffixes
    are not supported and the agent should ask the user about
    contributing support.
  - Replace `tokenpkg_uncaught_error_demo()`'s `stop()` call with a
    call to `tokenpkg_parse_version("not.a.version")` that triggers the
    function's own input validation error.
- Update NAMESPACE to export `tokenpkg_parse_version`.
- Update the four verification descriptions in Step 2 to reference
  version-parsing context.
- All changes are confined to the vignette file.

## Open Questions
- None — the scope is well-defined and confined to the vignette's
  tokenpkg code blocks and verification text.

