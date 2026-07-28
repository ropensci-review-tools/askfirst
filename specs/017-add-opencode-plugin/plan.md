---
created: 2026-07-28T14:25:29Z
agent: claude-sonnet-5
git_hash: da4602035ebe3feb24382d0a557e2c77c2a14b51
---

# Plan: add-opencode-plugin

## Overview
Fix up askfirst's opencode support based on stage 016's finding that opencode's real plugin API is a JS/TS Hooks object (auto-discovered from a project's `.opencode/plugins/` directory, or registered via opencode.json's plugin array for npm-published plugins, executed in-process) rather than the shell-script/stdin-JSON convention agent-hooks/opencode/*.sh assumes, plus askfirst-tests/recommendations.md's harness-side finding that opencode hook delivery was never confirmed to actually reach the model. Build a real, dependency-free JS opencode plugin achieving full parity with the Claude Code hook mechanism: an experimental system-prompt-transform hook for SessionStart-equivalent context injection, `tool.execute.after` for the non-blocking notice-log/escalation-reminder annotations, and `tool.execute.before` (throwing to abort a call, per opencode's own documented `.env`-blocking example) for the blocking stop-and-ask gate equivalent to Claude Code's PostToolUse exit-code-2 convention. Remove the legacy agent-hooks/opencode/*.sh shell scripts and their installation path once the corresponding real hook point is confirmed working, rather than keeping known-dead fallback code.

## Context

This stage is a direct follow-up to two findings that were explicitly
flagged rather than acted on at the time:

- **Stage 016 (escalate-unactioned-notice)**, "Enforcement" decision and
  Deferred Items: investigating opencode's real plugin SDK
  (`@opencode-ai/plugin`, vendored under `.opencode/node_modules/` in this
  repo) found its actual mechanism is a JS/TS `Hooks` object — `tool.
  execute.before`/`tool.execute.after`, `permission.ask`,
  `experimental.chat.system.transform`, etc. — registered via `opencode.
  json`'s `plugin` array and executed in-process by opencode itself. There
  is no `.opencode/hooks/*.sh`-style shell-script-reading-JSON-from-stdin
  convention anywhere in that SDK's type definitions. This means
  `agent-hooks/opencode/{session_start,post_tool_use,user_prompt_submit}.sh`
  — shipped since stage 014, relocated and extended again in stage 016 —
  are very likely never invoked by real opencode at all. Stage 016
  documented this precisely in both hook file copies' header comments
  rather than fixing it, and explicitly flagged "a real JS/TS opencode
  plugin" as "the top candidate for a future stage."
- **`askfirst-tests/recommendations.md`** (a sibling test-harness repo,
  not part of this repo, not yet committed there as of this stage): its
  own section 3 ("What hooks actually changed, per agent") independently
  observed that an opencode trial transcript contained no discrete event
  corresponding to the `SessionStart` hook's context injection — "consistent
  with, but does not prove, the hook content never being injected into this
  run at all." Its section 5 recommendation #2 (tagged "[Harness, not
  askfirst]") called for verifying opencode hook delivery with a canary
  before trusting any with-hooks trial's condition label. That
  recommendation is scoped to the harness's *verification* method; this
  stage addresses the underlying cause directly, by replacing the
  mechanism the harness would otherwise have to keep working around.

Relevant prior decisions this stage builds on:

- **Stage 007**: introduced `agent-hooks/` as the shared, per-tool hook
  source directory and `tools/install-agent-hooks.sh` as the
  binding-agnostic installer.
- **Stage 014/015**: established the `# askfirst-hook-version: <N>` marker
  convention and `agent-hooks/manifest.json`, used by
  `askfirst_hooks_status()` to detect missing/stale installs.
- **Stage 016**: relocated all runtime state (`log`, `pending/`,
  `unresolved-notice/`) from the project's working tree to
  `${TMPDIR:-/tmp}/askfirst/<mangled-abs-project-path>/`, computed
  independently by the R process (from `getwd()`) and each hook script
  (from its payload's `cwd` field) — this stage's plugin must compute the
  identical path from opencode's own equivalent value (`PluginInput.
  directory`), so state stays interoperable regardless of which coding
  tool touches a project in a given session. Stage 016 also added the
  non-blocking, escalating "unresolved notice" reminder this stage's
  `tool.execute.after` equivalent must reproduce.

**Update, resolved during plan review**: fetching opencode's own published
docs (`opencode.ai/docs/custom-tools`, `opencode.ai/docs/plugins`), then
discovering and correcting a real version mismatch in this repo's own dev
environment, resolved every open question this plan originally carried
about the plugin API surface:
- **Plugin auto-discovery is real and documented**: local plugin files
  placed in a project's `.opencode/plugins/` directory (plural) are
  "automatically loaded at startup," no `opencode.json` registration
  needed — registration in the `plugin` array is only for npm-published
  plugins, which "are installed automatically using Bun at startup." This
  mirrors the already-confirmed `.opencode/tools/` auto-discovery
  convention this repo's own `.opencode/tools/get_session_stats.{py,ts}`
  pair already uses (a Python script wrapped by a thin TS/JS file — direct
  existing-repo precedent for "any language implementation, JS/TS wrapper
  for discovery").
- **`tool.execute.before` can abort a call, not just modify its args**: the
  docs describe this hook as permitting "modification or abortion of tool
  calls," with a worked example throwing an error to block `.env` file
  reads. This is confirmed as the mechanism for the blocking stop-and-ask
  gate — it fires unconditionally on every tool call, more directly than
  `permission.ask` (which operates only within opencode's existing
  permission-gating system, not as an independent authorization layer).
- **The apparent "version drift" was real, but has been fixed, and turned
  out to be a false alarm about hook coverage regardless.** This repo's
  vendored dev dependency (`.opencode/package.json`) was pinned to
  `@opencode-ai/plugin@1.1.23`, while the actually-installed `opencode` CLI
  in this environment was `1.18.8` — a genuine local-environment mismatch
  (a stale `/usr/bin/opencode` shadowing a correctly-updated
  `~/.opencode/bin/opencode` earlier in a different `$PATH` entry).
  Bumping the vendored dependency to `^1.18.8` (`bun add
  @opencode-ai/plugin@latest`) and re-reading the real, current type
  definitions resolved the mystery cleanly: every hook this plan needs —
  `experimental.chat.system.transform`, `tool.execute.before`,
  `tool.execute.after`, `permission.ask`, `"chat.message"` — is present and
  stable at 1.18.8 (with minor shape evolution, e.g.
  `experimental.chat.system.transform`'s input gained a `model` field and
  made `sessionID` optional). The docs' apparently "richer" hook table
  (`session.created`, `file.edited`, `message.updated`, `permission.
  replied`, `command.executed`, `lsp.*`, `tui.*`, etc.) turned out not to
  be separate Hooks methods at all — confirmed directly against
  `@opencode-ai/sdk`'s vendored `Event` union type, every one of those
  names is a `type:` discriminant value of that union, all dispatched
  through the single generic `event?: (input: {event: Event}) =>
  Promise<void>` hook, not independent top-level Hooks fields. There was
  no real API gap to design around.

Out of scope for this stage: re-running the `askfirst-tests` harness's own
trial matrix to re-measure compliance rates now that a real opencode
mechanism exists — that lives in that sibling repo's own workflow, not
here. This stage's own verification is limited to confirming the plugin's
hook points fire and behave as designed against a real opencode session.

**Considered and rejected during plan review: implementing this as a
custom Tool instead of a Plugin.** opencode's `.opencode/tools/` mechanism
(also auto-discovered, and already used in this repo's own dev setup via
`.opencode/tools/get_session_stats.{py,ts}`) defines *new* functions the
agent may choose to call — structurally the same category as
`askfirst_check_scenarios()` itself (agent-invoked, opt-in). Every piece of
this stage's actual need — automatic context injection at session start,
an escalating reminder on the agent's *own* subsequent Edit/Write calls
regardless of whether it thinks to check anything, and blocking *any*
subsequent tool call while a stop-and-ask is pending — requires
intercepting tool calls the agent already makes on its own initiative, not
adding a new one it might choose to invoke. Building this as a Tool instead
of a Plugin would reintroduce the exact reachability gap stage 016 fixed:
an agent that never calls the new tool gets no benefit from it at all.
Exposing `askfirst_check_scenarios()` itself as a native custom Tool
(nicer discoverability than shelling out to `Rscript`) is a legitimate but
separate, smaller enhancement — deferred as its own possible future stage,
not part of this one.

## Design Goals

1. **Achieve full functional parity with Claude Code's three hook points**
   using opencode's actual, documented plugin mechanism — not another
   unverified shell-script fallback. Concretely: context injection
   (SessionStart-equivalent), non-blocking annotation/escalation
   (PostToolUse-equivalent, non-blocking half), and the blocking
   stop-and-ask gate (PostToolUse-equivalent, blocking half), plus clearing
   the pending sentinel on a new user turn (UserPromptSubmit-equivalent).
2. **Ship as a single, dependency-free JS file.** `@opencode-ai/plugin`'s
   `Plugin`/`Hooks` shapes are TypeScript types only (compile-time,
   erased); the package's only runtime export (`tool()`, for defining new
   tools with zod-validated arguments) is not needed here, since this
   plugin only implements existing hook points, not new tools. A plain
   `.js` file requiring no imports and no `node_modules` in the consuming
   project matches this project's existing self-contained-script
   distribution model (the bash hooks, `tools/install-agent-hooks.sh`)
   rather than introducing a new npm-dependency-based install story.
3. **Reuse stage 016's state model exactly**, not a parallel one: the
   plugin computes `${TMPDIR:-/tmp}/askfirst/<mangled-path>/...` using the
   identical mangling scheme (leading `/` stripped, remaining `/` replaced
   with `_`) already implemented in R (`askfirst_mangle_path()`) and bash
   (`agent-hooks/*/post_tool_use.sh`), keyed off `PluginInput.directory`
   (opencode's analog of `cwd`/`getwd()`).
4. **Verify empirically against a real session, not just the type
   definitions.** The plugin API surface itself is now confirmed directly
   against the installed `opencode@1.18.8`'s own type definitions, not
   assumed from docs or a stale vendored copy — but whether
   `tool.execute.before`'s abort-via-throw actually covers every tool call
   unconditionally in practice (matching Claude Code's "block every
   subsequent call regardless of topic" guarantee) is still a runtime
   behavior, not something the type signature alone proves. Must be
   confirmed against a real opencode session before this stage is
   considered done; any gap found must be documented honestly rather than
   silently assumed away.
5. **Remove the confirmed-dead shell scripts once superseded.** Per
   explicit decision, no defense-in-depth fallback: once a real hook
   point's plugin equivalent is implemented and verified,
   `agent-hooks/opencode/*.sh` and its corresponding
   `tools/install-agent-hooks.sh` installation step are deleted outright,
   not kept alongside the new mechanism "just in case."

## Proposed Approach

- **New file**: `agent-hooks/opencode/askfirst-plugin.js` — a single
  default-exported async function matching `Plugin`'s shape (`(input:
  PluginInput) => Promise<Hooks>`), written in plain JS with no `import`
  statements and no TypeScript syntax, so it can be copied into a
  consuming project exactly like the bash scripts are today, with no
  `node_modules` or build step required at install time.
- **State helpers (JS)**: reimplement `askfirst_mangle_path()`/
  `askfirst_state_dir()`'s logic directly in the plugin file (no shared
  module across languages — each binding/mechanism keeps its own
  self-contained copy, consistent with how the bash hooks already
  duplicate this logic rather than sourcing a shared script), keyed off
  `input.directory` captured once when the plugin is loaded.
- **Hook mapping** (confirmed against `@opencode-ai/plugin@1.18.8`'s real
  type definitions):
  - System-prompt injection (SessionStart-equivalent):
    `experimental.chat.system.transform` — input `{sessionID?: string,
    model: Model}`, mutable `output: {system: string[]}`. Append the same
    `<askfirst-context>` block content as `session_start.sh` to
    `output.system`.
  - `tool.execute.after` — input now also carries `args` (in addition to
    `tool`, `sessionID`, `callID`), output unchanged: `{title, output,
    metadata}`. On every tool call, flushes the one-shot `log` file's
    content into `output.output` (appended, not replacing the tool's real
    result) exactly as `post_tool_use.sh` does; for file-modifying tools
    specifically, checks `unresolved-notice/` and appends the same
    escalating reminder text/thresholds from stage 016, using the same
    per-package repeat-count file convention.
  - Blocking stop-and-ask gate: implemented via `tool.execute.before`
    (input `{tool, sessionID, callID}`, mutable `output: {args}`),
    throwing an error while any `pending/` sentinel file exists — per
    opencode's own documented pattern for aborting a tool call (the
    `.env`-blocking example). Fires unconditionally on every tool call,
    matching Claude Code's "block every subsequent call regardless of
    topic" guarantee more directly than `permission.ask` would (that hook
    operates only within opencode's existing permission-gating system).
    `permission.ask` remains a documented fallback if empirical testing
    against a real session finds `tool.execute.before`'s abort behavior
    narrower than expected in practice.
  - Pending-clear (UserPromptSubmit-equivalent): no hook named anything
    like `UserPromptSubmit` exists even at 1.18.8; the closest candidate
    remains `"chat.message"` ("Called when a new message is received",
    input `{sessionID, agent?, model?, messageID?, variant?}`, mutable
    `output: {message, parts}`). Use it to clear `pending/` the same way
    `user_prompt_submit.sh` does, verifying empirically that it fires once
    per new user turn as needed (see Open Questions).
- **Installer changes**: `tools/install-agent-hooks.sh --tool opencode`
  drops `askfirst-plugin.js` into the project's `.opencode/plugins/`
  directory (confirmed auto-discovered, no `opencode.json` registration
  needed for local file-based plugins per opencode's own docs), replacing
  the current (dead) `.opencode/hooks/*.sh` installation step entirely.
- **Removal**: delete `agent-hooks/opencode/{session_start,post_tool_use,
  user_prompt_submit}.sh` once their plugin equivalents are implemented
  and verified. Update `tools/generate-install-hooks.sh` and its
  documented assumption that `agent-hooks/claude/` and `agent-hooks/
  opencode/` are byte-identical shell scripts — that invariant no longer
  holds once opencode's mechanism is a JS plugin rather than a shell
  script family, and the corresponding regression test
  (`test-install-agent-hooks.R`'s byte-identity check) needs updating to
  match.
- **Testing**: a `bun test`-based unit suite (this repo's `.opencode/`
  dev setup already has a `bun.lock`) for the plugin's pure logic
  (mangling, escalation wording/thresholds, log-flush behavior) mirroring
  the bash-side smoke tests done in stage 016. A manual, real-opencode-
  session smoke test (installing the plugin, triggering a notice, and
  confirming each hook point's effect is actually observed) is the real
  verification step, directly closing both stage 016's and
  `askfirst-tests/recommendations.md`'s open questions about whether
  opencode hook delivery can be trusted at all.

## Open Questions

- **Does `tool.execute.before`'s documented abort-via-throw behavior cover
  every tool call unconditionally**, matching Claude Code's "block every
  subsequent call regardless of topic" guarantee, or are there tool types
  it can't intercept? The docs example (blocking `.env` reads) demonstrates
  the mechanism but not its full scope, and the type signature alone can't
  prove runtime behavior — confirm empirically early in implementation,
  since Design Goal 1's "full parity" framing depends on it.
- **Is `"chat.message"` the right hook to clear the pending sentinel on a
  new user turn**, or does some other event fire more precisely at that
  boundary (e.g. a `session.*`/`message.*` value delivered through the
  generic `event` hook instead)? No hook named anything like
  `UserPromptSubmit` exists even at the current 1.18.8 API — needs
  confirming empirically against a real multi-turn session.
- **Keeping the injected `<askfirst-context>` text in sync between
  `session_start.sh` (Claude Code) and the new plugin's system-prompt-
  injection hook body** — manually duplicated (as today, across
  `agent-hooks/claude/` and `agent-hooks/opencode/`) or extracted into one
  shared source both a bash heredoc and a JS string literal are generated
  from? No strong constraint surfaced yet; decide during implementation.
- **Whether to also bump `tools/generate-install-hooks.sh`'s and this
  repo's own `.opencode/package.json` version pin as a durable fix**
  (already bumped to `^1.18.8` during this plan's review, so future `bun
  install` runs in this repo don't silently drift stale again) — confirm
  this stays committed as part of this stage's own changes, not just a
  transient local fix made during planning.
