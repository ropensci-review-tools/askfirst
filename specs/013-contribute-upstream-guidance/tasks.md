---
created: 2026-07-27T16:35:03Z
agent: claude-sonnet-5
git_hash: 34a7653f165cda18b283a70dad6cbca25db135b8
---

# Tasks: contribute-upstream-guidance

## T013-1: Add `contribute_how`/`contribute_url` parameters to `askfirst_init()`
- [ ] T013-1: In `bindings/r/R/init.R`, add `contribute_how = NULL` and `contribute_url = NULL` parameters to `askfirst_init(pkg, notice, on_error = TRUE, scenarios = character(), contribute_how = NULL, contribute_url = NULL)`. Add `stopifnot()` validation entries (mirroring the existing `pkg`/`notice`/`scenarios` checks) requiring each to be either `NULL` or a single string: `is.null(contribute_how) || (is.character(contribute_how) && length(contribute_how) == 1)`, same pattern for `contribute_url`. Store both in the registry entry: `.askfirst_state$packages[[pkg]] <- list(notice = notice, on_error = isTRUE(on_error), scenarios = scenarios, contribute_how = contribute_how, contribute_url = contribute_url)`.

## T013-2: Update `askfirst_init()` roxygen docs for the new parameters
- [ ] T013-2: In `bindings/r/R/init.R`, add `@param contribute_how` and `@param contribute_url` roxygen entries above `askfirst_init()`, both documented as optional (default `NULL`). `contribute_how`: free text describing how a human could go about contributing a fix upstream (e.g. "Open an issue describing the gap, or a PR against `main` following `CONTRIBUTING.md`") — advise writing it as third-person/impersonal guidance, not addressed to "you", since the immediate reader of the resulting message is the calling agent, not the human it's meant for. `contribute_url`: a single URL (e.g. an issue tracker or `CONTRIBUTING.md` link). Update the function's `@examples` block to show both in use.

## T013-3: Add the shared `askfirst_build_contribute_line()` helper
- [ ] T013-3: In `bindings/r/R/scenarios.R`, add an internal helper:
  ```r
  askfirst_build_contribute_line <- function(contribute_how = NULL, contribute_url = NULL) {
    parts <- "The developers of {pkg} use the 'askfirst' system, which suggests they may be able to fix this in their own package."
    if (!is.null(contribute_how) && nzchar(contribute_how)) {
      parts <- c(parts, sprintf("The human user of {pkg} is invited to contribute a fix: %s.", contribute_how))
    }
    if (!is.null(contribute_url) && nzchar(contribute_url)) {
      parts <- c(parts, sprintf("Contribution guide: %s", contribute_url))
    }
    paste(parts, collapse = " ")
  }
  ```
  with a `@keywords internal`/`@noRd` roxygen block (matching the style of `askfirst_build_notice()`/`askfirst_build_scenario_check_message()` in the same file) explaining: (a) the base sentence always appears, so the message never reverts to fully generic/unattributed text even when neither optional field is set; (b) neither added sentence uses second-person "you" — the calling agent is the direct reader of this text, so an unqualified "you" would be read as addressing the agent itself rather than the human the invitation is actually for; (c) `{pkg}` is left as a literal glue placeholder, resolved later by `cli::format_inline()` inside `askfirst_signal()`, consistent with how `askfirst_build_notice()` and `askfirst_build_scenario_check_message()` already handle `{pkg}`.

## T013-4: Wire the helper into `askfirst_build_notice()`
- [ ] T013-4: In `bindings/r/R/scenarios.R`, change `askfirst_build_notice <- function(pkg, notice)` to `askfirst_build_notice <- function(pkg, notice, contribute_how = NULL, contribute_url = NULL)`. Replace the current `generic` string's closing clause ("...askfirst::askfirst_check_scenarios(\"{pkg}\") -- the capability may belong in {pkg} itself.") so it ends at "...askfirst::askfirst_check_scenarios(\"{pkg}\")." and append the result of `askfirst_build_contribute_line(contribute_how, contribute_url)` as a separate sentence in the same paragraph (e.g. `generic <- paste(generic, askfirst_build_contribute_line(contribute_how, contribute_url))`). In `bindings/r/R/init.R`, update the `askfirst_build_notice(pkg, notice)` call site inside `askfirst_init()` to `askfirst_build_notice(pkg, notice, contribute_how, contribute_url)`.

## T013-5: Wire the helper into `askfirst_build_scenario_check_message()`
- [ ] T013-5: In `bindings/r/R/scenarios.R`, change `askfirst_build_scenario_check_message <- function(scenarios)` to `askfirst_build_scenario_check_message <- function(scenarios, contribute_how = NULL, contribute_url = NULL)`. In the `header` construction, replace the closing clause ("...capability should be added to {pkg} itself -- this applies to any missing or buggy capability, not just situations matching a listed example below.") by appending `askfirst_build_contribute_line(contribute_how, contribute_url)` as an additional sentence after it (both the `length(scenarios) == 0` early-return branch and the bullet-list branch should include the updated `header`, since both currently build from the same `header` variable). In `askfirst_check_scenarios()` (same file), read `contribute_how <- info$contribute_how` and `contribute_url <- info$contribute_url` from the registry entry (the same `info` list already used for `info$scenarios`), and pass them through: `askfirst_build_scenario_check_message(scenarios, contribute_how, contribute_url)`.

## T013-6: Update `test-init.R` for the new fields
- [ ] T013-6: In `bindings/r/tests/testthat/test-init.R`, add tests verifying: (a) `askfirst_init()` stores `contribute_how`/`contribute_url` in `.askfirst_state$packages[[pkg]]` when supplied; (b) both default to `NULL` in the registry when omitted; (c) `askfirst_init()` errors (via `expect_error()`) when `contribute_how` or `contribute_url` is supplied as a non-`NULL`, non-single-string value (e.g. a numeric or a length-2 character vector), matching the existing validation-test pattern used for `pkg`/`notice`.

## T013-7: Update `test-scenarios.R` for the new message content
- [ ] T013-7: In `bindings/r/tests/testthat/test-scenarios.R`, add tests covering both `askfirst_build_notice()`-driven (load-time notice) and `askfirst_check_scenarios()`-driven (scenario_check) message content:
  - When a package registers both `contribute_how` and `contribute_url`, both the load-time notice and the scenario-check halt message include the "The human user of `{pkg}` is invited to contribute a fix: ..." sentence and the "Contribution guide: ..." sentence, and do **not** contain a bare "You are invited" phrase.
  - When only `contribute_how` is registered, only that sentence appears (no "Contribution guide:" sentence).
  - When only `contribute_url` is registered, only that sentence appears (no "invited to contribute" sentence).
  - When neither is registered, the message still contains "The developers of `{pkg}` use the 'askfirst' system" (the always-present base sentence), confirming the fallback never reverts to the old fully-generic wording.
  Use the existing `tryCatch()`/`withCallingHandlers()` patterns already present in this file (halting `tryCatch()` for `scenario_check`, `withCallingHandlers()` for the non-fatal `notice`) as templates.

## T013-8: Update the `using-askfirst.Rmd` vignette
- [ ] T013-8: In `bindings/r/vignettes/using-askfirst.Rmd`, section "1. Registering your package: `askfirst_init()`": add `contribute_how` and `contribute_url` to the example `.onLoad()` call, with realistic example values (e.g. `contribute_how = "Open an issue describing the gap, or a PR following CONTRIBUTING.md"`, `contribute_url = "https://github.com/example/mypackage/issues"`). Add a new "**Writing `contribute_how`/`contribute_url`**" paragraph after the existing "**Writing `scenarios`**" paragraph, explaining both are optional, and explicitly warning against second-person "you" phrasing in `contribute_how` for the same reason given in the "Writing `notice`" paragraph just above it (the agent is the direct reader; an unqualified "you" would be read as addressing the agent, not the human the guidance is meant for).

## T013-9: Regenerate `man/` pages with roxygen2
- [ ] T013-9: From `bindings/r/`, run `roxygen2::roxygenise()` (or `devtools::document()`) to regenerate `man/askfirst_init.Rd` from the docblock changes in T013-2, and confirm the updated `.Rd` file is staged along with the source changes.

## T013-10: Full verification pass
- [ ] T013-10: Run the R package test suite (`devtools::test()` from `bindings/r/`) to confirm all tests pass after T013-1 through T013-7. Manually call `askfirst_init()` with and without `contribute_how`/`contribute_url` set (forcing `.askfirst_state$confidence <- "high"` in an interactive session, per the pattern used in existing tests) and inspect the rendered `askfirst_notice`/`askfirst_scenario_check` message text directly to confirm it reads correctly and contains no unqualified "you".
