---
created: 2026-07-30T00:00:00Z
agent: claude-sonnet-5
git_hash: 4dea3684cd28feaab71355e7f2d4b9107ec86eed
---

# Tasks: fix-installer-and-halt-clause

## T022-1: Fix installer silent-skip bug in the Claude Code branch
- [x] T022-1: In `agent-hooks/install-agent-hooks.sh`'s `claude)` case
  (~lines 717-722), replace the
  `if [[ -f "$TARGET_CONFIG" ]]; then register_hooks_claude; echo
  "register..."; else echo "skip..."; fi` block with: create
  `$TARGET_CONFIG` as `{}` when absent (`[[ -f "$TARGET_CONFIG" ]] ||
  echo '{}' > "$TARGET_CONFIG"`), then unconditionally call
  `register_hooks_claude` and log a single "register: $TARGET_CONFIG
  (hooks added)" line. Remove the "skip: ... not found" branch entirely.
  Leave the earlier `jq`-missing warning/`exit 0` (~line 692-696)
  untouched — it remains the only early-exit case. Do not touch the
  `opencode)` branch (no registration step exists there; confirmed no
  equivalent gap).

## T022-2: Add installer test for settings.json creation
- [x] T022-2: Add a test (wherever `install-agent-hooks.sh` is currently
  tested, or a new script-level test if none exists) that runs the
  installer against a temp directory with no `.claude/settings.json`
  present, and asserts: (a) `.claude/settings.json` is created, (b) it
  contains registered `SessionStart`/`PostToolUse`/`UserPromptSubmit`
  hooks pointing at `.claude/hooks/{session_start,post_tool_use,
  user_prompt_submit}.sh`, (c) the installer's stderr output no longer
  contains "skip:" and instead contains "register: ... (hooks added)".
  Also verify the existing behavior is unchanged when
  `.claude/settings.json` already exists (hooks still get appended
  correctly, not overwritten).

## T022-3: Revise HALT directive point 6 in the hook-context canonical source
- [x] T022-3: Edit point 6 of the `<askfirst-context>` block in
  `agent-hooks/askfirst-context.txt` so that, on a `stop-and-ask` signal:
  surfacing the upstream question to the user and waiting for their
  answer remains the required first and primary action (stated up front);
  a workaround may be separately noted as existing only as a clearly
  subordinate, explicitly-labeled aside (e.g. "unvetted"/"provisional"),
  never as a selectable menu option, recommended or otherwise, co-equal
  with asking the user. Preserve the existing prohibition on menu-style
  framing that stages 011/012 established — do not reintroduce a
  "recommended option" pattern. Base wording on the plan.md draft:
  "your first and primary action is to surface the upstream question ...
  this must come first, not buried after other content. You may
  separately note that an unvetted workaround exists, but only as a
  clearly subordinate, explicitly-labeled aside ... never as a selectable
  menu option, recommended or otherwise, co-equal with asking the user."

## T022-4: Regenerate downstream copies from the hook-context source
- [x] T022-4: Run `agent-hooks/generate-install-hooks.sh` after T022-3 to
  propagate the revised point 6 into `agent-hooks/claude/session_start.sh`
  and `agent-hooks/opencode/askfirst-plugin.js`, and into
  `install-agent-hooks.sh`'s embedded `SESSION_HOOK`/`POST_HOOK`/
  `USER_PROMPT_HOOK`/`PLUGIN_HOOK` heredocs. Diff the regenerated files to
  confirm only the intended wording changed, and run whatever sync-check
  script currently validates these stay in sync with their canonical
  source (see `check-agent-content-sync.R` and its sibling for
  `agent-hooks/`, if one exists) to confirm no drift remains.

## T022-5: Revise the hook-independent stop-consequence and notice-prime text
- [x] T022-5: Edit `agent-content/askfirst-stop-consequence.txt` and
  `agent-content/askfirst-notice-prime.txt` to carry the same substance as
  T022-3's revised wording (these are short, inline forms — not required
  to be byte-identical to `askfirst-context.txt`, but must not
  contradict it): keep "ask the user / wait for their answer" as the
  required first action, and change "do not implement, draft, or offer a
  workaround as an option, recommended or otherwise" /  "do not offer one
  as an option in that turn" to permit a clearly subordinate,
  explicitly-labeled mention (not a menu option) once the upstream
  question has been surfaced.

## T022-6: Sync the revised agent-content text into the R package
- [x] T022-6: Run `bindings/r/data-raw/sync-agent-content.R` (or the
  current equivalent sync script) to update
  `bindings/r/inst/agent-content/askfirst-stop-consequence.txt` and
  `askfirst-notice-prime.txt` from the edited canonical sources, then run
  `check-agent-content-sync.R` to confirm no drift remains.

## T022-7: Add/update tests asserting the revised stop-consequence and notice-prime wording
- [x] T022-7: In `bindings/r/tests/testthat/test-capability-gap.R` and
  `test-log.R` (both already assert on `<<<ASKFIRST:HALT>>>` message
  content), add assertions that the emitted message contains the new
  subordinate-aside language (e.g. matches on "unvetted" or the specific
  label chosen in T022-5) and does NOT contain menu-option framing (e.g.
  no match on a "recommended option" pattern). Confirm these tests fail
  against the pre-change text and pass after T022-5/T022-6, to verify
  they actually exercise the new wording rather than passing vacuously.

## T022-8: Run full test suite and confirm no regressions
- [x] T022-8: Run the R package test suite (`devtools::test()` or
  equivalent in `bindings/r/`) and any installer-level tests added in
  T022-2, confirming all pass. Confirm `git status` shows only the
  expected changed files: `agent-hooks/install-agent-hooks.sh`,
  `agent-hooks/askfirst-context.txt`, `agent-hooks/claude/session_start.sh`,
  `agent-hooks/opencode/askfirst-plugin.js`,
  `agent-content/askfirst-stop-consequence.txt`,
  `agent-content/askfirst-notice-prime.txt`,
  `bindings/r/inst/agent-content/*`, and the test files touched above.
