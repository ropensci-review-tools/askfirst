---
created: 2026-07-27T14:30:00Z
agent: claude-sonnet-4-6
git_hash: 48bc02973317344616693fa348ac72d88da1320a
---

# Tasks: restrict-to-high-confidence

## T010-1: Restrict load-time notice to high confidence
- [ ] T010-1: In `bindings/r/R/init.R:74`, change `confidence %in% c("high", "medium")` to `identical(confidence, "high")`, and update the roxygen doc on line 10 to remove `" or medium"`.

## T010-2: Restrict error handler to high confidence
- [ ] T010-2: In `bindings/r/R/init.R:154`, change `!(confidence %in% c("high", "medium"))` to `!identical(confidence, "high")`, and update the roxygen doc on line 92 to remove `"high"/"medium"`.

## T010-3: Restrict scenario check to high confidence
- [ ] T010-3: In `bindings/r/R/scenarios.R:116`, change `confidence %in% c("high", "medium")` to `identical(confidence, "high")`, and update the roxygen docs on lines 28 and 81 to remove `"high"/"medium"` references.

## T010-4: Restrict capability gap to high confidence
- [ ] T010-4: In `bindings/r/R/capability_gap.R:48`, change `identical(confidence, "low")` to `!identical(confidence, "high")`, and update the roxygen doc on line 12.

## T010-5: Update tests for medium-confidence no-signal behaviour
- [ ] T010-5: Update these tests to expect no signal (instead of expecting a signal) under medium confidence:
  - `tests/testthat/test-init.R:20-34` — `askfirst_init signals a askfirst_notice under medium confidence` → rename to "does not signal" and assert no notice is caught
  - `tests/testthat/test-scenarios.R:91-109` — `askfirst_check_scenarios signals askfirst_scenario_check at medium confidence` → rename to "does not signal" and assert no condition is caught
  - `tests/testthat/test-capability-gap.R:25-35` — `askfirst_capability_gap halts under medium confidence too` → rename to "does not halt" and assert no error is caught

## T010-6: Run tests and verify everything passes
- [ ] T010-6: Run the test suite (e.g. `devtools::test()` or `R CMD check`) and confirm all tests pass after the changes.
