---
created: 2026-07-28T11:55:00Z
agent: claude-sonnet-5
git_hash: 8906541ebc8774d06b7e1595d13c128532bbb2a7
---

# Tasks: recover-swallowed-stderr-signals

## T015-1: Rework prefix/type/delimiter assembly in `askfirst_signal()`
- [x] T015-1: In `bindings/r/R/conditions.R`, change `prefix_line` from `askfirst::{lang}::{pkg}::{type}` to `askfirst::{lang}::{pkg}::{directive}` (directive first, i.e. `stop-and-ask` or `notice`), and replace the old `directive_line <- sprintf("directive: %s", ...)` with a `type_line <- sprintf("type: %s", type)` occupying the position immediately after the prefix line in `header`. Rename `askfirst_stop_start_delimiter`/`askfirst_stop_end_delimiter` constants' values to `<<<ASKFIRST:HALT>>>` / `<<<ASKFIRST:RESUME>>>` respectively (keep the object names, or rename consistently — check both definition and every call site in this file). Leave `askfirst_stop_consequence()`'s wording unchanged.

## T015-2: Update `askfirst_notice_prime()` for the new token
- [x] T015-2: In `bindings/r/R/conditions.R`, update `askfirst_notice_prime()`'s hard-coded reference to the old `"----- ASKFIRST AGENT STOP -----"` prose text so it instead references `<<<ASKFIRST:HALT>>>` (the constant from T015-1, not a re-typed literal).

## T015-3: Add stdout duplication for stop-and-ask signals
- [x] T015-3: In `askfirst_signal()` (`bindings/r/R/conditions.R`), after `formatted` is assembled and before the `rlang::abort()`/`rlang::inform()` call, add an unconditional `cat(formatted, "\n\n", sep = "", file = stdout())` gated on `identical(directive_map[[class]], "stop-and-ask")`. Do not duplicate `notice`-directive messages to stdout.

## T015-4: Create `bindings/r/R/log.R` with sentinel/log primitives
- [x] T015-4: Create `bindings/r/R/log.R` with three internal (`@noRd`, `@keywords internal`) functions: `askfirst_log_notice(pkg, formatted)` — appends `formatted` to `.askfirst/log` (creating `.askfirst/` via `dir.create(..., recursive = TRUE, showWarnings = FALSE)` if needed), relative to `getwd()`; `askfirst_write_pending(pkg, type, formatted)` — writes `formatted` to `.askfirst/pending/{pkg}-{type}.txt` (creating the `pending/` directory as needed), overwriting any existing file of the same name so a repeat signal from the same package/type de-duplicates rather than accumulates; `askfirst_silence_notice_active(pkg)` — returns `TRUE` if `Sys.getenv("ASKFIRST_SILENCE_NOTICE")`, split on commas and trimmed, contains `pkg` or the literal `"all"`, else `FALSE` (empty env var → `FALSE`).

## T015-5: Wire notice logging + `ASKFIRST_SILENCE_NOTICE` gating
- [x] T015-5: In `askfirst_signal()`, for the `notice`-directive branch (i.e. `class == "askfirst_notice"`), call `askfirst_log_notice(pkg, formatted)` unless `askfirst_silence_notice_active(pkg)` is `TRUE`. `stop-and-ask` signals must never consult `askfirst_silence_notice_active()` — they are never silenceable.

## T015-6: Wire pending-sentinel writing for stop-and-ask signals
- [x] T015-6: In `askfirst_signal()`, alongside the T015-3 stdout duplication, call `askfirst_write_pending(pkg, type, formatted)` unconditionally for every `stop-and-ask`-directive class, before the `rlang::abort()`/`rlang::inform()` call (so the sentinel is written even in the halting `call_stop = TRUE` case, which does not return normally).

## T015-7: Resolve open question — opencode hook blocking support
- [x] T015-7: Before implementing T015-8, check opencode's own hook documentation (as flagged in `plan.md`'s Open Questions) to confirm whether opencode's `PostToolUse`-equivalent hook supports a blocking response, and if so whether it follows Claude Code's exit-code-2/stderr-as-reason convention, the `{"decision": "block", "reason": ...}` JSON convention, or a different one entirely. Record the finding as a short comment in `agent-hooks/opencode/post_tool_use.sh` (T015-9) so the divergence, if any, is documented at the point it matters.

## T015-8: Block on pending sentinels in `post_tool_use.sh` (claude)
- [x] T015-8: In `agent-hooks/claude/post_tool_use.sh`, extract `.cwd` from the JSON payload (`jq -r '.cwd // ""'`). If `"$cwd/.askfirst/pending/"` contains any files, concatenate their contents as the blocking reason and exit with the Claude Code blocking convention (exit code 2, reason on stderr, per `plan.md`'s confirmed PostToolUse blocking behavior). Keep the existing (non-blocking) `.askfirst/log` detection/annotation behavior for notices, now reading from `"$cwd/.askfirst/log"` instead of the tool-result payload, and clear the log file after reading it. Bump the `# askfirst-hook-version:` marker at the top of the file to `2`.

## T015-9: Mirror `post_tool_use.sh` change to opencode
- [x] T015-9: Apply the same change from T015-8 to `agent-hooks/opencode/post_tool_use.sh`, using whichever blocking convention T015-7 determined is correct for opencode (falling back to the Claude Code convention with a documenting comment if opencode's docs don't specify one, per the plan's fallback framing). Bump its `# askfirst-hook-version:` marker to `2`. Keep this file byte-identical to `agent-hooks/claude/post_tool_use.sh` unless T015-7 found a genuine protocol divergence — if so, note the divergence in both files' headers.

## T015-10: Add `user_prompt_submit.sh` hook (claude + opencode)
- [x] T015-10: Create `agent-hooks/claude/user_prompt_submit.sh`: on each new user turn, remove all files under `"$cwd/.askfirst/pending/"` (extracting `.cwd` from the payload the same way as `post_tool_use.sh`), never failing the turn (same `main 2>/dev/null || true` pattern as the other hooks), with `# askfirst-hook-version: 2`. Copy byte-identical to `agent-hooks/opencode/user_prompt_submit.sh`.

## T015-11: Update `session_start.sh` context (claude + opencode)
- [x] T015-11: Update `agent-hooks/claude/session_start.sh`'s `<askfirst-context>` block to describe: the new prefix format (`askfirst::{lang}::{pkg}::{directive}` first, with a `type:` line for the finer-grained signal class), the new `<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>` token pair replacing the old prose markers, and the persistent-sentinel/active-blocking behavior (a `stop-and-ask` signal stays blocking across subsequent tool calls until the user's next message clears it — so the agent cannot simply wait it out or move to unrelated work). Bump `# askfirst-hook-version:` to `2`. Mirror the same edit to `agent-hooks/opencode/session_start.sh` (byte-identical).

## T015-12: Extend `tools/generate-install-hooks.sh` for the third hook
- [x] T015-12: In `tools/generate-install-hooks.sh`, add a `USER_PROMPT_SRC` variable pointing at `agent-hooks/claude/user_prompt_submit.sh`, include it in the existence check loop, and extend the `awk` script with a third heredoc-splice case (`<<.USER_PROMPT_HOOK.$` marker) mirroring the existing `SESSION_HOOK`/`POST_HOOK` cases.

## T015-13: Extend `tools/install-agent-hooks.sh` to install/register the third hook
- [x] T015-13: In `tools/install-agent-hooks.sh`, add a `write_user_prompt_submit()` function (mirroring `write_session_start`/`write_post_tool_use`) that writes to `$1/user_prompt_submit.sh` inside a `USER_PROMPT_HOOK` heredoc placeholder (to be filled by T015-12/T015-14), `chmod +x`, and is called alongside the other two `write_*` calls. Extend `register_hooks_claude()` and `register_hooks_opencode()` to also add a `hooks.UserPromptSubmit` entry (`[{"hooks": [{"type": "command", "command": "<hooks_dir>/user_prompt_submit.sh"}]}]`) via the existing `jq` pipeline pattern.

## T015-14: Regenerate `install-agent-hooks.sh` and update the manifest
- [x] T015-14: Run `tools/generate-install-hooks.sh` to splice the real `agent-hooks/claude/{session_start,post_tool_use,user_prompt_submit}.sh` contents into `tools/install-agent-hooks.sh`'s heredocs, replacing the placeholders from T015-13. Bump `hook_version` to `2` in `agent-hooks/manifest.json`, and update the hand-maintained copy in `bindings/r/R/hooks_status.R`'s `askfirst_hooks_manifest()` to match (both `hook_version` and any new fields needed for the third hook file, if `askfirst_hooks_status_for_tool()`'s staleness check should also depend on `user_prompt_submit.sh`'s presence/version — decide during implementation whether checking `session_start.sh`'s version alone remains sufficient given all three files now share one version number).

## T015-15: Update `install_hooks.R` docs for the third hook
- [x] T015-15: In `bindings/r/R/install_hooks.R`, update `askfirst_install_agent_hooks()`'s roxygen description ("Installs SessionStart and PostToolUse hooks...") to also mention the new `UserPromptSubmit` hook.

## T015-16: Update existing test literals for the new format
- [x] T015-16: In `bindings/r/tests/testthat/test-init.R`, update the assertions at lines ~216-217, ~235-240, and ~257-261 (`expect_match`/`expect_no_match` against `"askfirst::r::mypkg::notice"`, `"directive: notice"`, the old prose delimiter strings, `"askfirst::r::mypkg::capability_gap"`, `"directive: stop-and-ask"`) to match the new prefix ordering (`askfirst::r::mypkg::notice` / `askfirst::r::mypkg::stop-and-ask`), the new `type:` line, and the new `<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>` tokens in place of the old prose delimiters.

## T015-17: Update `test-install-agent-hooks.R` for the third embedded hook
- [x] T015-17: In `bindings/r/tests/testthat/test-install-agent-hooks.R`, extend `extract_heredoc_body()` usage and the first `test_that` block to also compare the embedded `USER_PROMPT_HOOK` body against `agent-hooks/claude/user_prompt_submit.sh`, and extend the second `test_that` block to also assert `agent-hooks/claude/user_prompt_submit.sh` and `agent-hooks/opencode/user_prompt_submit.sh` are byte-identical.

## T015-18: Add new sandboxed tests for sentinel/log/silencing behavior
- [x] T015-18: Add tests (new file `bindings/r/tests/testthat/test-log.R`, or appended to `test-init.R` if more natural given existing high-confidence signal setup there) covering: `askfirst_write_pending()` creates `.askfirst/pending/{pkg}-{type}.txt` with the expected content and overwrites on a repeat call rather than accumulating a second file; `askfirst_silence_notice_active()` correctly parses comma-separated `ASKFIRST_SILENCE_NOTICE` values and the `"all"` sentinel; a `notice`-directive `askfirst_signal()` call does not append to `.askfirst/log` when `ASKFIRST_SILENCE_NOTICE` covers its `pkg`; a `stop-and-ask`-directive `askfirst_signal()` call writes to stdout (capture via `testthat::capture_output()` or `evaluate::evaluate()`) in addition to signalling the condition, and writes a `.askfirst/pending/` file regardless of `ASKFIRST_SILENCE_NOTICE`. Every test that triggers real signal emission must wrap its working directory in `withr::local_dir(withr::local_tempdir())`, per this stage's test-hygiene goal and the `askfirst_hooks_status()` precedent from stage 014.

## T015-19: Full regeneration and test run
- [x] T015-19: After all R and shell changes land, re-run `tools/generate-install-hooks.sh` once more (idempotency check — should produce no diff if T015-14 already ran it correctly), run `devtools::document()` in `bindings/r/` to refresh any roxygen output touched by docstring edits, then run the full `testthat` suite (`devtools::test()` or `R CMD check`) and confirm all tests pass, including the newly updated/added ones from T015-16/T015-17/T015-18.
