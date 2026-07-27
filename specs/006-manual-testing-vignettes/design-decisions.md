---
created: 2026-07-27T11:05:00Z
agent: claude-sonnet-5
git_hash: 5442965ba81d078a23db0e75a7aca793e492fcd5
---

# Design Decisions: manual-testing-vignettes

## Summary
This stage replaced `bindings/r/MANUAL_TESTING.md` with two real R
vignettes — a maintainer-facing testing walkthrough
(`askfirst-development.Rmd`) and a consumer-facing procedural guide
(`using-askfirst.Rmd`) — and fixed a pre-existing broken CI job
discovered along the way.

## New Design Decisions

### Decision 1: Real, buildable vignettes over plain markdown
**Chosen:** The two replacement documents are standard R vignettes in
`bindings/r/vignettes/`, requiring `knitr`/`rmarkdown` in `Suggests` and
`VignetteBuilder: knitr` in `DESCRIPTION` — the project's first vignette
infrastructure.
**Rationale:** Discoverability via `vignette(package = "askfirst")` and
any future pkgdown site outweighs the cost of the new build dependency,
given the package is still unreleased (`0.0.0.9000`).
**Tradeoffs:** None significant; confirmed against a clean local
`R CMD check` (0 errors/warnings/notes) with both vignettes rendering and
re-building successfully.

### Decision 2: Explicit worked example limited to two tools
**Chosen:** `askfirst-development.Rmd` gives a fully explicit,
copy-pasteable verification walkthrough (token test package plus
shell/R commands) only for Claude Code and opencode. Every other
previously-listed tool (Cursor, Gemini CLI, Cline, Codex CLI, Antigravity,
Augment CLI, Goose, Junie, Pi, Claude Code Cowork, Replit, GitHub Copilot
CLI, AWS Kiro, openclaw, Devin) is preserved as a manual checklist
appendix rather than each getting its own worked transcript.
**Rationale:** Matches the requested scope precisely, while still
carrying forward every checklist item, false-positive caveat (Replit
`REPL_ID`, Kiro IDE-terminal), and the `tryCatch()` error-redirect
limitation from the file being replaced — no content was dropped, only
reorganized and prioritized.
**Tradeoffs:** None; the appendix is functionally equivalent to the
original file's per-tool checklist.

### Decision 3: Fix the broken CI workflow in this stage, not deferred
**Chosen:** `.github/workflows/r-cmd-check.yml`'s `r-cmd-check` job still
used `working-directory: r`, left over from before the R package moved to
`bindings/r`. It was regenerated from
`usethis::use_github_action("check-standard")`'s current upstream
template (multi-OS matrix, pandoc setup, `check-r-package@v2`), adapted
throughout with `working-directory: bindings/r`. The pre-existing
`check-vendor-sync` job and the path-filtered `on.push`/`on.pull_request`
triggers were preserved unchanged.
**Rationale:** Adding a vignette-building dependency to a package whose
CI check already pointed at the wrong directory would have compounded
existing breakage rather than caught it.
**Tradeoffs:** None; this was a bug fix, not a scope tradeoff.

### Decision 4: `askfirst_install_error_handler()` is internal, not a call site
**Chosen:** The vignette content documents `askfirst_init()`'s `on_error`
argument (default `TRUE`) as the actual integration point, rather than
describing a separate exported function for authors to call. The
consumer vignette's `on_error` section was later expanded, after review,
with concrete code for the `TRUE` default, the `on_error = FALSE`
opt-out, and a worked example of what an agent sees when an uncaught
error triggers the redirect.
**Rationale:** Reading the actual source (`bindings/r/R/init.R`) showed
`askfirst_install_error_handler()` is `@noRd`/internal, invoked
automatically from `askfirst_init()` — the original task breakdown's
phrasing assumed otherwise. The vignette had to reflect the real exported
API, and an initial prose-only explanation of `on_error` didn't
demonstrate where or how the argument is actually set.
**Tradeoffs:** None; this corrects an inaccuracy rather than trading
anything off.

## Integration with Prior Work
Builds on the exported API finalized in stage 005
(`askfirst_init()`, `askfirst_capability_gap()`,
`askfirst_check_scenarios()`) and the fourth, agent-invoked intervention
point added in stage 004 — all three exported functions and all four
intervention points (load-time notice, capability-gap halt, error
redirect, scenario check) are represented across the two new vignettes.
This is the first stage to touch `bindings/r/DESCRIPTION`'s `Suggests`/
`VignetteBuilder` fields and the first to modify
`.github/workflows/r-cmd-check.yml` since it was written.

## Issues Resolved
- Vignette format (real vignettes vs. plain markdown): resolved in favor
  of real vignettes.
- Whether the broken CI `working-directory` path was in scope: resolved
  yes, fixed in this stage.

## Deferred Items
- Exact wording/tone split between the two vignettes' overlapping
  sections, left to implementation-time judgment rather than a firm rule.

## Process Notes
- The task breakdown's assumption that `askfirst_install_error_handler()`
  is a directly-callable integration point was found incorrect during
  implementation, by reading `bindings/r/R/init.R` directly rather than
  relying on the plan's wording; the vignette content was corrected
  accordingly.
- After the stage's tasks were marked complete, a follow-up review round
  found the consumer vignette's `on_error` explanation was prose-only
  with no demonstrating code, and it was expanded with explicit examples
  before this retrospective was written.
