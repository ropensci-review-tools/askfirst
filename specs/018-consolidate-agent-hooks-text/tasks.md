---
created: 2026-07-28T17:21:36Z
agent: claude-sonnet-5
git_hash: 410c1b799c3ef5a7210681bbe1743ed4b7dd1e67
---

# Tasks: consolidate-agent-hooks-text

## T018-1: Move tools/ files into agent-hooks/, remove tools/
- [x] T018-1: Moved via `git mv` (history preserved), `tools/` removed.
  `agent-hooks/` now contains `claude/`, `opencode/`, `manifest.json`,
  `install-agent-hooks.sh`, `generate-install-hooks.sh`. No content
  changes made in this task. Move `tools/install-agent-hooks.sh` to
  `agent-hooks/install-agent-hooks.sh` and `tools/generate-install-hooks.sh`
  to `agent-hooks/generate-install-hooks.sh` (`git mv` to preserve history).
  Remove the now-empty `tools/` directory. Do not edit either file's
  contents in this task — that happens in later tasks.

## T018-2: Update generate-install-hooks.sh's internal paths for the merge
- [x] T018-2: `INSTALLER` updated to `$REPO_ROOT/agent-hooks/install-agent-hooks.sh`;
  header comment updated. Ran it once: regenerated installer is
  byte-identical to the pre-change version (confirmed via diff), so the
  path move alone changed nothing observable. In the relocated
  `agent-hooks/generate-install-hooks.sh`,
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
- [x] T018-3: All confirmed locations updated via `sed`, plus two the
  initial grep missed (only caught by a second, broader repo-wide sweep):
  `agent-hooks/install-agent-hooks.sh`'s own header comment
  (self-referencing `agent-hooks/generate-install-hooks.sh`, outside any
  spliced heredoc region, so hand-edited directly) and
  `bindings/r/tests/testthat/test-install-agent-hooks.R`'s `file.path(dir,
  "tools", "install-agent-hooks.sh")`-style calls (separate path
  components, not a literal joined string, so the sed pass missed them --
  fixed by hand, and `find_repo_root()` simplified to a single existence
  check per the task's own suggestion). Regenerated `.Rd` files via
  `devtools::document()`. Final repo-wide grep confirms zero remaining
  `tools/install-agent-hooks`/`tools/generate-install-hooks` references
  anywhere outside `specs/` (historical stage records correctly left
  untouched). Update all literal `tools/install-agent-hooks.sh` /
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
- [x] T018-4: Symlink removed; confirmed `bindings/r/inst/agent-hooks/install-agent-hooks.sh`
  resolves correctly through the existing whole-directory symlink. Both
  `system.file()` calls updated to
  `system.file("agent-hooks", "install-agent-hooks.sh", package =
  "askfirst", mustWork = TRUE)`; verified live it resolves to the correct,
  existing path. Remove the `bindings/r/inst/install-agent-hooks.sh` symlink
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
- [x] T018-5: `devtools::test()`: 162/162 pass. `devtools::check()`: 0
  errors, 0 warnings, 0 notes. Manually re-ran the installer for both
  `--tool opencode` and `--tool claude` in a scratch directory: both
  installed correctly (opencode's plugin auto-discovered, Claude Code's
  three hooks installed and registered). Directory merge confirmed clean
  before starting the text-consolidation work. Run `devtools::test()` and
  `devtools::check()` from
  `bindings/r/` to confirm the directory merge (T018-1 through T018-4)
  introduced no regressions before layering the text-consolidation work
  (T018-6 onward) on top. Also manually re-run the installer
  (`agent-hooks/install-agent-hooks.sh --tool claude` and `--tool
  opencode` in a scratch directory) to confirm it still installs
  correctly from its new location.

## T018-6: Create the canonical askfirst-context.txt source
- [x] T018-6: **Found real drift, not just accidental duplication.**
  Diffing the two extracted copies found: (a) bash's heredoc content had a
  leading blank line the JS template literal didn't -- traced to
  `session_start.sh`'s own output structure (separating a passthrough
  `cat` of the hook payload from the appended context block), not actual
  prose content, so excluded from the canonical file and left as
  `session_start.sh`'s own static formatting around the splice point; (b)
  a genuine, intentional stage-017 divergence: bash said "this coding
  tool's own **PostToolUse hook** will actively **block** every
  subsequent tool call" / "treat a subsequent **blocked** tool call",
  while the JS version (deliberately reworded during stage 017 to match
  opencode's actual throw-based mechanism) said "**tool-execution hook**"
  / "actively **reject**" / "**rejected** tool call". Reconciled with
  tool-neutral wording in the canonical file: "enforcement hook ... will
  actively **stop** every subsequent tool call ... **from succeeding**"
  and "a subsequent **failed** tool call" -- accurate for both Claude
  Code's exit-code blocking and opencode's thrown-error rejection, so one
  canonical text now serves both without picking either mechanism's own
  terminology. Created `agent-hooks/askfirst-context.txt` containing the
  `<askfirst-context>...</askfirst-context>` prose block verbatim, copied
  from its current form in `agent-hooks/claude/session_start.sh`'s
  `ASKFIRST_CONTEXT` heredoc (confirm it is byte-identical to
  `agent-hooks/opencode/askfirst-plugin.js`'s `ASKFIRST_CONTEXT` JS
  template literal content first, since they should already match exactly
  -- if they've drifted even slightly, flag this and resolve which
  version is authoritative before proceeding, since this task assumes
  they're identical).

## T018-7: Create the canonical askfirst-reminder-messages.txt source
- [x] T018-7: No drift found -- bash and JS wording matched exactly
  (modulo placeholder syntax). Created
  `agent-hooks/askfirst-reminder-messages.txt` with `--- LEVEL1 ---`/
  `--- LEVEL2 ---` sections, `{{PKG}}`/`{{COUNT}}` placeholders, and the
  trailing `\n\n` kept literally (both bash `printf` and JS template
  literals already interpret a literal `\n` the same way, so this needs
  no reinterpretation during splicing). Create with two
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
- [x] T018-8: Confirmed the two bash copies are byte-identical (diff,
  clean). Created `agent-hooks/askfirst-state-dir.sh` containing the
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
- [x] T018-9: **Simplified during implementation**: the context block
  needs no new markers at all in *either* file -- `<askfirst-context>`/
  `</askfirst-context>` are already unique literal tags present in both
  `session_start.sh`'s heredoc and `askfirst-plugin.js`'s template
  literal, so they serve directly as splice boundaries (matched on
  content, not a synthetic marker comment). Added paired `_START`/`_END`
  comment markers (more robust for the awk splicer than single-line
  markers, since the bracketed content spans multiple lines) for
  everything else: `# ASKFIRST_STATE_DIR_START`/`_END` around
  `askfirst_state_dir()` in both `post_tool_use.sh` and
  `user_prompt_submit.sh`; `# ASKFIRST_REMINDER_LEVEL1_START`/`_END` and
  `# ASKFIRST_REMINDER_LEVEL2_START`/`_END` around each `printf` call in
  `post_tool_use.sh`; the JS-comment equivalents (`//
  ASKFIRST_REMINDER_LEVEL1_START`/`_END`, `_LEVEL2_START`/`_END`) around
  each `reminder +=` line in `askfirst-plugin.js`. Also added a code
  comment on `askfirstMangleTermPath()` documenting it as a
  manually-maintained JS port of `agent-hooks/askfirst-state-dir.sh`, not
  a literal shared source (Design Goal 4). Verified: bash syntax checks
  pass, `bun build`/`bun test` (12/12) still pass unchanged after adding
  the comment markers.

## T018-10: Extend generate-install-hooks.sh with the earlier splicing pass
- [x] T018-10: Implemented via a generic `splice_between_markers()`
  awk-based helper (handles both "inclusive" mode for the
  `<askfirst-context>` tags and "exclusive" mode for synthetic
  `ASKFIRST_*_START`/`_END` comment markers, auto-detecting and
  reproducing each marker line's own indentation), plus
  `render_reminder_bash_line()`/`render_reminder_js_line()` which
  translate `{{PKG}}`/`{{COUNT}}` into each target's native substitution
  syntax by rebuilding the argument list in placeholder-appearance order
  (bash) or direct named interpolation (JS). Backtick-escaping for the JS
  context target implemented via a `sed 's/`/\\`/g'` pre-pass on a temp
  copy. Syntax-checked clean; full output-correctness verification is
  T018-11's job. In `agent-hooks/generate-install-hooks.sh`, add a new
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
- [x] T018-11: **Found and fixed a real bug during first run**: the
  generator aborted mid-Pass-1 because `[[ "$target" == *.sh ]] &&
  chmod +x "$target"` evaluates to a false (non-zero) status whenever the
  condition is false (i.e. for `askfirst-plugin.js`), which trips
  `set -e` and kills the whole script even though nothing actually went
  wrong -- fixed by converting to an explicit `if`/`fi` block. After the
  fix: full end-to-end run succeeded (exit 0), confirmed via all four
  checks: (a) both context blocks render the reconciled wording correctly
  (`grep`/live JS `import` check, both positive); (b) reminder wording --
  *executed* both the original two-line and new single-line `printf`
  calls with sample values and diffed the actual rendered output (not
  just source text): identical for both level-1 and level-2; JS template
  literals diffed byte-for-byte against the pre-stage backup: identical;
  (c) `askfirst_state_dir()` function body diffed against backup
  (modulo the new marker comments): identical; (d)
  `test-install-agent-hooks.R`'s embedded-content checks: 10/10 pass.
  Full suite re-run after: `bun test`: 12/12 pass; `devtools::test()`:
  162/162 pass. Run the extended `agent-hooks/generate-install-hooks.sh`.
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
- [x] T018-12: Created `agent-hooks/askfirst-state-dir-fixture.txt` (4
  cases: multi-segment path, 3-segment path, `/` alone → empty string,
  single segment). Extracted `find_repo_root()` (previously duplicated
  only in `test-install-agent-hooks.R`) into a new shared
  `helper-repo-root.R`, since `test-log.R` now needs it too. Added a
  fixture-driven test to `test-log.R` asserting `askfirst_mangle_path()`
  against every fixture line. Added a fixture-driven test to
  `askfirst-plugin.test.js` verifying indirectly (via a real
  `tool.execute.after` log-flush, using the *fixture's own* expected
  value to place the marker file, not this test file's separate
  `mangle()` setup helper — so it would catch drift between the real
  implementation and the fixture even if that setup helper also drifted).
  **Caught a real bug before it ran**: the `/` → `""` fixture case
  mangles to the shared state-tmp-root itself
  (`${TMPDIR}/askfirst`), so the JS test's cleanup would have recursively
  deleted that shared directory — excluded that one case from the JS test
  (still covered safely, with no filesystem side effects, by the R test)
  rather than risk it. R: 33/33 pass (`test-log.R`), 10/10 pass
  (`test-install-agent-hooks.R`, unaffected by the helper extraction). JS:
  13/13 pass. Per the plan's Design Goal 4, add a small fixture (e.g.
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
- [x] T018-13: `generate-install-hooks.sh`'s header comment was already
  rewritten during T018-10 to describe the two-layer pipeline. Added a new
  "Editing hook content" paragraph to
  `bindings/r/vignettes/askfirst-development.Rmd`'s "Pre-configure agent
  hooks" section, naming all three canonical source files, the splice
  markers, and the edit → regenerate → commit workflow. Vignette confirmed
  to still knit cleanly. Update `agent-hooks/generate-install-hooks.sh`'s own header
  comment to describe the new two-layer splicing pipeline (shared
  sources → per-tool canonical files → installer), and note in
  `bindings/r/vignettes/askfirst-development.Rmd` (wherever it describes
  the hook-editing workflow for `askfirst` maintainers) that editing the
  context prose, reminder wording, or state-dir mangling now means editing
  the shared source file under `agent-hooks/` and re-running
  `agent-hooks/generate-install-hooks.sh`, not hand-editing
  `session_start.sh`/`askfirst-plugin.js`/`post_tool_use.sh` directly.

## T018-14: Full test suite and package check
- [x] T018-14: `devtools::document()`: no warnings. `devtools::test()`:
  166/166 pass. `devtools::check()`: 0 errors, 0 warnings, 0 notes.
  `bun test`: 13/13 pass. Final end-to-end sanity check: ran the installer
  fresh for both tools in a scratch directory and confirmed both
  installed artifacts (`.opencode/plugins/askfirst-plugin.js`,
  `.claude/hooks/session_start.sh`) carry the reconciled canonical
  context text. No regressions found across this stage's full scope.
