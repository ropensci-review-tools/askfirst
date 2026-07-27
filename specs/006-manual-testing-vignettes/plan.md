---
created: 2026-07-27T10:31:56Z
agent: claude-sonnet-5
git_hash: f61eb101bb2764abfbe7c8f986dc7bbf6eb063c6
---

# Plan: manual-testing-vignettes

## Overview
Replace `bindings/r/MANUAL_TESTING.md` with two real R vignettes: a
package-developer walkthrough (build a token test package, wire up every
`askfirst` integration step, and verify against Claude Code and opencode
with explicit runnable code), and a package-consumer procedural guide
(describes the integration steps an adopting maintainer would follow,
without runnable examples).

## Context
- Stage 004 (`specs/004-scenario-check`) added
  `askfirst_check_scenarios()` as a fourth, agent-invoked intervention
  point alongside the three system-triggered ones from stage 002
  (`load_time`/`error_time`/`capability_gap_time`). All four need to be
  represented in the developer-facing walkthrough.
- Stage 005 (`specs/005-rename-to-askfirst`) renamed the package and every
  exported symbol from `pkghooks_*` to `askfirst_*`
  (`askfirst_init()`, `askfirst_capability_gap()`,
  `askfirst_check_scenarios()`, `askfirst_install_error_handler()`).
  `MANUAL_TESTING.md`'s existing content already reflects this rename and
  is the accurate baseline to carry forward.
- The package is unreleased (`0.0.0.9000`, `bindings/r/DESCRIPTION`), so
  no existing vignette consumers or CRAN check history constrain this
  work.
- No `vignettes/` directory or `knitr`/`rmarkdown` dependency exists yet
  in `bindings/r/DESCRIPTION` — this stage introduces standard R vignette
  infrastructure for the first time.
- Decision on format (confirmed with user during this stage's planning):
  build real, buildable R vignettes rather than plain markdown files, so
  they're discoverable via `vignette(package = "askfirst")` and any
  future pkgdown site, not just GitHub browsing.
- `.github/workflows/r-cmd-check.yml`'s `r-cmd-check` job is currently
  broken independent of this stage: both its `setup-r-dependencies` and
  `check-r-package` steps pass `working-directory: r`, but the package
  lives at `bindings/r` (post-stage-005 relocation) — the path was never
  updated when the package moved. Confirmed by user: fix this as part of
  this stage rather than deferring it, since adding a vignette-building
  dependency to a package whose CI check is already pointed at the wrong
  directory would just compound the breakage.

## Design Goals
- Fully replace `bindings/r/MANUAL_TESTING.md` with two vignettes living
  in `bindings/r/vignettes/`, removing the old file rather than leaving
  it alongside the new ones.
- **Developer vignette** (`askfirst` package maintainers/contributors):
  a complete, followable walkthrough — create a minimal token test
  package from scratch, add every `askfirst` integration point
  (`askfirst_init()` with `notice` + `scenarios`, an exported function
  calling `askfirst_capability_gap()`, `askfirst_install_error_handler()`
  wiring, and a call site for `askfirst_check_scenarios()`), then give
  explicit, copy-pasteable shell/R code to install that token package and
  drive a real Claude Code session and a real opencode session against it
  to confirm the load-time notice, the capability-gap halt, the
  error-redirect notice, and the scenario-check response all surface
  correctly in each tool.
- Preserve the substance of the existing per-tool checklist (the full
  tool list, the Replit/Kiro false-positive caveats, the `tryCatch()`
  error-redirect limitation, and the scenario-check-specific checks) from
  `MANUAL_TESTING.md`, reorganized into the new vignette rather than
  dropped — this stage is a restructuring/expansion of existing content,
  not a scope cut. Full coverage of every tool in the current checklist
  is out of scope for the *explicit worked example* (which targets Claude
  Code and opencode only, per the user's request); the remaining tools
  stay as a checklist appendix.
- **Consumer vignette** (maintainers of other packages adopting
  `askfirst` as a dependency): a procedural, descriptive guide covering
  when/why to call `askfirst_init()`, how to write an effective `notice`
  and `scenarios` list, how to mark a known limitation with
  `askfirst_capability_gap()`, how to opt into
  `askfirst_install_error_handler()`, and how end users of *their*
  package would experience `askfirst_check_scenarios()` — without a
  worked test package or shell transcripts. This vignette targets people
  who will never run the verification steps themselves.
- Wire the new vignettes into standard R package infrastructure: add
  `knitr` and `rmarkdown` to `Suggests`, add `VignetteBuilder: knitr` to
  `DESCRIPTION`, and give both `.Rmd` files correct
  `vignette::vignette_index_entry` front-matter so `R CMD check` and
  `devtools::build_vignettes()` succeed.
- Replace the broken `r-cmd-check` job in
  `.github/workflows/r-cmd-check.yml` with the standard
  `usethis::use_github_action("check-standard")` template, adapted with
  `working-directory: bindings/r` throughout, so CI actually checks the
  right package (and, as a consequence, builds the new vignettes on every
  push/PR instead of silently skipping them).

## Proposed Approach
- Create `bindings/r/vignettes/` with two files:
  - `askfirst-development.Rmd` — the maintainer/testing walkthrough.
  - `using-askfirst.Rmd` — the consumer/procedural guide.
- `askfirst-development.Rmd` structure: (1) why automated tests can't
  verify real-agent-harness behavior (carried over rationale from the
  current `MANUAL_TESTING.md` intro), (2) step-by-step creation of a
  token test package (`usethis`-style directory layout, minimal
  `DESCRIPTION`, an `.onLoad()` calling `askfirst_init()`, one function
  calling `askfirst_capability_gap()`, one calling
  `askfirst_check_scenarios()`, and `askfirst_install_error_handler()`
  wired into `.onLoad()` or `zzz.R`), (3) install instructions
  (`devtools::install()` / `R CMD INSTALL`), (4) explicit shell + R
  snippets for driving the token package inside a Claude Code session and
  an opencode session and what output confirms success at each of the
  four intervention points, (5) the remaining per-tool checklist
  (unchanged substance from today's file) as a follow-on manual pass
  across the other listed tools, (6) the additional human/non-agent
  false-positive checks and the `tryCatch()` limitation note, carried
  over verbatim in substance.
- `using-askfirst.Rmd` structure: prose sections per integration point
  (init/notice/scenarios, capability gap, error redirect, scenario
  check), each describing what to write and why, with small illustrative
  code fragments where helpful for readability, but no end-to-end
  runnable transcript and no CLI-tool-specific verification steps —
  that's the first vignette's job.
- Update `bindings/r/DESCRIPTION`: add `knitr`, `rmarkdown` to `Suggests`,
  add `VignetteBuilder: knitr`.
- Delete `bindings/r/MANUAL_TESTING.md` once its content is fully
  absorbed into the two vignettes.
- Run `devtools::build_vignettes()` (or equivalent) and `R CMD check`
  locally as part of implementation to confirm the new vignette
  infrastructure builds cleanly.
- Regenerate the CI workflow: run
  `usethis::use_github_action("check-standard")` to get the current
  upstream template, then adapt every step that assumes the package
  lives at the repo root to instead use
  `working-directory: bindings/r` (matching the pattern already used —
  incorrectly, as `r` instead of `bindings/r` — in the existing job),
  and fold the pre-existing `check-vendor-sync` job back in unchanged
  alongside it in `.github/workflows/r-cmd-check.yml`.

## Open Questions
- Exact wording/tone split between the two vignettes' overlapping
  sections (e.g. how much of the "why manual testing is needed" rationale
  belongs in the consumer vignette, if at all) — left to implementation
  judgment, consistent with this project's existing documentation voice.
  (OQ deferred by user — resolve during implementation, not before.)
