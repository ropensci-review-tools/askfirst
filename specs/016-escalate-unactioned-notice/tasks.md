---
created: 2026-07-28T13:33:20Z
agent: claude-sonnet-5
git_hash: 1c0f92128de0efe81c2d4217b0cb7261e3ea1916
---

# Tasks: escalate-unactioned-notice

## T016-1: Shared helper computing the tmp state root (R side)
- [ ] T016-1: In `bindings/r/R/state.R` (or a new `bindings/r/R/state_dir.R`
  if that reads more cleanly), add `askfirst_state_dir()`: returns
  `file.path(Sys.getenv("TMPDIR", unset = "/tmp"), "askfirst", askfirst_mangle_path(getwd()))`,
  and a helper `askfirst_mangle_path(path)` implementing the agreed
  mangling scheme -- strip a leading `/` and replace remaining `/` with
  `_` (literal, not hashed, per the maintainer's explicit choice to keep
  the path human-debuggable). Do not call `normalizePath()` or otherwise
  resolve symlinks -- the bash side has no equivalent resolution step
  available to it, and introducing asymmetric normalization would make the
  two sides silently diverge for any project path involving a symlink.
  Document with `@keywords internal`/`@noRd` that this is the single
  source of truth for where `log`, `pending/`, and `unresolved-notice/`
  live, replacing the previous `.askfirst/`-relative-to-`getwd()` location
  from stage 015.

## T016-2: Migrate the existing log/pending mechanism to the new root
- [ ] T016-2: In `bindings/r/R/log.R`, update `askfirst_log_notice()` and
  `askfirst_write_pending()` to write under
  `file.path(askfirst_state_dir(), "log")` and
  `file.path(askfirst_state_dir(), "pending", sprintf("%s-%s.txt", pkg, type))`
  respectively, replacing the current `.askfirst`-relative-to-`getwd()`
  paths. Preserve all existing behavior otherwise (append semantics for
  `log`, one-file-per-`{pkg}-{type}` de-duplication for `pending/`).

## T016-3: Add write/clear helpers for the new "unresolved notice" marker
- [ ] T016-3: In `bindings/r/R/log.R`, add
  `askfirst_write_unresolved_notice(pkg, formatted)` (writes/overwrites
  `file.path(askfirst_state_dir(), "unresolved-notice", paste0(pkg, ".txt"))`,
  creating parent directories as needed) and
  `askfirst_clear_unresolved_notice(pkg)` (removes that file if present; a
  no-op, not an error, if it doesn't exist). Document both as the third
  state category, distinct from `log` (one-shot, cleared by the very next
  tool call) and `pending/` (blocking, cleared only by a new user turn):
  this one persists across multiple tool calls and turns, cleared only by
  an explicit resolution (a scenario-check call, or a stop-and-ask
  firing), never merely by time or turn passing.

## T016-4: Write the marker when a notice fires without a prior resolution
- [ ] T016-4: In `bindings/r/R/conditions.R`, inside `askfirst_signal()`'s
  existing notice branch (the `else if (!askfirst_silence_notice_active(pkg))`
  block that currently calls `askfirst_log_notice(pkg, formatted)`), add a
  call to `askfirst_write_unresolved_notice(pkg, formatted)` right
  alongside it, gated on the same `!askfirst_silence_notice_active(pkg)`
  condition (a silenced notice shouldn't newly open an escalation either).
  Writing is idempotent (overwrites), so no need to check whether a marker
  already exists for `pkg` before writing.

## T016-5: Clear the marker on a scenario-check call, at every confidence tier
- [ ] T016-5: In `bindings/r/R/scenarios.R`, at the top of
  `askfirst_check_scenarios()` (before the `confidence <- askfirst_ensure_detection()`
  branch that decides whether to signal), add an unconditional call to
  `askfirst_clear_unresolved_notice(pkg)`. This must run regardless of the
  session's confidence tier -- a human or low-confidence caller invoking
  this function deliberately also represents the self-check having
  happened.

## T016-6: Clear the marker when a real stop-and-ask gate fires
- [ ] T016-6: In `bindings/r/R/conditions.R`, inside `askfirst_signal()`,
  add a call to `askfirst_clear_unresolved_notice(pkg)` in the
  `stop-and-ask` branch (i.e. whenever `directive_map[[class]]` is
  `"stop-and-ask"`), so that any of `askfirst_capability_gap()`,
  `askfirst_check_scenarios()`'s own halt, or an `error_redirect` firing
  for `pkg` supersedes and clears a previously-open reminder for that same
  package.

## T016-7: Unit tests for the state-root helper and the full marker lifecycle
- [ ] T016-7: Add tests for `askfirst_state_dir()`/`askfirst_mangle_path()`
  (correct mangling of representative paths, including ones with multiple
  path separators). Update `bindings/r/tests/testthat/test-log.R` for the
  relocated `askfirst_log_notice()`/`askfirst_write_pending()` (assert
  against the new tmp-root path, not a `.askfirst`-relative one) and add
  tests for `askfirst_write_unresolved_notice()`/
  `askfirst_clear_unresolved_notice()`. In `test-scenarios.R`, add a test
  asserting that calling `askfirst_check_scenarios(pkg)` removes an
  existing marker file, at both low/medium and high confidence. In
  `test-capability-gap.R` (or wherever `askfirst_signal()`'s stop-and-ask
  branch is most directly exercised), add a test asserting a
  `stop-and-ask`-directive signal clears an already-existing marker for
  the same package. Because `askfirst_state_dir()` now resolves to a path
  under the *real* system tmp root (derived from whatever tempdir
  `helper-state.R`'s `local_reset_askfirst_state()` sandboxes `getwd()`
  into, not nested inside that sandboxed tempdir itself), every test that
  exercises these code paths must clean up the tmp-root directory it
  creates via `withr::defer(unlink(askfirst_state_dir(), recursive = TRUE))`
  (or equivalent), so repeated test runs don't accumulate stray directories
  under the real `/tmp`. Consider adding this cleanup once, centrally, to
  `local_reset_askfirst_state()` itself rather than repeating it in every
  test.

## T016-8: Relocate the bash-side state paths and add the mangling function
- [ ] T016-8: In `agent-hooks/claude/post_tool_use.sh` and
  `agent-hooks/claude/user_prompt_submit.sh`, add a shared bash function
  (duplicated identically in both files, consistent with how these scripts
  already duplicate their `cwd`-extraction logic) implementing the same
  mangling scheme as T016-1: strip a leading `/` from the payload's `cwd`
  value and replace remaining `/` with `_`, then build
  `"${TMPDIR:-/tmp}/askfirst/<mangled>"`. Replace every existing
  `"$cwd/.askfirst/pending"` and `"$cwd/.askfirst/log"` reference with the
  new computed root's `pending`/`log` subpaths. `user_prompt_submit.sh`'s
  `rm -rf "$cwd/.askfirst/pending"` becomes `rm -rf` on the relocated
  `pending` subpath under the new root.

## T016-9: Escalating reminder logic in the Claude Code PostToolUse hook
- [ ] T016-9: In `agent-hooks/claude/post_tool_use.sh`, after the existing
  pending-block check and before (or alongside) the existing log flush
  (both now reading from the relocated tmp-root paths per T016-8), add
  logic that: (a) parses the tool name from the hook payload (Claude
  Code's `PostToolUse` payload includes a `tool_name` field -- confirm the
  exact field name against Claude Code's hook documentation or existing
  payload samples if available); (b) if `tool_name` matches a
  file-modifying tool (`Edit`, `Write`, `NotebookEdit`) and the relocated
  `unresolved-notice/` subdirectory contains any files, appends a reminder
  block to the non-blocking annotation output naming each still-open
  package and restating the instruction to call
  `askfirst::askfirst_check_scenarios('pkg')` before proceeding if the
  edit duplicates/extends that package's functionality. Track a
  per-package repeat count (e.g. a companion counter file under a
  `unresolved-notice-count/<pkg>.txt` subpath of the same state root,
  incremented by this script each time it fires the reminder for that
  package) so the reminder text escalates from a level-1 phrasing (first
  1-2 occurrences) to a firmer level-2 phrasing after a small fixed
  threshold (e.g. 3 occurrences) -- exact wording and threshold are
  implementation-time choices, but must never repeat verbatim identical
  text indefinitely, per stage 015's own rationale that identical repeated
  text trains an agent to stop reading it. This addition must remain
  non-blocking: it always falls through to `exit 0` regardless of whether
  a reminder was appended.

## T016-10: Confirm and implement the opencode equivalent
- [ ] T016-10: Investigate opencode's actual `PostToolUse`-equivalent
  payload shape for file-modifying tool calls (its plugin API is a
  `tool.execute.before/after` interface per stage 015's own findings, not
  necessarily identical field names to Claude Code's `tool_name`) -- check
  the vendored `.opencode/node_modules`/`.opencode/tools` in this repo's
  own dev setup, or opencode's own documentation, for the real field
  name(s) and tool-name values for edit/write operations. Then apply the
  same relocation (T016-8) and escalation logic (T016-9) to
  `agent-hooks/opencode/post_tool_use.sh` and
  `agent-hooks/opencode/user_prompt_submit.sh`, adapted only where
  opencode's payload genuinely differs from Claude Code's. If
  investigation finds no reliable way to detect file-modifying tool calls
  or to inject non-blocking output on opencode at all, document that
  limitation explicitly in the script's header comment (matching the
  existing "unverified fallback" comment style stage 015 used for the
  blocking convention) rather than silently shipping a no-op.

## T016-11: Broaden the Claude Code PostToolUse matcher to include file edits
- [ ] T016-11: In `tools/install-agent-hooks.sh`'s `register_hooks_claude()`
  function, change the `PostToolUse` matcher from the current
  `"Bash|R|Rscript"` to also include `Edit`, `Write`, and `NotebookEdit`
  (e.g. `"Bash|R|Rscript|Edit|Write|NotebookEdit"`), since the hook script
  will otherwise never even be invoked for the Edit/Write calls this
  stage's escalation depends on. Note in a comment that this also
  retroactively closes a latent gap from stage 015: that stage's `log`
  one-shot notice was documented as flushed "on the next tool call," but
  the matcher as originally written would silently skip that flush
  whenever the very next tool call was an Edit/Write rather than a
  Bash/R/Rscript call. This repo's own local `.claude/settings.json` (used
  for dogfooding askfirst's own development) currently registers
  `"Write|Edit"` only, the mirror-image gap -- reconcile both toward the
  same, fuller matcher.

## T016-12: Determine whether opencode's matcher/config registration has any effect
- [ ] T016-12: `tools/install-agent-hooks.sh`'s `register_hooks_opencode()`
  writes a `matcher` field into `.opencode/settings.json`, but
  `askfirst-tests/AGENTS.md` states opencode "discovers hooks from
  `.opencode/hooks/` without needing them registered in a config file" and
  that `.opencode/settings.json` "does not exist as a real opencode config
  path." Confirm directly (opencode docs, or empirical test) whether this
  matcher registration has any real effect for opencode at all. If it does
  nothing, note that in a comment (matcher restriction is moot for
  opencode -- its hook fires on every tool call regardless, so T016-10's
  in-script `tool_name`/equivalent check is the only real gate). If it
  turns out to matter, apply the same broadening as T016-11 to
  `register_hooks_opencode()`.

## T016-13: Regenerate the embedded installer heredocs
- [ ] T016-13: After T016-8, T016-9, and T016-10's edits to
  `agent-hooks/claude/post_tool_use.sh`, `agent-hooks/claude/user_prompt_submit.sh`,
  and their `opencode/` counterparts (and any `session_start.sh` changes
  from T016-16) are finalized, run `tools/generate-install-hooks.sh` from
  the repo root and verify the regenerated `tools/install-agent-hooks.sh`
  heredoc bodies match the edited source files exactly. Commit the
  regenerated `tools/install-agent-hooks.sh` alongside the
  `agent-hooks/claude/*.sh` changes, per the existing convention noted in
  that script's own header comment.

## T016-14: Bump the hook version marker everywhere it's tracked
- [ ] T016-14: Increment the hook version from 2 to 3 in all of: the
  `# askfirst-hook-version: 2` comment line in
  `agent-hooks/claude/session_start.sh`, `agent-hooks/claude/post_tool_use.sh`,
  `agent-hooks/claude/user_prompt_submit.sh`, and their
  `agent-hooks/opencode/` counterparts; `agent-hooks/manifest.json`'s
  `"hook_version": 2` field; and `bindings/r/R/hooks_status.R`'s
  `askfirst_hooks_manifest()` function's `hook_version = 2L`. Keep all of
  these in sync manually, per the existing documented convention.

## T016-15: Update hook-status and installer tests for the new version
- [ ] T016-15: Update `bindings/r/tests/testthat/test-hooks-status.R` for
  the new `hook_version` value (3) wherever tests assert on
  `askfirst_hooks_manifest()` or construct fixture hook files with a
  specific version marker to test `"stale"` vs `"current"` status. Update
  `bindings/r/tests/testthat/test-install-agent-hooks.R` to assert the
  installed `post_tool_use.sh` carries the new version marker and targets
  the relocated tmp-root paths, and that the registered matcher now
  includes `Edit`/`Write`/`NotebookEdit` per T016-11/T016-12.

## T016-16: Update SessionStart hook context for the new location and tier
- [ ] T016-16: In both `agent-hooks/claude/session_start.sh` and
  `agent-hooks/opencode/session_start.sh`'s injected `<askfirst-context>`
  block: (a) correct the existing paragraph that currently says a
  stop-and-ask signal is "written to a persistent sentinel file under
  `.askfirst/pending/` in the project's working directory" -- this is now
  inaccurate and must instead describe the relocated, session-scoped tmp
  location; (b) add a new paragraph (near the existing point 4, "If you
  see `askfirst_check_scenarios()` mentioned, consider calling it...")
  explaining that if a `notice` fires and `askfirst_check_scenarios()` is
  not called before the next file edit, subsequent edits will carry an
  escalating, non-blocking reminder in the tool result until the check is
  made -- this is not a hard stop and does not block, but is a strong
  signal that the check has been skipped and should be made now if the
  edit in question duplicates/extends the flagged package's functionality.

## T016-17: Document the new mechanism and storage location in vignettes
- [ ] T016-17: Update `bindings/r/vignettes/using-askfirst.Rmd` to
  describe the new escalation tier alongside the existing explanation of
  `notice`/`stop-and-ask`/`askfirst_check_scenarios()`, so package authors
  adopting askfirst understand the full lifecycle: load-time notice ->
  (optional) agent-initiated scenario check -> hard stop, now with the new
  non-blocking PostToolUse reminder bridging the gap when the middle step
  is skipped. Update `bindings/r/vignettes/askfirst-development.Rmd` if it
  documents the hook mechanism or the `.askfirst/`-under-project-tree
  location at an implementation level -- both should now describe the
  relocated, session-scoped tmp storage instead (check its current
  contents before deciding what needs to change).

## T016-18: Reconcile this repo's own local dev hook installation
- [ ] T016-18: This repo's own `.claude/settings.json` (used to dogfood
  askfirst's own development) currently registers `PostToolUse` with
  matcher `"Write|Edit"` only, and its hook scripts are presumably from an
  earlier hook-version pointing at the pre-relocation `.askfirst/` paths.
  After T016-8-T016-14 land, re-run
  `tools/install-agent-hooks.sh --tool claude --overwrite` from the repo
  root to refresh `.claude/hooks/*.sh` to the new version and relocated
  paths, and reconcile `.claude/settings.json`'s matcher with whatever
  T016-11 decided, so this repo's own dev sessions actually exercise the
  new mechanism rather than running stale hooks against a location
  nothing writes to anymore.

## T016-19: Manual smoke-test verification for both agents
- [ ] T016-19: Before considering this stage complete, manually verify the
  end-to-end behavior once for each agent: trigger a `notice` (e.g. load
  an askfirst-adopting test package in a throwaway directory with hooks
  installed), skip calling `askfirst_check_scenarios()`, perform an
  Edit/Write-equivalent tool call, and confirm (a) the R process and the
  hook script actually agree on the same tmp-root path (e.g. by checking
  the marker file the R side wrote is the one the hook script reads), and
  (b) the escalating reminder appears in the tool result, for both Claude
  Code and opencode. This directly closes the plan's open verification
  questions -- both the R/bash path-derivation agreement and whether
  opencode's hook mechanism can even inject non-blocking output the way
  Claude Code's can -- rather than leaving them assumed. Record the
  outcome (works / doesn't work / partially works per agent) in
  `design-decisions.md` when this stage is retrospected.

## T016-20: Full test suite and package check
- [ ] T016-20: Run the full `bindings/r` test suite (`devtools::test()` or
  equivalent) and `R CMD check` (or `devtools::check()`) from
  `bindings/r/`, confirm no regressions from T016-1-T016-7's R-side
  changes, and fix any failures before this stage is considered done.
