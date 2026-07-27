---
created: 2026-07-27T12:45:30Z
agent: claude-sonnet-5
git_hash: dc8d969f815eacd4368658346c5c36e90da58114
---

# Tasks: realistic-demo

## T008-1: Add standalone `tokenpkg_parse_version()` code chunk

- [x] T008-1: In `bindings/r/vignettes/askfirst-development.Rmd`, add a new
  standalone code chunk at the top of Step 1 (before the DESCRIPTION section)
  showing just the `tokenpkg_parse_version()` function — an Roxygen-documented
  function that splits `"1.2.3"` into `list(major=1L, minor=2L, patch=3L)`,
  errors if the input does not have exactly three dot-separated components,
  and includes an `@examples` tag.

## T008-2: Update `R/tokenpkg.R` code block with realistic scenarios, capability-gap, and error

- [x] T008-2: Replace the `R/tokenpkg.R` code block in the vignette to:
  - Include `tokenpkg_parse_version()` as the core function (same body as
    T008-1).
  - In `.onLoad()`, replace the two scenario entries with version-parsing
    scenarios: (1) writing a pre-release version parser instead of
    contributing pre-release support to tokenpkg, (2) implementing
    cross-package version comparisons that duplicate the parser.
  - In `tokenpkg_capability_gap_demo()`, replace the placeholder message
    with text stating that pre-release suffixes are not supported and the
    agent should ask the user about contributing support to tokenpkg.
  - Replace `tokenpkg_uncaught_error_demo()`'s `stop()` body with a call
    to `tokenpkg_parse_version("not.a.version")`.

## T008-3: Update NAMESPACE block

- [x] T008-3: Add `export(tokenpkg_parse_version)` to the NAMESPACE code
  block in the vignette, alongside the existing exports.

## T008-4: Update Step 2 verification descriptions for version-parsing context

- [x] T008-4: Update the four verification paragraphs in Step 2 (Claude Code)
  to reference the concrete version-parsing context:
  - Load-time notice: mention the two version-parsing scenarios
  - Capability-gap halt: mention pre-release suffix limitation
  - Error redirect: mention the invalid-version-string error
  - Scenario check: mention the two registered scenarios

## T008-5: Update Step 3 and verification checklist for consistency

- [x] T008-5: In Step 3 (opencode), update the reference to "the same four
  things listed in Step 2" to be consistent if any wording changed. In the
  scenario-check checklist section, update the item referencing the
  load-time notice's scenario list to say "version-parsing scenarios".

## T008-6: Verify vignette renders correctly

- [x] T008-6: Run `devtools::check("bindings/r")` to confirm the vignette
  still builds without errors or warnings. Confirm `R CMD check` passes
  (pre-existing detect-test failures accepted).
