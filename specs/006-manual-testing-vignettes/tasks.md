---
created: 2026-07-27T10:38:05Z
agent: claude-sonnet-5
git_hash: f61eb101bb2764abfbe7c8f986dc7bbf6eb063c6
---

# Tasks: manual-testing-vignettes

## T006-1: Add vignette-building dependencies to DESCRIPTION
- [ ] T006-1: In `bindings/r/DESCRIPTION`, add `knitr` and `rmarkdown` to
      the `Suggests:` field (alphabetically ordered alongside the
      existing `testthat (>= 3.0.0)` and `withr` entries), and add a new
      top-level `VignetteBuilder: knitr` field. Confirm the file still
      parses with `desc::desc(file = "bindings/r/DESCRIPTION")` or
      `devtools::load_all("bindings/r")`.

## T006-2: Scaffold vignettes/ and write askfirst-development.Rmd — setup and token package
- [ ] T006-2: Create `bindings/r/vignettes/askfirst-development.Rmd` with
      standard vignette YAML front-matter (`title`, `output:
      rmarkdown::html_vignette`, `vignette: >
      %\VignetteIndexEntry{...}\n%\VignetteEngine{knitr::rmarkdown}\n%\VignetteEncoding{UTF-8}`).
      Write the opening section carrying over the rationale from the
      current `bindings/r/MANUAL_TESTING.md` lines 1-10 (why automated
      `tests/testthat/` coverage cannot verify that a real agent tool's
      harness surfaces conditions to the calling LLM). Follow with a
      step-by-step walkthrough that creates a minimal token test package
      from scratch, wiring in every `askfirst` integration point in its
      `.onLoad()`/`zzz.R` and exported functions:
      `askfirst_init(pkg, notice, scenarios)`, an exported function
      calling `askfirst_capability_gap()`, `askfirst_install_error_handler()`,
      and an exported (or documented ad-hoc) call site for
      `askfirst_check_scenarios()`. Base the package skeleton and example
      `notice`/`scenarios` content on the existing Setup section in
      `bindings/r/MANUAL_TESTING.md` (lines 12-39), but include all four
      integration points (the current file's Setup section only covers
      `askfirst_init()` and `askfirst_capability_gap()` — add the missing
      `askfirst_install_error_handler()` and `askfirst_check_scenarios()`
      wiring). Include explicit install instructions
      (`devtools::install("path/to/tokenpkg")` or `R CMD INSTALL`).

## T006-3: askfirst-development.Rmd — explicit Claude Code and opencode verification steps
- [ ] T006-3: In the same `askfirst-development.Rmd`, add a section with
      explicit, copy-pasteable shell and R code for driving the token
      package (from T006-2) inside a real Claude Code session and a real
      opencode session, and for each of the four intervention points
      (load-time notice, `askfirst_capability_gap()` halt, error-redirect
      notice via `askfirst_install_error_handler()`, and
      `askfirst_check_scenarios()` response) state exactly what output in
      that tool's transcript confirms success. Cover both tools
      separately since their harnesses differ (e.g. persistent session
      vs. subprocess invocation) — do not assume one verification
      transcript generalizes to the other.

## T006-4: askfirst-development.Rmd — carry over per-tool checklist and caveats
- [ ] T006-4: In the same `askfirst-development.Rmd`, add a closing
      section presenting the remaining tools as a follow-on manual
      checklist, carrying over the full tool list and its checkbox
      structure from `bindings/r/MANUAL_TESTING.md` lines 47-68 (Cursor,
      Cursor CLI, Gemini CLI, Cline, Codex CLI, Antigravity, Augment CLI,
      Goose, Junie, Pi, Claude Code Cowork, Replit, GitHub Copilot CLI,
      AWS Kiro, openclaw, Devin — every tool except Claude Code and
      opencode, which T006-3 already covers explicitly), including the
      Replit `REPL_ID`-ambiguity caveat and the Kiro IDE-terminal
      false-positive caveat verbatim in substance. Also carry over, in
      substance: the "Additional scenarios" section (lines 70-88 —
      plain interactive console, `Rscript`/CI non-agent case, uncaught
      error under an agent tool, and the `tryCatch()` error-redirect
      limitation) and the full "Scenario-check checklist" section (lines
      90-109). Nothing from the current `MANUAL_TESTING.md` should be
      dropped without being represented somewhere in the two new
      vignettes.

## T006-5: Write using-askfirst.Rmd consumer guide
- [ ] T006-5: Create `bindings/r/vignettes/using-askfirst.Rmd` with
      standard vignette YAML front-matter (same format as T006-2). Write
      a procedural, descriptive guide for maintainers of other packages
      adopting `askfirst` as a dependency, with one section per
      integration point: (1) when and why to call `askfirst_init()` in
      `.onLoad()`, and how to write an effective `notice` and `scenarios`
      character vector; (2) how to mark a known limitation with
      `askfirst_capability_gap()`; (3) how and why to opt into
      `askfirst_install_error_handler()`; (4) what end users of the
      adopting package experience when an agent calls
      `askfirst_check_scenarios()`. Use small illustrative code fragments
      per section for readability, but do not include a full worked
      token-package example, shell transcripts, or any CLI-tool-specific
      verification steps — that content belongs only in
      `askfirst-development.Rmd`.

## T006-6: Delete the superseded MANUAL_TESTING.md
- [ ] T006-6: Delete `bindings/r/MANUAL_TESTING.md` once T006-2 through
      T006-4 have absorbed its content into `askfirst-development.Rmd`.
      Grep the repo (`grep -rn "MANUAL_TESTING" .`) for any remaining
      references (e.g. README links, CI config, CONTRIBUTING docs) and
      update them to point at the new vignette(s) instead.

## T006-7: Build and check the new vignette infrastructure locally
- [ ] T006-7: From `bindings/r`, run
      `devtools::build_vignettes()` (or
      `rmarkdown::render()` on each `.Rmd` directly if `devtools` isn't
      available) to confirm both vignettes render without errors, then
      run a full `R CMD check` (e.g. `devtools::check("bindings/r")` or
      `rcmdcheck::rcmdcheck("bindings/r")`) to confirm the new
      `Suggests`/`VignetteBuilder` additions from T006-1 don't introduce
      any new `R CMD check` NOTE/WARNING/ERROR.

## T006-8: Fix and regenerate the CI workflow
- [ ] T006-8: Run `usethis::use_github_action("check-standard")` (from
      within `bindings/r` as the active package, or targeting it) to
      obtain the current upstream `check-standard.yaml` template. Merge
      it into `.github/workflows/r-cmd-check.yml`, replacing the existing
      `r-cmd-check` job, and set `working-directory: bindings/r` on every
      step that operates on the package (setup-r-dependencies,
      check-r-package, and any other path-sensitive step in the
      template) — this fixes the pre-existing bug where those steps used
      `working-directory: r` instead of `bindings/r` post-stage-005
      relocation. Preserve the existing `check-vendor-sync` job and the
      `on.push.paths`/`on.pull_request.paths` triggers unchanged. Confirm
      the resulting job would build vignettes as part of `R CMD check`
      (the standard `check-standard` template does this by default via
      `rcmdcheck::rcmdcheck(build_args = ...)`), so vignette regressions
      are caught in CI going forward.
