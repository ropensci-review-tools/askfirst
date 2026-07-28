---
created: 2026-07-28T15:56:15Z
agent: claude-sonnet-5
git_hash: da4602035ebe3feb24382d0a557e2c77c2a14b51
---

# Tasks: add-opencode-plugin

## T017-1: Confirm and commit the @opencode-ai/plugin version bump
- [ ] T017-1: This repo's own `.opencode/package.json` was bumped from an
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
- [ ] T017-2: Before implementing the escalation/blocking logic (which
  must target file-modifying tool calls specifically, mirroring Claude
  Code's `Edit`/`Write`/`NotebookEdit` matcher from stage 016), determine
  opencode's own built-in tool name(s) for file-editing operations (e.g.
  whether they're called `edit`, `write`, `patch`, or something else) —
  by inspecting `tool.execute.before`/`tool.execute.after`'s `input.tool`
  value directly in a real opencode session (a minimal canary plugin
  logging every `input.tool` value seen is the fastest way to confirm
  this), rather than assuming Claude Code's naming carries over. Record
  the confirmed name(s) for use in T017-5/T017-6.

## T017-3: JS state-dir and path-mangling helpers
- [ ] T017-3: In the new plugin file (see T017-8), implement
  `askfirstMangleTermPath(path)` and `askfirstStateDir(directory)` in
  plain JS, reproducing exactly the same transform as
  `askfirst_mangle_path()`/`askfirst_state_dir()` (R,
  `bindings/r/R/state.R`) and the bash hooks
  (`agent-hooks/*/post_tool_use.sh`): strip a leading `/`, replace
  remaining `/` with `_`, join under
  `${TMPDIR:-/tmp}/askfirst/<mangled>`, using `process.env.TMPDIR` (or
  Bun's equivalent) and the plugin's own `input.directory` (captured once
  at load time) in place of `getwd()`/the hook payload's `cwd` field. Get
  this exactly byte-for-byte equivalent to the bash implementation, since
  state must be interoperable across whichever coding tool touches a
  project in a given session.

## T017-4: Implement context injection (experimental.chat.system.transform)
- [ ] T017-4: Implement the `experimental.chat.system.transform` hook
  (input `{sessionID?, model}`, mutable `output: {system: string[]}`,
  confirmed present at `@opencode-ai/plugin@1.18.8`): push the same
  `<askfirst-context>` block content currently injected by
  `agent-hooks/claude/session_start.sh` onto `output.system`, adapted to
  describe this plugin's actual mechanism (e.g. replace references to
  Claude Code's `PostToolUse` exit-code-2 convention with a description of
  the `tool.execute.before`-throw blocking behavior from T017-6, and the
  tmp-root state location from T017-3 rather than any project-relative
  path).

## T017-5: Implement notice-log flush and escalating reminder (tool.execute.after)
- [ ] T017-5: Implement `tool.execute.after` (input
  `{tool, sessionID, callID, args}`, mutable `output: {title, output,
  metadata}`): on every call, append the one-shot `log` file's content
  (from `askfirstStateDir()`) into `output.output` (never replacing the
  tool's real result) and delete the log file, mirroring
  `post_tool_use.sh`'s log-flush logic exactly. Additionally, when
  `input.tool` matches the file-editing tool name(s) confirmed in T017-2,
  check `unresolved-notice/` for any marker files and append the same
  escalating reminder text/thresholds from stage 016 (level-1 wording for
  the first 1-2 occurrences, "REPEATED" level-2 wording from the 3rd
  occurrence onward), using a per-package repeat-count file under
  `unresolved-notice-count/` exactly as `agent-hooks/*/post_tool_use.sh`
  does.

## T017-6: Implement the blocking stop-and-ask gate (tool.execute.before)
- [ ] T017-6: Implement `tool.execute.before` (input
  `{tool, sessionID, callID}`, mutable `output: {args}`): if any file
  exists under `pending/` (from `askfirstStateDir()`), throw an `Error`
  whose message is that pending file's content (or a concatenation if
  multiple exist) — per opencode's own documented pattern for aborting a
  tool call (the `.env`-file-blocking example in its plugin docs). This is
  the equivalent of Claude Code's `PostToolUse` exit-code-2/stderr-as-
  reason blocking convention, but via a thrown error instead. Confirm
  during T017-15's smoke test whether this actually blocks every tool
  call unconditionally (per this stage's Open Questions) — if it doesn't,
  document the actual observed scope precisely rather than assuming full
  coverage.

## T017-7: Implement pending-clear on a new turn (chat.message)
- [ ] T017-7: Implement `"chat.message"` (input `{sessionID, agent?,
  model?, messageID?, variant?}`, mutable `output: {message, parts}`):
  clear (recursively remove) the `pending/` directory under
  `askfirstStateDir()`, mirroring `user_prompt_submit.sh`'s behavior.
  Leave `unresolved-notice/` untouched — that marker is not cleared by a
  new turn, only by an explicit resolution (matching stage 016's
  decision). Flag in code comments that this hook's exact firing
  semantics (once per new user turn, as needed) are unconfirmed until
  T017-15's smoke test.

## T017-8: Assemble the single, dependency-free plugin file
- [ ] T017-8: Create `agent-hooks/opencode/askfirst-plugin.js` combining
  T017-3 through T017-7 into one default-exported async function matching
  `Plugin`'s shape (`(input) => Promise<Hooks>`), written in plain JS with
  no `import`/`require` statements and no TypeScript syntax, so it can be
  copied into a consuming project with no `node_modules` or build step
  required. Add a version marker comment at the top of the file (e.g.
  `// askfirst-hook-version: 4`) matching the convention
  `askfirst_hook_version_from_file()` (R) already uses for the bash hooks,
  bumped from the current `3` set in stage 016 (see T017-12 for the
  R-side regex change needed to recognize this `//`-style marker in
  addition to the existing `#`-style one).

## T017-9: Unit tests for the plugin's pure logic
- [ ] T017-9: Add a `bun test`-based suite (this repo's `.opencode/`
  already has a `bun.lock`) covering `askfirst-plugin.js`'s pure logic in
  isolation: path mangling (matching the R/bash test cases from stage
  016's `test-log.R`), escalation wording/threshold transitions (level-1
  vs. "REPEATED" level-2 after 3 occurrences), and log-flush behavior
  (content correctly moved into `output.output` and the source file
  deleted). Mock or stub the `PluginInput`/hook `input`/`output` shapes
  directly rather than requiring a real opencode process to run these
  tests.

## T017-10: Rework the installer's opencode branch to install the plugin, not shell scripts
- [ ] T017-10: In `tools/install-agent-hooks.sh`, restructure the
  currently-unconditional `write_session_start`/`write_post_tool_use`/
  `write_user_prompt_submit` + per-tool `register_hooks_*` sequence so
  that `--tool opencode` instead: creates `.opencode/plugins/` and copies
  (or writes, if the plugin content is embedded per T017-11) the plugin
  file there as e.g. `.opencode/plugins/askfirst-plugin.js`; does **not**
  call `write_session_start`/`write_post_tool_use`/
  `write_user_prompt_submit` (no `.opencode/hooks/*.sh` files at all
  anymore) or `register_hooks_opencode()` (no `opencode.json`
  registration needed for a local, auto-discovered plugin, per opencode's
  own docs). Keep the Claude Code (`--tool claude`) install path
  completely unchanged.

## T017-11: Embed the plugin content in the installer, update the generator
- [ ] T017-11: Update `tools/generate-install-hooks.sh` to also splice
  `agent-hooks/opencode/askfirst-plugin.js`'s content into a new heredoc
  marker (e.g. `PLUGIN_HOOK`) in `tools/install-agent-hooks.sh`'s new
  plugin-writing function (from T017-10), following the exact same
  awk-based splicing pattern already used for `SESSION_HOOK`/`POST_HOOK`/
  `USER_PROMPT_HOOK`. Update the script's header comment, which currently
  states "`agent-hooks/claude/` and `agent-hooks/opencode/` are kept
  byte-identical to each other, so `claude/` is used as the single
  source" — that invariant no longer holds for the opencode side once its
  mechanism is a JS plugin rather than a shell-script family; clarify that
  `agent-hooks/opencode/askfirst-plugin.js` is now its own independent
  source, spliced separately from the three Claude Code shell scripts.

## T017-12: Update hook-version detection for the JS plugin marker
- [ ] T017-12: In `bindings/r/R/hooks_status.R`:
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
- [ ] T017-13: Once T017-10/T017-11 are wired up and T017-15's smoke test
  confirms the plugin mechanism actually works, delete
  `agent-hooks/opencode/session_start.sh`,
  `agent-hooks/opencode/post_tool_use.sh`, and
  `agent-hooks/opencode/user_prompt_submit.sh` outright — per this
  stage's explicit decision, no defense-in-depth fallback is kept once the
  real mechanism supersedes them.

## T017-14: Update tests for the new opencode install path and version marker
- [ ] T017-14: In `bindings/r/tests/testthat/test-install-agent-hooks.R`:
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
- [ ] T017-15: Update `bindings/r/vignettes/using-askfirst.Rmd` and
  `bindings/r/vignettes/askfirst-development.Rmd` wherever they describe
  `askfirst_install_agent_hooks()`/`tools/install-agent-hooks.sh`'s
  behavior, to describe the opencode path as installing a single plugin
  file into `.opencode/plugins/` (auto-discovered, no registration step)
  rather than three registered shell hooks — distinctly from the Claude
  Code path, which is unchanged.

## T017-16: Manual smoke-test against a real opencode session
- [ ] T017-16: Using the confirmed-current `~/.opencode/bin/opencode`
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
- [ ] T017-17: Run the full `bindings/r` test suite (`devtools::test()`)
  and `devtools::check()` from `bindings/r/`, confirm no regressions from
  T017-12/T017-14's R-side changes, and fix any failures before this stage
  is considered done.
