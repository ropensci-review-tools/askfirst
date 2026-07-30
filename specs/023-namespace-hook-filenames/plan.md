---
created: 2026-07-30T11:47:31Z
agent: claude-sonnet-5
git_hash: d0df6b573ac09b2d93d57deebb58ca33829acb7d
---

# Plan: namespace-hook-filenames

## Overview
Rename askfirst's Claude Code hook script files (.claude/hooks/session_start.sh, post_tool_use.sh, user_prompt_submit.sh) to askfirst-namespaced filenames (askfirst-session-start.sh, askfirst-post-tool-use.sh, askfirst-user-prompt-submit.sh), so install-agent-hooks.sh can never silently clobber or skip another tool's same-named hook script occupying the same generic, conventional filename in a shared .claude/hooks/ directory

## Context

**Source of this stage:** a user report that `.claude/hooks/` filenames
askfirst writes (`session_start.sh`, `post_tool_use.sh`,
`user_prompt_submit.sh`) are generic, conventional names that may already
be occupied by an unrelated tool's own hook scripts. Confirmed concretely
against this very repo: `.claude/hooks/session_start.sh` and
`post_tool_use.sh` here already belong to `designlens` itself (registered
in the committed `.claude/settings.json`), not askfirst. Running
askfirst's installer in a project like this one today would either
silently clobber designlens's hook scripts entirely (with `--overwrite`)
or silently skip installing askfirst (without it) — `write_session_start`/
`write_post_tool_use`/`write_user_prompt_submit` in
`agent-hooks/install-agent-hooks.sh` (~lines 104-110, 227-230, 370-373) do
a wholesale `cat > "$target"` to these hardcoded generic paths, with no
awareness of what tool (if any) already owns the file at that path.

**Verified before scoping the fix:** Claude Code has no filename-
convention-based hook discovery (unlike git's `.git/hooks/pre-commit`
pattern) — hooks are dispatched purely from the explicit `"command"`
string registered under each event key (`SessionStart`, `PostToolUse`,
`UserPromptSubmit`) in `.claude/settings.json`. Confirmed against official
Claude Code hooks documentation (via the claude-code-guide agent) and
against this repo's own `.claude/settings.json`, which maps each event key
to an arbitrary command path. Also verified none of askfirst's three hook
scripts derive behavior from their own filename (no `$0`/`basename` self-
reference; the one `basename` call in `post_tool_use.sh` extracts a
package name from a state-marker file, unrelated to the hook script's own
name) and that cross-references between the scripts
(`post_tool_use.sh`/`user_prompt_submit.sh`) are documentation comments
only, not executable dependencies. This means the temporal sequence
implied by the current names (session-start vs. per-tool-call vs.
per-user-turn) is governed entirely by which event key each script is
registered under, not by its filename — so renaming the files (while
registering the same event-key mapping under the new path) preserves
identical firing order and behavior.

**Filename dependents found in the codebase** (all needing the
corresponding update, not just the installer itself):
`agent-hooks/manifest.json` (`marker_file: "session_start.sh"`, the
authoritative version-marker file for `askfirst_hooks_status()`),
`bindings/r/R/hooks_status.R` (hardcodes the same value as manifest.json's
in-package fallback copy), `bindings/r/tests/testthat/test-hooks-status.R`
and `test-install-agent-hooks.R` and `test-init.R` (test fixtures/
assertions referencing the filenames), `agent-hooks/generate-install-hooks.sh`
(splices `agent-hooks/claude/*.sh` into `install-agent-hooks.sh`'s embedded
heredocs — the source files themselves need renaming too, at
`agent-hooks/claude/`), and doc-only prose in `bindings/r/R/log.R`,
`bindings/r/R/state.R`, and `bindings/r/vignettes/askfirst-development.Rmd`.
opencode's side is already namespaced (`askfirst-plugin.js` under
`.opencode/plugins/`) and is out of scope for this stage.

## Design Goals
- Eliminate the possibility of askfirst's installer silently destroying or
  being blocked by another tool's hook script that happens to occupy the
  same conventional filename in `.claude/hooks/`, by giving askfirst's own
  three Claude Code hook scripts askfirst-namespaced filenames:
  `askfirst-session-start.sh`, `askfirst-post-tool-use.sh`,
  `askfirst-user-prompt-submit.sh`.
- Preserve identical runtime behavior: same event-key registration
  (`SessionStart`/`PostToolUse`/`UserPromptSubmit`), same script contents,
  same firing order and timing — only the filename and the registered
  `command` path change.
- Keep `askfirst_hooks_status()`'s version-detection mechanism working
  against the new filename, by updating `agent-hooks/manifest.json`'s and
  `hooks_status.R`'s `marker_file` value in lockstep.
- No migration/cleanup logic for pre-existing installs at the old generic
  filenames — a fresh `install-agent-hooks.sh` run is sufficient; users on
  stale installs re-run the installer to get the new namespaced files.

## Proposed Approach
1. Rename the canonical source scripts:
   `agent-hooks/claude/session_start.sh` →
   `agent-hooks/claude/askfirst-session-start.sh` (and equivalently for
   `post_tool_use.sh`/`user_prompt_submit.sh`).
2. Update `agent-hooks/install-agent-hooks.sh`'s `write_session_start`/
   `write_post_tool_use`/`write_user_prompt_submit` functions to target
   the new `.claude/hooks/askfirst-*.sh` paths, and update
   `register_hooks_claude`'s hardcoded `"command"` strings to match.
3. Update `agent-hooks/manifest.json`'s `marker_file` field (and its
   explanatory `_comment`) and `bindings/r/R/hooks_status.R`'s matching
   hardcoded fallback to `"askfirst-session-start.sh"`.
4. Run `agent-hooks/generate-install-hooks.sh` to re-splice the renamed
   canonical sources into `install-agent-hooks.sh`'s embedded heredocs
   (the heredoc marker tokens `SESSION_HOOK`/`POST_HOOK`/
   `USER_PROMPT_HOOK` themselves are unaffected — only the target path
   each heredoc body gets written to changes, in the surrounding
   `write_*` functions from step 2).
5. Update tests referencing the old filenames
   (`test-install-agent-hooks.R`, `test-hooks-status.R`, `test-init.R`) to
   the new names, and add a regression test asserting the installer does
   not touch a pre-existing, non-askfirst file at any of the old generic
   paths (`session_start.sh`, `post_tool_use.sh`, `user_prompt_submit.sh`)
   when installing.
6. Update doc-only prose referencing the old filenames in
   `bindings/r/R/log.R`, `bindings/r/R/state.R`, and
   `bindings/r/vignettes/askfirst-development.Rmd` for accuracy.

## Open Questions
- None outstanding — filename-independence (both Claude Code's dispatch
  and the scripts' own internal logic) was verified before this plan was
  written, and migration scope was explicitly resolved as out of scope.
