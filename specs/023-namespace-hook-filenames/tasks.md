---
created: 2026-07-30T11:51:29Z
agent: claude-sonnet-5
git_hash: d0df6b573ac09b2d93d57deebb58ca33829acb7d
---

# Tasks: namespace-hook-filenames

## T023-1: Rename the canonical Claude Code hook source scripts
- [x] T023-1: Rename `agent-hooks/claude/session_start.sh` →
  `agent-hooks/claude/askfirst-session-start.sh`,
  `agent-hooks/claude/post_tool_use.sh` →
  `agent-hooks/claude/askfirst-post-tool-use.sh`, and
  `agent-hooks/claude/user_prompt_submit.sh` →
  `agent-hooks/claude/askfirst-user-prompt-submit.sh` (via `git mv` to
  preserve history). Do not change file contents in this task — only the
  filenames. Update any comments inside these files that reference their
  own or a sibling script's old filename (e.g.
  `askfirst-user-prompt-submit.sh`'s comment referencing
  "`post_tool_use.sh`") to the new names.

## T023-2: Update install-agent-hooks.sh's write functions and registration to target the new paths
- [x] T023-2: In `agent-hooks/install-agent-hooks.sh`:
  - `write_session_start()`, `write_post_tool_use()`,
    `write_user_prompt_submit()` (~lines 104, 227, 370) must target
    `"$1/askfirst-session-start.sh"`, `"$1/askfirst-post-tool-use.sh"`,
    `"$1/askfirst-user-prompt-submit.sh"` respectively, instead of the old
    generic paths. Update each function's own "skip: ... exists" message
    text accordingly (paths are interpolated via `$target`, so this should
    require no separate text change beyond the path itself).
  - `register_hooks_claude()` (~lines 713-720): update the three hardcoded
    `"command"` strings (`.claude/hooks/session_start.sh`,
    `.claude/hooks/post_tool_use.sh`,
    `.claude/hooks/user_prompt_submit.sh`) in both the
    `SessionStart`-exists and `SessionStart`-absent jq branches to the new
    `askfirst-*.sh` paths.
  - Do not change the heredoc marker tokens (`SESSION_HOOK`, `POST_HOOK`,
    `USER_PROMPT_HOOK`) themselves, or which function writes which heredoc
    body — only the target path each function writes to and the
    registered command string.

## T023-3: Update the version-marker filename in manifest.json and hooks_status.R
- [x] T023-3: In `agent-hooks/manifest.json`, change
  `tools.claude.marker_file` from `"session_start.sh"` to
  `"askfirst-session-start.sh"`, and update the `_comment` field's
  reference to `session_start.sh` to match. In
  `bindings/r/R/hooks_status.R`, update the hardcoded fallback
  `marker_file = "session_start.sh"` (in the in-package manifest copy) to
  `"askfirst-session-start.sh"`, and update the roxygen comment describing
  it (~line 19, referencing "`session_start.sh`, a
  `# askfirst-hook-version: <N>` shell comment").

## T023-4: Regenerate install-agent-hooks.sh from the renamed canonical sources
- [x] T023-4: Run `agent-hooks/generate-install-hooks.sh` to re-splice the
  renamed `agent-hooks/claude/askfirst-*.sh` files' bodies into
  `install-agent-hooks.sh`'s embedded `SESSION_HOOK`/`POST_HOOK`/
  `USER_PROMPT_HOOK` heredocs. Diff the regenerated `install-agent-hooks.sh`
  to confirm only the heredoc bodies' content (reflecting T023-1's comment
  updates) changed as expected, and that T023-2's target-path/command-string
  edits (outside the heredocs) survived the regeneration intact.

## T023-5: Update tests referencing the old hook filenames
- [x] T023-5: Update `bindings/r/tests/testthat/test-hooks-status.R`,
  `test-install-agent-hooks.R`, and `test-init.R` (and any other test
  files found referencing `session_start.sh`, `post_tool_use.sh`, or
  `user_prompt_submit.sh` as literal filenames or path fragments) to use
  the new `askfirst-*.sh` names. Re-run the full R test suite after this
  change and confirm all pass.

## T023-6: Add a regression test asserting the installer never touches a pre-existing non-askfirst file at the old generic paths
- [x] T023-6: In `bindings/r/tests/testthat/test-install-agent-hooks.R`,
  add a test that: creates a temp directory with
  `.claude/hooks/session_start.sh` and `.claude/hooks/post_tool_use.sh`
  pre-populated with unrelated, non-askfirst content (simulating another
  tool's hook scripts, e.g. modeled on this repo's own
  `.claude/hooks/session_start.sh`/`post_tool_use.sh` belonging to
  designlens); runs `install-agent-hooks.sh --tool claude`; and asserts
  those two files are byte-identical to their pre-existing content
  afterward (untouched), while `.claude/hooks/askfirst-session-start.sh`,
  `askfirst-post-tool-use.sh`, and `askfirst-user-prompt-submit.sh` are
  newly created and registered in `.claude/settings.json` alongside the
  pre-existing entries (not replacing them).

## T023-7: Update doc-only prose referencing the old filenames
- [x] T023-7: Update references to the old filenames in
  `bindings/r/R/log.R`, `bindings/r/R/state.R` (roxygen comments), and
  `bindings/r/vignettes/askfirst-development.Rmd` to the new
  `askfirst-*.sh` names, for documentation accuracy.

## T023-8: Run the full test suite and confirm no regressions
- [x] T023-8: Run the full R package test suite
  (`devtools::test()`/equivalent in `bindings/r/`), confirming all pass
  with no new failures. Confirm `git status` shows only the expected
  changed/renamed files: the three renamed
  `agent-hooks/claude/askfirst-*.sh` files, `agent-hooks/install-agent-hooks.sh`,
  `agent-hooks/manifest.json`, `bindings/r/R/hooks_status.R`,
  `bindings/r/R/log.R`, `bindings/r/R/state.R`,
  `bindings/r/vignettes/askfirst-development.Rmd`, and the test files
  touched in T023-5/T023-6.
