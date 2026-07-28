---
created: 2026-07-28T16:42:15Z
agent: claude-sonnet-5
git_hash: fa3d1232f97c92e36c3c00eba29433af7037cc4c
---

# Design Decisions: Add Opencode Plugin

## Summary
Replaced the confirmed-dead `agent-hooks/opencode/*.sh` shell scripts with a real, dependency-free JS plugin (`agent-hooks/opencode/askfirst-plugin.js`) built against opencode's actual `@opencode-ai/plugin` Hooks API, achieving full functional parity with Claude Code's SessionStart/PostToolUse/UserPromptSubmit mechanism, and verified every hook point end-to-end against a real, authenticated opencode session rather than assumed from documentation alone.

## New Design Decisions

### Decision 1: Plugins, not custom Tools
**Chosen:** Implement via opencode's Hooks/Plugin mechanism (`experimental.chat.system.transform`, `tool.execute.before`/`after`, `"chat.message"`), not its separate custom-Tools mechanism (`.opencode/tools/`).
**Rationale:** Every behavior needed (automatic context injection, escalation on the agent's own subsequent edits, blocking any subsequent call) requires intercepting tool calls the agent already makes on its own initiative. A Tool is opt-in -- the agent must choose to call it -- which would reintroduce the exact reachability gap stage 016 fixed (an agent that never calls the tool gets no benefit).
**Tradeoffs:** A native `askfirst_check_scenarios()` custom Tool (nicer discoverability than shelling out to `Rscript`) remains a legitimate but separate, smaller enhancement, deferred to a possible future stage.
**Proposed by:** agent, confirmed by git-user

### Decision 2: `tool.execute.before` throw for the blocking gate, not `permission.ask`
**Chosen:** Throw an `Error` inside `tool.execute.before` whenever a `pending/` sentinel exists, per opencode's own documented abort-a-tool-call pattern.
**Rationale:** Confirmed live against a real session: this fires unconditionally on every tool call regardless of type, achieving the same "block every subsequent call regardless of topic" guarantee as Claude Code's PostToolUse exit-code-2 convention. `permission.ask` was considered and rejected -- it operates only within opencode's own existing permission-gating system, a narrower scope.
**Tradeoffs:** None found; a mid-turn live test (sentinel injected after a first tool call, so no intervening turn-boundary event could clear it) showed a second tool call in the same turn genuinely rejected, with the thrown message surfaced to and correctly relayed by the model.
**Proposed by:** joint (opencode's own docs plus live verification)

### Decision 3: Single, dependency-free JS file; named ES export required
**Chosen:** `askfirst-plugin.js` uses only Node/Bun builtins (`fs`, `path` via `require()`), no `node_modules`; exports exactly one binding, `export const AskfirstPlugin = async ({directory}) => {...}` -- a named ES export, not `export default` and not CommonJS `module.exports`.
**Rationale:** Live testing found opencode's plugin loader tries to invoke *every* exported binding in a plugin file as if it were a `Plugin` function. A first implementation attempt used `module.exports`, which does not match what opencode's loader looks for; a later attempt at exporting an unrelated helper function alongside the real plugin (for easier unit testing) caused plugin loading to hang entirely, since the loader tried invoking that helper too with a `PluginInput`-shaped argument it couldn't handle.
**Tradeoffs:** Internal helper functions (state-dir mangling) cannot be exported for direct unit testing; tests instead exercise them indirectly through the one real exported plugin function, invoked exactly as opencode itself invokes it.
**Proposed by:** agent (discovered via live testing)

### Decision 4: State-storage mangling scheme reused exactly, computed from `PluginInput.directory`
**Chosen:** The plugin reimplements stage 016's exact path-mangling scheme (leading `/` stripped, remaining `/` replaced with `_`, joined under `${TMPDIR:-/tmp}/askfirst/<mangled>`), keyed off `directory` (opencode's analog of `cwd`/`getwd()`), independently duplicated in JS rather than shared via a common module across languages.
**Rationale:** State must be interoperable regardless of which coding tool (R process, Claude Code hook, or opencode plugin) touches a project in a given session. Confirmed live: the plugin's self-computed state directory matched exactly the path independently computed by hand, and state written by one mechanism was correctly found and consumed by another.
**Proposed by:** agent
**Relates to:** Stage 016 (the tmp-root relocation and mangling scheme this reuses)

### Decision 5: Installer and version-marker convention extended, not duplicated
**Chosen:** `tools/install-agent-hooks.sh --tool opencode` now installs one file into `.opencode/plugins/` (auto-discovered, no `opencode.json` registration -- confirmed against opencode's own docs and empirically), replacing the prior three-shell-script install and its (already-suspected-inert) config-registration step entirely. `tools/generate-install-hooks.sh` gained a fourth spliced source (`PLUGIN_HOOK`, from `agent-hooks/opencode/askfirst-plugin.js`), alongside the three existing Claude Code shell-script sources. The hook-version marker convention was extended (not replaced) to recognize a `// askfirst-hook-version: <N>` JS-comment form alongside the existing `#`-style shell-comment form, with `askfirst_hooks_manifest()`/`agent-hooks/manifest.json` gaining a per-tool `marker_file` field (previously hardcoded to `session_start.sh` for every tool).
**Rationale:** Keeps a single shared `hook_version` counter and a single installer script covering both tools' genuinely different install mechanisms, rather than forking into parallel tooling.
**Tradeoffs:** Bumping the shared `hook_version` to `4` required also bumping Claude Code's own marker files to `4` (even though this stage didn't change their content) -- otherwise correctly-installed Claude Code hooks would have incorrectly reported as `"stale"`. This is the same convention stages 014-016 already followed (bump all markers together on any shared-counter change).
**Proposed by:** agent

## Integration with Prior Work
Directly resolves stage 016's own flagged follow-up ("a real JS/TS opencode plugin" as "the top candidate for a future stage") and the entangled harness-side finding in `askfirst-tests/recommendations.md` (opencode hook delivery never confirmed to reach the model) by replacing the mechanism the harness would otherwise have had to keep working around. Reuses stage 016's state-relocation model exactly (Decision 4 above) and stages 014/015's hook-version marker convention (Decision 5), extended rather than reinvented.

## Issues Resolved
- `agent-hooks/opencode/*.sh` never actually invoked by real opencode (stage 016's finding) -- resolved by replacing with a real, verified JS plugin.
- Whether opencode hook delivery could be trusted at all (`askfirst-tests/recommendations.md`'s open harness question) -- resolved with direct, positive evidence for all three mechanism halves (context injection, escalation, blocking), not just documentation.
- The prior (already-suspected-inert) `.opencode/settings.json` config-registration step -- removed entirely, confirmed unnecessary via opencode's own auto-discovery docs.

## Deferred Items
- A native `askfirst_check_scenarios()` custom Tool for opencode (nicer discoverability) -- legitimate but separate enhancement, not attempted this stage.
- Re-running the `askfirst-tests` harness's own trial matrix against the new plugin to re-measure compliance rates -- lives in that sibling repo's own workflow.

## Process Notes
- A significant fraction of this stage's real design work happened through direct empirical testing against a real, authenticated opencode session (using a free-tier model, `opencode/deepseek-v4-flash-free`) rather than documentation or type-signature inspection alone -- this surfaced two things neither the docs nor the vendored type definitions stated: the named-ES-export requirement (Decision 3) and the precise timing of `"chat.message"` relative to tool calls within a turn (informing Decision 2's realistic test design).
- A version mismatch in this repo's own local dev environment (vendored `@opencode-ai/plugin` pinned to `1.1.23` while the actually-installed `opencode` CLI was `1.18.8`, due to a stale `/usr/bin/opencode` shadowing a correctly-updated `~/.opencode/bin/opencode` earlier in `$PATH`) was found and fixed during planning, before implementation began -- resolving what had initially looked like a genuine API-surface gap between opencode's docs and its SDK.
