---
created: 2026-07-28T15:56:15Z
agent: claude-sonnet-5
git_hash: da4602035ebe3feb24382d0a557e2c77c2a14b51
---

# Tasks: add-opencode-plugin

## T017-1: Confirm and commit the @opencode-ai/plugin version bump
- [x] T017-1: **Verified, not committed — `.opencode/.gitignore` explicitly
  excludes `package.json`, `bun.lock`, and `node_modules`** (this
  directory is deliberately untracked local dev/testing scratch tooling,
  confirmed by reading `.opencode/.gitignore` directly: it lists
  `node_modules`, `package.json`, `bun.lock`, `.gitignore`). The version
  bump to `^1.18.8` is correctly in place locally
  (`.opencode/package.json` and `.opencode/bun.lock` both confirmed), but
  there is nothing to commit for this task — it was never meant to be
  tracked. This repo's own `.opencode/package.json` was bumped from an
  exact-pinned `"@opencode-ai/plugin": "1.1.23"` to
  `"@opencode-ai/plugin": "^1.18.8"` (via `bun add @opencode-ai/plugin@latest`)
  during this stage's plan review, to match the actually-installed
  `opencode` CLI in this environment (confirmed at `~/.opencode/bin/opencode
  --version` → `1.18.8`; `/usr/bin/opencode` at `1.1.23` is a stale,
  unrelated install earlier in `$PATH`). Verify `.opencode/package.json`
  and `.opencode/bun.lock` reflect this bump, and include them in this
  stage's own commit(s) rather than leaving it as an untracked local-only
  fix.

## T017-2: Determine opencode's real built-in tool names for file edits
- [x] T017-2: **Confirmed empirically against a real, authenticated
  opencode session** (`~/.opencode/bin/opencode run ... --model
  opencode/deepseek-v4-flash-free`, with a minimal canary plugin in a
  scratch project's `.opencode/plugins/` logging every `input.tool`
  value): opencode's real, exact `input.tool` string for a file edit is
  `"edit"` (lowercase) — directly observed in both `tool.execute.before`
  and `tool.execute.after` payloads when the model called its edit tool
  (`{"filePath": "...", "oldString": "...", "newString": "..."}` as
  `args`). This matches opencode's own published tools docs, which also
  name `write` and `apply_patch` as the other two file-modifying tools
  (not independently observed live in this test, since the model only
  used `edit`, but consistent with the confirmed `edit` naming
  convention and the docs' explicit listing). The escalation/blocking
  logic (T017-5/T017-6) should match on `input.tool` being one of
  `"edit"`, `"write"`, `"apply_patch"`.
  **Additional findings from this same live test, useful for later
  tasks**: `"chat.message"` fired exactly once per user turn (confirming
  it as the right UserPromptSubmit-equivalent hook for T017-7);
  `"experimental.chat.system.transform"` fired *multiple* times within a
  single turn (once per model inference step, not once per session) —
  T017-4's implementation must treat pushing the context block onto
  `output.system` as safe to repeat, not assume a Claude-Code-style
  one-shot SessionStart firing pattern.

## T017-3: JS state-dir and path-mangling helpers
- [x] T017-3: Implemented `askfirstMangleTermPath()`/`askfirstStateDir()`
  in `agent-hooks/opencode/askfirst-plugin.js`, byte-for-byte matching the
  R (`askfirst_mangle_path()`/`askfirst_state_dir()`,
  `bindings/r/R/state.R`) and bash (`agent-hooks/*/post_tool_use.sh`)
  mangling scheme: leading `/` stripped, remaining `/` replaced with `_`,
  joined under `${TMPDIR:-/tmp}/askfirst/<mangled>` via
  `process.env.TMPDIR` and the plugin's own `directory` (captured once at
  load time, opencode's analog of `cwd`/`getwd()`). Confirmed live: the
  plugin's self-computed state dir for a real scratch project matched
  exactly the path independently computed by hand, and state written
  there was correctly found and consumed by the plugin across separate
  `opencode run` invocations.

## T017-4: Implement context injection (experimental.chat.system.transform)
- [x] T017-4: Implemented `experimental.chat.system.transform`, pushing
  the `<askfirst-context>` block (same content as
  `agent-hooks/claude/session_start.sh`, which was already tool-agnostic
  in wording — no Claude-Code-specific text needed changing) onto
  `output.system`. Confirmed live that this hook fires multiple times per
  turn (once per model inference step, not once per session as Claude
  Code's SessionStart does) — implemented as safe to call repeatedly
  (each firing just appends the same block; no session-scoped
  "already-injected" guard needed).

## T017-5: Implement notice-log flush and escalating reminder (tool.execute.after)
- [x] T017-5: Implemented `tool.execute.after`: flushes `log`'s content
  into `output.output` (prefixed with `[askfirst-annotation:]`, tool's
  real result preserved) and deletes it; for `input.tool` in
  `{"edit", "write", "apply_patch"}` (confirmed set from T017-2), checks
  `unresolved-notice/` and appends the escalating reminder (level-1 for
  occurrences 1-2, "REPEATED" level-2 from the 3rd) via a per-package
  counter under `unresolved-notice-count/`, mirroring
  `post_tool_use.sh` exactly. **Confirmed live end-to-end**: with a
  simulated unresolved `dodgr` notice in place, a real `edit` tool call
  correctly flushed the log, incremented the counter file to `1`, and
  left the `unresolved-notice/dodgr.txt` marker in place (correctly not
  cleared by this hook); a preceding `read` call correctly did *not*
  increment the counter, confirming the file-tool-type filter works.

## T017-6: Implement the blocking stop-and-ask gate (tool.execute.before)
- [x] T017-6: Implemented `tool.execute.before`: throws an `Error` (message
  = concatenated content of any `pending/*.txt` files) whenever any exist,
  per opencode's own documented abort-via-throw pattern. **Confirmed live**:
  with a pending sentinel injected mid-turn (after a first tool call, so
  no intervening `chat.message` could clear it), a second tool call within
  the *same* turn was genuinely rejected — the CLI showed `✗ Read
  testfile.txt failed` / `Error: <pending file content>`, and the model
  correctly relayed the rejection to the user. This resolves this stage's
  open question: `tool.execute.before`'s abort behavior is not scoped to
  any particular tool type in this implementation (the check runs
  unconditionally before every tool call), so it does achieve the "block
  every subsequent call regardless of topic" guarantee this stage needed.
  (An earlier test that appeared to show no blocking was a test-setup
  artifact, not a real gap — see T017-7's note.)

## T017-7: Implement pending-clear on a new turn (chat.message)
- [x] T017-7: Implemented `"chat.message"`: recursively removes `pending/`
  under `askfirstStateDir()`, leaving `unresolved-notice/` untouched (not
  cleared by a new turn, only by an explicit resolution, per stage 016).
  **Confirmed live and precisely characterized**: `chat.message` fires
  exactly once per new user turn, *before* any tool calls in that turn.
  This means a `pending/` sentinel that exists when a brand-new turn
  starts is cleared immediately, before the agent's first tool call of
  that turn — which is in fact the *intended* semantics (a new user
  message is the proxy for "the user has had a chance to respond"), not a
  bug. An initial test that pre-created a pending file and then started a
  fresh session appeared to show "blocking doesn't work," but this was
  actually `chat.message` correctly clearing a sentinel from a prior turn
  at the start of a new one; T017-6's real-blocking confirmation used a
  sentinel injected *mid-turn* instead, which is the realistic scenario
  (askfirst raising a stop-and-ask synchronously during a tool call, not
  before the turn even starts).

## T017-8: Assemble the single, dependency-free plugin file
- [x] T017-8: Created `agent-hooks/opencode/askfirst-plugin.js` combining
  T017-3 through T017-7 into one file exporting `AskfirstPlugin` as a
  **named ES export** (`export const AskfirstPlugin = async ({directory})
  => {...}`) — confirmed live as the convention opencode's plugin loader
  actually looks for (not `export default`, and not CommonJS
  `module.exports`, which was this task's original assumption and had to
  be corrected after the first live test). Uses only Node/Bun built-ins
  (`fs`, `path` via `require()`, confirmed to work inside an ES-exported
  plugin module under opencode's bun runtime) — no `node_modules` or
  build step needed. Version marker: `// askfirst-hook-version: 4` at the
  top of the file (see T017-12 for the matching R-side regex change).

## T017-9: Unit tests for the plugin's pure logic
- [x] T017-9: Added `agent-hooks/opencode/askfirst-plugin.test.js` (12
  tests, `bun test`), exercising the real `AskfirstPlugin` export exactly
  as opencode itself invokes it (never by exporting internal helpers
  directly for testing — see the note in that file's header and T017-8:
  opencode's loader tries to invoke every exported binding as a plugin, so
  a second, differently-shaped export would break real installs). Covers:
  state-dir mangling (indirectly, via log-flush landing at the expected
  path), context injection (present, and safe to call repeatedly per
  turn), log-flush content/deletion, the file-tool-type filter (`read`
  vs. `edit`/`write`/`apply_patch`), the level-1 → "REPEATED" level-2
  escalation transition at the 3rd occurrence, the blocking gate
  (throws with pending content present, resolves cleanly with none), and
  `"chat.message"` clearing `pending/` while leaving `unresolved-notice/`
  untouched. All 12 pass (`bun test agent-hooks/opencode/askfirst-plugin.test.js`).

## T017-10: Rework the installer's opencode branch to install the plugin, not shell scripts
- [x] T017-10: Restructured `case "$TOOL" in ... esac` into a per-tool
  install dispatch: `claude` keeps `write_session_start`/
  `write_post_tool_use`/`write_user_prompt_submit` + `register_hooks_claude`
  unchanged; `opencode` now only creates `.opencode/plugins/` and calls a
  new `write_plugin()` (no shell scripts, no `register_hooks_opencode()`,
  no config registration at all). **Confirmed live end-to-end**: ran the
  installer with `--tool opencode` in a scratch dir — produced exactly
  `.opencode/plugins/askfirst-plugin.js`, byte-identical to the canonical
  `agent-hooks/opencode/askfirst-plugin.js`; separately ran `--tool claude`
  in a scratch dir with a seed `.claude/settings.json` — produced the
  three hook scripts plus correct `PostToolUse`/`SessionStart`/
  `UserPromptSubmit` registration, unchanged in shape from before this
  stage.

## T017-11: Embed the plugin content in the installer, update the generator
- [x] T017-11: Updated `tools/generate-install-hooks.sh` to also splice
  `agent-hooks/opencode/askfirst-plugin.js`'s content into a new
  `PLUGIN_HOOK` heredoc marker inside `write_plugin()`, following the same
  awk-based splicing pattern as `SESSION_HOOK`/`POST_HOOK`/
  `USER_PROMPT_HOOK`. Rewrote the script's header comment: the old
  "`agent-hooks/claude/` and `agent-hooks/opencode/` are kept
  byte-identical" invariant no longer holds now that opencode's mechanism
  is a JS plugin rather than a shell-script family; the comment now states
  `askfirst-plugin.js` is spliced from its own independent source.
  **Confirmed**: ran the regenerator against the already-hand-embedded
  installer content (from T017-10) — output was byte-identical, confirming
  the generator correctly automates what was manually embedded and will
  keep it in sync on future edits to `askfirst-plugin.js`.

## T017-12: Update hook-version detection for the JS plugin marker
- [x] T017-12: All three sub-parts implemented and verified: (a) regex
  now `^(#|//)\s*askfirst-hook-version:\s*[0-9]+`, confirmed live against
  both a shell-comment and a JS-comment fixture (extracted `4` correctly
  from each, `NA` for no marker); (b) `askfirst_hooks_manifest()` and
  `agent-hooks/manifest.json` both updated with `marker_file` per tool
  (`session_start.sh` / `askfirst-plugin.js`) and opencode's `hooks_dir`
  changed to `.opencode/plugins`; (c) `askfirst_hooks_status_for_tool()`
  now builds its target path from `manifest$tools[[tool]]$marker_file`
  instead of a hardcoded `"session_start.sh"`. `hook_version` bumped to
  `4` in both places, matching T017-8's plugin file marker. In
  `bindings/r/R/hooks_status.R`:
  (a) extend `askfirst_hook_version_from_file()`'s marker regex to also
  match a `// askfirst-hook-version: <N>` JS-comment form (in addition to
  the existing `# askfirst-hook-version: <N>` shell-comment form), since
  T017-8's plugin file uses `//` comments;
  (b) update `askfirst_hooks_manifest()` and `agent-hooks/manifest.json`
  so opencode's entry reflects the new install location
  (`.opencode/plugins/`) and target filename (`askfirst-plugin.js`)
  instead of `.opencode/hooks/session_start.sh`;
  (c) generalize `askfirst_hooks_status_for_tool()`, which currently
  hardcodes checking `file.path(hooks_dir, "session_start.sh")` for every
  tool — it needs a per-tool target filename (e.g. `session_start.sh` for
  claude, `askfirst-plugin.js` for opencode) rather than one filename
  assumed universal.
  Bump `hook_version` to `4` in both `agent-hooks/manifest.json` and
  `askfirst_hooks_manifest()`, consistent with T017-8's plugin file
  marker.

## T017-13: Remove the superseded opencode shell scripts
- [x] T017-13: Deleted `agent-hooks/opencode/session_start.sh`,
  `post_tool_use.sh`, and `user_prompt_submit.sh` outright. Their
  precondition (the plugin mechanism actually working) was already
  satisfied by the live verification done during T017-3 through T017-10
  (context injection, escalation, blocking gate, and turn-boundary
  clearing all confirmed against real `opencode` sessions); `agent-hooks/opencode/`
  now contains only `askfirst-plugin.js` and its test file. Per this
  stage's explicit decision, no defense-in-depth fallback is kept once the
  real mechanism supersedes them.

## T017-14: Update tests for the new opencode install path and version marker
- [x] T017-14: Replaced the byte-identity test with an equivalent
  `PLUGIN_HOOK`-vs-canonical-file check (`test-install-agent-hooks.R`);
  added opencode-specific fixtures to `test-hooks-status.R` (JS-comment
  marker at `.opencode/plugins/askfirst-plugin.js`, both stale (`0`) and
  current (`4`) versions, and a mixed-tools case). Along the way, found
  and fixed a second stale hardcoded fixture in `test-init.R:289` (still
  `# askfirst-hook-version: 3`) that the version bump to `4` broke —
  also fixed the root cause: Claude Code's own hook markers
  (`agent-hooks/claude/*.sh`) needed bumping from `3` to `4` too, even
  though this stage didn't change their content, since `hook_version` is
  one shared number across tools in the manifest — leaving them at `3`
  while the manifest said `4` would have made every correctly-installed
  Claude Code hook incorrectly report as `"stale"`. Full suite: 162/162
  pass. In `bindings/r/tests/testthat/test-install-agent-hooks.R`:
  remove or replace the "agent-hooks/claude/ and agent-hooks/opencode/
  stay byte-identical" test (no longer meaningful once opencode's
  mechanism is a JS plugin, not a parallel shell-script family); add
  equivalent regression coverage asserting
  `tools/install-agent-hooks.sh`'s embedded plugin content (spliced via
  T017-11) matches `agent-hooks/opencode/askfirst-plugin.js` exactly, the
  same way the existing test already checks the three Claude Code shell
  scripts. In `bindings/r/tests/testthat/test-hooks-status.R`: add test
  fixtures covering the new `// askfirst-hook-version: <N>` marker form
  and opencode's new target filename/location from T017-12.

## T017-15: Update vignettes describing hook installation
- [x] T017-15: Updated both vignettes to distinguish Claude Code's
  three-shell-hook-file install (unchanged) from opencode's
  single-plugin-file install into `.opencode/plugins/` (auto-discovered,
  no registration step, structurally a JS/TS plugin module rather than a
  shell-script family). Both vignettes confirmed to still knit cleanly
  (`knitr::knit()`) after the edits. Update `bindings/r/vignettes/using-askfirst.Rmd` and
  `bindings/r/vignettes/askfirst-development.Rmd` wherever they describe
  `askfirst_install_agent_hooks()`/`tools/install-agent-hooks.sh`'s
  behavior, to describe the opencode path as installing a single plugin
  file into `.opencode/plugins/` (auto-discovered, no registration step)
  rather than three registered shell hooks — distinctly from the Claude
  Code path, which is unchanged.

## T017-16: Manual smoke-test against a real opencode session
- [x] T017-16: **All four points confirmed against real, authenticated
  `~/.opencode/bin/opencode` (1.18.8) sessions**, using the plugin as
  installed by the actual `tools/install-agent-hooks.sh --tool opencode`
  (confirmed byte-identical to the canonical source): (a) asked the model
  directly to state what it knows from its system context, with no tools
  used — it correctly explained askfirst's mechanism, the
  `askfirst::<language>::<pkg>::<directive>` format, and the
  `stop-and-ask`/`notice` distinction, verbatim from the injected
  `<askfirst-context>` block; (b) with a simulated `dodgr` notice
  unresolved, a real `edit` tool call correctly flushed the log,
  incremented the escalation counter to `1`, and left the notice marker in
  place, while a preceding `read` call did not increment it; (c) with a
  `pending/` sentinel injected mid-turn (the realistic scenario), a
  second tool call in the same turn was genuinely rejected — CLI showed
  `✗ Read testfile.txt failed` / `Error: <pending content>`, and the model
  correctly relayed the rejection; this resolves the open question in the
  affirmative: `tool.execute.before`'s abort-via-throw is not scoped to
  any tool type in this implementation, so it does achieve
  unconditional-coverage parity with Claude Code's blocking convention;
  (d) `"chat.message"` was confirmed to fire exactly once per new user
  turn, before any tool calls in that turn — clearing `pending/` at that
  point is the *correct*, intended behavior (new turn = proxy for "user
  has had a chance to respond"), not a gap. All findings above are
  reflected in this stage's `design-decisions.md` at retrospective time.
  Using the confirmed-current `~/.opencode/bin/opencode`
  (1.18.8; ensure this is the binary actually invoked, not the stale
  `/usr/bin/opencode`), install the plugin into a throwaway test project
  via the updated installer (T017-10), then verify each hook point
  end-to-end: (a) the `<askfirst-context>` block appears in the model's
  system prompt at session start; (b) triggering a notice and then
  performing a file-edit-equivalent tool call produces the escalating
  reminder in the tool result, with the correct tool name(s) from T017-2;
  (c) with a `pending/` sentinel present, the next tool call of any kind
  is actually blocked with the thrown-error message surfaced to the
  agent — resolving this stage's open question about whether
  `tool.execute.before`'s abort behavior covers every tool call
  unconditionally; (d) sending a new user message clears `pending/` (or
  identify and switch to whatever hook actually does, if `"chat.message"`
  proves not to fire as expected) — resolving the other open question.
  Record the actual observed behavior for both open questions precisely
  in `design-decisions.md` when this stage is retrospected, including
  honest documentation of any gap found rather than an assumed pass.

## T017-17: Full test suite and package check
- [x] T017-17: `devtools::document()`: no warnings. `devtools::test()`:
  162/162 pass. `devtools::check()`: 0 errors, 0 warnings, 0 notes.
  `bun test agent-hooks/opencode/askfirst-plugin.test.js`: 12/12 pass.
  No regressions found.
