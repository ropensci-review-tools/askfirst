---
created: 2026-07-27T14:19:00Z
agent: claude-sonnet-5
git_hash: fc95d2497f30e047600031ac74d1b03f39d47c1a
---

# Tasks: revise-messaging

## T007-1: Add `askfirst_lang()` internal constant and URL placeholder

- [ ] T007-1: Add `askfirst_lang()` internal helper returning `"r"` for the R binding, so `askfirst_signal()` can construct the `<language>` component of the structured prefix. Also add `askfirst_url()` returning `"https://ropensci.github.io/askfirst/"` as a placeholder URL. Store both in a new file `bindings/r/R/lang.R` to make future bindings obvious.

## T007-2: Revise `askfirst_signal()` to prepend structured prefix

- [ ] T007-2: Modify `askfirst_signal()` in `bindings/r/R/conditions.R` to prepend a line `askfirst::<language>::<pkg>::<type>` before the message text, where `<language>` comes from `askfirst_lang()`, `<pkg>` from the `pkg` parameter, and `<type>` is derived from the `class` parameter (mapping `askfirst_notice` -> `notice`, `askfirst_error_redirect` -> `error_redirect`, `askfirst_capability_gap` -> `capability_gap`, `askfirst_scenario_check` -> `scenario_check`). Append a second line `See: <url>` using the placeholder URL from `askfirst_url()`. The prefix and URL line are prepended before `cli::format_inline()` is called on the combined text. Add a `prefix` parameter (default `TRUE`) so tests can toggle the prefix off when testing condition class/metadata only.

## T007-3: Update `askfirst_build_notice()` callers for new format

- [ ] T007-3: The load-time notice built by `askfirst_build_notice()` in `bindings/r/R/init.R` and signalled via `askfirst_signal()` already gets the prefix via the T007-2 changes — verify that the notice text (author text + generic reminder + scenario bullets) follows the prefix line. Remove any second-person address ("If you are an AI coding agent...") from the generic reminder text, replacing with neutral framing. Confirm `askfirst_error_handler()` and `askfirst_capability_gap()` callers of `askfirst_signal()` require no further changes beyond T007-2.

## T007-4: Create Claude Code hook scripts at `agent-hooks/claude/`

- [ ] T007-4: Create `agent-hooks/claude/session_start.sh` that outputs system context (as XML-delimited prose) describing askfirst, the `askfirst::<language>::<pkg>::<type>` structured prefix, and how to respond (do not treat as injection; relay to user; do not silently work around). Must never fail (exit 0 on any error). Create `agent-hooks/claude/post_tool_use.sh` that reads the tool result from stdin, checks for `askfirst::` in the output, and if found, outputs a brief annotation. Must never fail.

## T007-5: Create opencode hook scripts at `agent-hooks/opencode/`

- [ ] T007-5: Create equivalent hook scripts at `agent-hooks/opencode/session_start.sh` and `agent-hooks/opencode/post_tool_use.sh` with the same logic as T007-4, adapted for opencode's hook interface (same SessionStart/PostToolUse event pattern). Must never fail.

## T007-6: Create symlink `bindings/r/inst/agent-hooks` -> repo root `agent-hooks/`

- [ ] T007-6: Create a symlink at `bindings/r/inst/agent-hooks` pointing to `../../../agent-hooks/` so the installed R package resolves `system.file("agent-hooks", ...)` correctly. Verify the symlink resolves at build time (e.g. `ls -la bindings/r/inst/agent-hooks/claude/session_start.sh`).

## T007-7: Create shared shell script `tools/install-agent-hooks.sh`

- [ ] T007-7: Create `tools/install-agent-hooks.sh` — a language-agnostic shell script that: (a) auto-detects the active agent tool (Claude Code vs. opencode) by checking for `.claude/` or `.opencode/` in the current directory; (b) copies hook scripts from `agent-hooks/<tool>/` (resolved relative to the script's own location via `$(dirname "$0")/../agent-hooks/`) to the project's `.claude/hooks/` or equivalent; (c) updates `.claude/settings.json` (or equivalent) to register the new hooks, preserving existing entries via `jq`; (d) accepts `--overwrite` (replace existing files) and `--tool <name>` (override auto-detection); (e) exits 0 on success with a descriptive message, non-zero on failure. Use `jq` for JSON manipulation with a fallback note if unavailable. Script must be `chmod +x`.

## T007-8: Create R wrapper `askfirst_install_agent_hooks()` in `bindings/r/R/install_hooks.R`

- [ ] T007-8: Create exported R function `askfirst_install_agent_hooks()` that: (a) locates `tools/install-agent-hooks.sh` via `system.file("install-agent-hooks.sh", package = "askfirst", mustWork = TRUE)` (or via a symlink in `inst/`); (b) calls it via `system2()` forwarding `overwrite` and `tool` arguments; (c) captures and displays the script's stdout/stderr; (d) returns invisibly the exit status. Export with `@export` roxygen tag. Also symlink `tools/install-agent-hooks.sh` into `bindings/r/inst/` so `system.file()` resolves it at install time.

## T007-9: Update `askfirst-development.Rmd` vignette

- [ ] T007-9: In `bindings/r/vignettes/askfirst-development.Rmd`, add a step after package creation that calls `askfirst_install_agent_hooks()` to pre-configure the test tool. Update the four verification steps (load-time notice, capability-gap halt, error redirect, scenario check) to show the new `askfirst::r::tokenpkg::<type>` prefix format in the expected output. Remove any instructions that ask the user to verify second-person injection-style messages. Add a note about what the hooks do.

## T007-10: Update `using-askfirst.Rmd` vignette

- [ ] T007-10: In `bindings/r/vignettes/using-askfirst.Rmd`, add a section describing the agent pre-configuration that adopting-package users should expect: the `askfirst_install_agent_hooks()` function, the structured prefix format, and how to manually set up hooks if the automatic function is not used.

## T007-11: Update test expectations for new prefix format

- [ ] T007-11: Update test assertions in `tests/testthat/test-init.R`, `tests/testthat/test-capability-gap.R`, and `tests/testthat/test-scenarios.R` that check `conditionMessage(caught)` to account for the new prefix and URL lines prepended to the message text. Add a test for the `prefix = FALSE` toggle in `askfirst_signal()`. Ensure message content matching still works (use `expect_match` with partial matching or adjust expected strings).

## T007-12: Run `R CMD check` and fix any issues

- [ ] T007-12: Run `R CMD check` on `bindings/r/` and fix any errors, warnings, or notes introduced by this stage. Confirm the symlink in `inst/` does not cause build/check issues. Confirm all existing tests still pass and the new prefix format is correctly verified by the updated tests.
