---
created: 2026-07-27T18:20:00Z
agent: claude-sonnet-5
git_hash: b652c8ee47a05301f71cadd1369d50a92d6fbc78
---

# Tasks: sharpen-workaround-guidance

## T011-1: Drop scenario bullets from the load-time notice
- [x] T011-1: In `bindings/r/R/conditions.R`, edit `askfirst_build_notice()` to remove the `if (length(scenarios) > 0) { ... }` block that appends a `"Situations to watch for in {pkg}:\n"` bullet list, and drop the now-unused `scenarios` parameter from its signature (keep only `pkg`, `notice`). Update its roxygen `@keywords internal` comment block to no longer describe folding in scenario bullets. Update the call site in `bindings/r/R/init.R:75` from `askfirst_build_notice(pkg, notice, scenarios)` to `askfirst_build_notice(pkg, notice)`. Also update the roxygen doc for `askfirst_init()` (lines 10-20) which currently states the notice includes `scenarios` "formatted as a bullet list" -- remove that clause since scenario bullets now appear only via `askfirst_check_scenarios()`.

## T011-2: Make the scenario_check bullet list explicitly non-exhaustive
- [x] T011-2: In `bindings/r/R/conditions.R`, edit `askfirst_build_scenario_check_message()` so the bullet-list header text (currently `"Known situations where this applies for {pkg}:\n"`) explicitly states the list is illustrative and non-exhaustive, e.g. `"Situations where this applies for {pkg}, including but not limited to:\n"`. Also adjust the header sentence (`"Before implementing a workaround, the user should be asked whether this capability should be added to {pkg} itself."`) if needed so it reads consistently with the new non-exhaustive framing -- this general rule applies regardless of whether the current task matches a listed example.

## T011-3: Add a structural directive field to every signalled message
- [x] T011-3: In `bindings/r/R/conditions.R`, edit `askfirst_signal()` so that when `prefix = TRUE`, a new line `directive: ask-before-proceeding` is inserted between the existing `askfirst::<language>::<pkg>::<type>` prefix line and the message body (i.e. `message <- paste(prefix_line, directive_line, message, url_line, sep = "\n")`), applied uniformly for all four signal classes (`askfirst_notice`, `askfirst_error_redirect`, `askfirst_scenario_check`, `askfirst_capability_gap`). When `prefix = FALSE`, no directive line is added (matching existing behavior for the prefix and URL lines). Update the roxygen doc for `askfirst_signal()` (the `prefix` parameter description, lines 44-46) to mention the new `directive:` line.

## T011-4: Strengthen the Claude Code session_start hook context
- [x] T011-4: In `agent-hooks/claude/session_start.sh`, add two new numbered points to the `<askfirst-context>` block's "Your response to these signals" list: (5) any scenario/example list accompanying a signal is illustrative, not an exhaustive gate -- the general rule in the notice (e.g. "ask before implementing a workaround") always applies to any missing/buggy capability, whether or not the specific task matches a listed example; (6) when presenting the user a choice between implementing a workaround yourself and asking whether the capability belongs upstream, mark "ask the user" as the recommended option using your own tool's convention for indicating a recommended choice (e.g. an explicit "(Recommended)" label), rather than a neutral, equal-weight menu that includes the workaround as a co-equal option.

## T011-5: Mirror the session_start hook context change for opencode
- [x] T011-5: Apply the identical two new points from T011-4 to `agent-hooks/opencode/session_start.sh`'s `<askfirst-context>` block, keeping the two files' context content identical per the existing stage-007 pattern.

## T011-6: Update load-time notice tests for the removed scenario bullets
- [x] T011-6: In `bindings/r/tests/testthat/test-scenarios.R`, rewrite the test `"the load-time notice includes the generic instruction and scenario bullets"` (lines 25-46) -- rename it to `"the load-time notice includes the generic instruction but not scenario bullets"` and change its assertions so it expects `expect_no_match(msg, "writing a custom date parser", fixed = TRUE)` and `expect_no_match(msg, "re-implementing grouping logic", fixed = TRUE)` (in place of the current `expect_match` calls for those two strings), while still asserting `expect_match(msg, "author notice text", fixed = TRUE)` and `expect_match(msg, "askfirst_check_scenarios", fixed = TRUE)`.

## T011-7: Add a test asserting the non-exhaustive wording in scenario_check
- [x] T011-7: In `bindings/r/tests/testthat/test-scenarios.R`, extend the test `"askfirst_check_scenarios signals askfirst_scenario_check at high confidence"` (lines 67-89), or add a new adjacent test, asserting `conditionMessage(caught)` matches non-exhaustive wording introduced in T011-2 (e.g. `expect_match(conditionMessage(caught), "not limited to", fixed = TRUE)` -- match the exact phrase chosen in T011-2).

## T011-8: Update prefix tests for the new directive field
- [x] T011-8: In `bindings/r/tests/testthat/test-init.R`, update the test `"askfirst_signal with default prefix = TRUE includes the structured prefix"` (lines 162-181) to also assert `expect_match(msg, "directive: ask-before-proceeding", fixed = TRUE)`. Update the test `"askfirst_signal with prefix = FALSE omits the structured prefix"` (lines 142-160) to also assert `expect_no_match(msg, "directive:", fixed = TRUE)`.

## T011-9: Run the test suite and confirm everything passes
- [x] T011-9: Run the test suite (e.g. `devtools::test()` or `R CMD check`) and confirm all tests pass after the changes in T011-1 through T011-8.
