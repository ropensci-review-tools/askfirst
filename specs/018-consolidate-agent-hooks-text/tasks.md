---
created: 2026-07-28T17:21:36Z
agent: claude-sonnet-5
git_hash: 410c1b799c3ef5a7210681bbe1743ed4b7dd1e67
---

# Tasks: consolidate-agent-hooks-text

## T018-1: Move tools/ files into agent-hooks/, remove tools/
- [ ] T018-1: Move `tools/install-agent-hooks.sh` to
  `agent-hooks/install-agent-hooks.sh` and `tools/generate-install-hooks.sh`
  to `agent-hooks/generate-install-hooks.sh` (`git mv` to preserve history).
  Remove the now-empty `tools/` directory. Do not edit either file's
  contents in this task — that happens in later tasks.

## T018-2: Update generate-install-hooks.sh's internal paths for the merge
- [ ] T018-2: In the relocated `agent-hooks/generate-install-hooks.sh`,
  update `REPO_ROOT`-relative path variables (`INSTALLER`, `SESSION_SRC`,
  `POST_SRC`, `USER_PROMPT_SRC`, `PLUGIN_SRC`) so `INSTALLER` now points at
  `$REPO_ROOT/agent-hooks/install-agent-hooks.sh` instead of
  `$REPO_ROOT/tools/install-agent-hooks.sh` (the other four already point
  at `agent-hooks/claude/*`/`agent-hooks/opencode/*`, unaffected by the
  move). Update the script's header comment, which currently references
  "`tools/install-agent-hooks.sh`", to the new path. Run it once now to
  confirm it still executes correctly from the new location (output
  should be unchanged, since only the installer's own path moved, not its
  content).

## T018-3: Update every literal path reference to the moved installer
- [ ] T018-3: Update all literal `tools/install-agent-hooks.sh` /
  `tools/generate-install-hooks.sh` references (confirmed locations via
  repo-wide grep) to `agent-hooks/install-agent-hooks.sh` /
  `agent-hooks/generate-install-hooks.sh`:
  - `bindings/r/R/init.R` (roxygen comment referencing the human-directed
    nudge)
  - `bindings/r/R/install_hooks.R` (roxygen comment)
  - `bindings/r/R/hooks_status.R` (both the roxygen comment on
    `askfirst_hooks_manifest()` and the literal message text
    `askfirst_maybe_nudge_hooks_install()` actually prints to the human
    -- `{.code tools/install-agent-hooks.sh}`)
  - `bindings/r/vignettes/using-askfirst.Rmd` (the
    `/path/to/askfirst/tools/install-agent-hooks.sh` code block)
  - `bindings/r/vignettes/askfirst-development.Rmd` (same code block)
  - `bindings/r/tests/testthat/test-install-agent-hooks.R` (header
    comment, `find_repo_root()`'s `file.exists(file.path(dir, "tools",
    "install-agent-hooks.sh"))` check -- update to check inside
    `agent-hooks/` instead, and simplify since both conditions now target
    the same parent directory)
  - `agent-hooks/manifest.json`'s `_comment` field
  Confirm via a final repo-wide grep for `tools/install-agent-hooks` and
  `tools/generate-install-hooks` that no reference remains.

## T018-4: Simplify the R package's inst/ symlink structure
- [ ] T018-4: Remove the `bindings/r/inst/install-agent-hooks.sh` symlink
  entirely (it pointed at `../../../tools/install-agent-hooks.sh`, which
  no longer exists at that path; the file it should resolve to now lives
  inside `agent-hooks/`, already covered by the existing
  `bindings/r/inst/agent-hooks -> ../../../agent-hooks` symlink). Update
  both `system.file("install-agent-hooks.sh", package = "askfirst",
  mustWork = TRUE)` calls in `bindings/r/R/install_hooks.R`
  (`askfirst_detect_agent_tool()` and `askfirst_install_agent_hooks()`) to
  `system.file("agent-hooks", "install-agent-hooks.sh", package =
  "askfirst", mustWork = TRUE)`. Update `install_hooks.R`'s own roxygen
  comment describing the symlink setup to match.

## T018-5: Verify the directory merge with the full test suite
- [ ] T018-5: Run `devtools::test()` and `devtools::check()` from
  `bindings/r/` to confirm the directory merge (T018-1 through T018-4)
  introduced no regressions before layering the text-consolidation work
  (T018-6 onward) on top. Also manually re-run the installer
  (`agent-hooks/install-agent-hooks.sh --tool claude` and `--tool
  opencode` in a scratch directory) to confirm it still installs
  correctly from its new location.

## T018-6: Create the canonical askfirst-context.txt source
- [ ] T018-6: Create `agent-hooks/askfirst-context.txt` containing the
  `<askfirst-context>...</askfirst-context>` prose block verbatim, copied
  from its current form in `agent-hooks/claude/session_start.sh`'s
  `ASKFIRST_CONTEXT` heredoc (confirm it is byte-identical to
  `agent-hooks/opencode/askfirst-plugin.js`'s `ASKFIRST_CONTEXT` JS
  template literal content first, since they should already match exactly
  -- if they've drifted even slightly, flag this and resolve which
  version is authoritative before proceeding, since this task assumes
  they're identical).

## T018-7: Create the canonical askfirst-reminder-messages.txt source
- [ ] T018-7: Create `agent-hooks/askfirst-reminder-messages.txt` with two
  clearly-delimited sections (e.g. `--- LEVEL1 ---` / `--- LEVEL2 ---`
  section markers), containing the level-1 and "REPEATED" level-2
  escalation wording currently duplicated between
  `agent-hooks/claude/post_tool_use.sh` (bash `printf`, positional `%s`/
  `%d` placeholders) and `agent-hooks/opencode/askfirst-plugin.js` (JS
  template literals, `${pkg}`/`${count}` placeholders). Use neutral
  placeholder tokens `{{PKG}}` (appears once in level-1, four times in
  level-2) and `{{COUNT}}` (level-2 only, in the "REPEATED reminder
  (Nx)" lead-in) that the generation step (T018-10) will translate to
  each target's native substitution syntax.

## T018-8: Create the canonical askfirst-state-dir.sh source
- [ ] T018-8: Create `agent-hooks/askfirst-state-dir.sh` containing the
  canonical `askfirst_state_dir()` bash function body (currently
  identical in both `agent-hooks/claude/post_tool_use.sh` and
  `agent-hooks/claude/user_prompt_submit.sh`): strip a leading `/`,
  replace remaining `/` with `_`, join under `${TMPDIR:-/tmp}/askfirst/
  <mangled>`. This is the single bash-language canonical source spliced
  into both files by T018-10; per the plan's Design Goal 4, no equivalent
  shared source is created for `askfirst-plugin.js`'s JS port -- that
  stays a manually-maintained, separately-verified translation (see
  T018-12).

## T018-9: Add intra-file splice markers to the four canonical per-tool files
- [ ] T018-9: Add splice-point markers the generator (T018-10) can locate:
  - `agent-hooks/claude/session_start.sh`: no new marker needed -- its
    existing `cat <<'ASKFIRST_CONTEXT'` / `ASKFIRST_CONTEXT` heredoc pair
    already brackets the prose block exactly.
  - `agent-hooks/opencode/askfirst-plugin.js`: add `// ASKFIRST_CONTEXT_START`
    immediately before and `// ASKFIRST_CONTEXT_END` immediately after the
    `const ASKFIRST_CONTEXT = \`...\`;` assignment.
  - `agent-hooks/claude/post_tool_use.sh`: add `# ASKFIRST_REMINDER_LEVEL1`
    directly above the level-1 `printf` call and `# ASKFIRST_REMINDER_LEVEL2`
    directly above the level-2/"REPEATED" `printf` call; add
    `# ASKFIRST_STATE_DIR_START` / `# ASKFIRST_STATE_DIR_END` bracketing
    the `askfirst_state_dir() { ... }` function body.
  - `agent-hooks/opencode/askfirst-plugin.js`: add
    `// ASKFIRST_REMINDER_LEVEL1` / `// ASKFIRST_REMINDER_LEVEL2` directly
    above each corresponding `reminder +=` line.
  - `agent-hooks/claude/user_prompt_submit.sh`: add
    `# ASKFIRST_STATE_DIR_START` / `# ASKFIRST_STATE_DIR_END` bracketing
    its own (currently duplicate) `askfirst_state_dir() { ... }` body.

## T018-10: Extend generate-install-hooks.sh with the earlier splicing pass
- [ ] T018-10: In `agent-hooks/generate-install-hooks.sh`, add a new
  splicing pass that runs *before* the existing
  SESSION_HOOK/POST_HOOK/USER_PROMPT_HOOK/PLUGIN_HOOK pass into the
  installer:
  1. Splice `askfirst-context.txt`'s content into
     `agent-hooks/claude/session_start.sh`'s existing `ASKFIRST_CONTEXT`
     heredoc region, and into `agent-hooks/opencode/askfirst-plugin.js`'s
     `ASKFIRST_CONTEXT_START`/`_END`-bracketed template literal (escaping
     any backtick or `${` characters for the JS target -- defensively,
     even though none are expected to occur in the prose).
  2. Splice `askfirst-reminder-messages.txt`'s two sections into
     `post_tool_use.sh` (translating `{{PKG}}` → `%s` and `{{COUNT}}` →
     `%d` in positional order, rebuilding the trailing `printf` argument
     list to match) and into `askfirst-plugin.js` (translating `{{PKG}}`
     → `${pkg}` and `{{COUNT}}` → `${count}` directly, no positional
     reordering needed).
  3. Splice `askfirst-state-dir.sh`'s function body into both
     `post_tool_use.sh` and `user_prompt_submit.sh`'s
     `ASKFIRST_STATE_DIR_START`/`_END`-bracketed regions.
  4. Then run the existing pass unchanged (splice the now-regenerated
     `agent-hooks/claude/*.sh`/`agent-hooks/opencode/askfirst-plugin.js`
     into `agent-hooks/install-agent-hooks.sh`).
  Implement via the same awk-based line-range-replacement technique
  already used for the installer-level splicing, extended to also handle
  the JS-comment marker pairs and the bash/JS placeholder-translation
  step.

## T018-11: Regenerate and verify byte-for-byte equivalence
- [ ] T018-11: Run the extended `agent-hooks/generate-install-hooks.sh`.
  Confirm: (a) `agent-hooks/claude/session_start.sh`'s and
  `agent-hooks/opencode/askfirst-plugin.js`'s context blocks are
  byte-identical to what they contained before this stage (modulo the new
  marker comments in the JS file); (b) `post_tool_use.sh`'s and
  `askfirst-plugin.js`'s rendered reminder wording produces identical
  output text to before, for both the level-1 and level-2/"REPEATED"
  cases (verify by rendering both with a sample `pkg`/`count` and diffing
  against the pre-stage wording, since the underlying `printf`/template
  mechanics changed even though the source moved); (c)
  `askfirst_state_dir()`'s function body in both `post_tool_use.sh` and
  `user_prompt_submit.sh` is unchanged; (d) `agent-hooks/install-agent-hooks.sh`'s
  embedded copies still match all four canonical files exactly (the
  existing splicing pass's own guarantee, now running on the
  freshly-regenerated canonical files).

## T018-12: Add a shared behavioral-contract fixture for the JS mangling port
- [ ] T018-12: Per the plan's Design Goal 4, add a small fixture (e.g.
  `agent-hooks/askfirst-state-dir-fixture.txt`, or inline in each test
  file if simpler) of example absolute-path → mangled-path pairs (a
  handful of representative cases: no trailing slash, multiple path
  segments, a path containing only `/`). Add or extend a bash test/check
  and confirm `bindings/r/tests/testthat/test-log.R`'s
  `askfirst_mangle_path()` tests and
  `agent-hooks/opencode/askfirst-plugin.test.js`'s mangling-related
  assertions (indirectly, via the state-dir path a log-flush test lands
  at) all agree on the same fixture cases, so the R, bash, and JS
  implementations are verified equivalent even though only the bash
  version has a literal shared source file (T018-8).

## T018-13: Update dev-workflow documentation
- [ ] T018-13: Update `agent-hooks/generate-install-hooks.sh`'s own header
  comment to describe the new two-layer splicing pipeline (shared
  sources → per-tool canonical files → installer), and note in
  `bindings/r/vignettes/askfirst-development.Rmd` (wherever it describes
  the hook-editing workflow for `askfirst` maintainers) that editing the
  context prose, reminder wording, or state-dir mangling now means editing
  the shared source file under `agent-hooks/` and re-running
  `agent-hooks/generate-install-hooks.sh`, not hand-editing
  `session_start.sh`/`askfirst-plugin.js`/`post_tool_use.sh` directly.

## T018-14: Full test suite and package check
- [ ] T018-14: Run `devtools::test()` and `devtools::check()` from
  `bindings/r/`, and `bun test agent-hooks/opencode/askfirst-plugin.test.js`,
  confirming no regressions from this stage's full scope (directory merge
  plus text consolidation). Fix any failures before this stage is
  considered done.
