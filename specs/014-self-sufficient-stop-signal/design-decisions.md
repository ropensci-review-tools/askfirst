---
created: 2026-07-28T09:26:31Z
agent: claude-sonnet-5
git_hash: 6999676a3066babc769b0b934d8a493cd707f900
---

# Design Decisions: Self-Sufficient Stop Signal

## Summary
Resolved a field-reported failure where an agent read a hooks-reinforced `stop-and-ask` signal and offered a workaround as a menu option anyway, by reopening stage 007/011's neutral-message-text trust boundary: `askfirst_signal()` now embeds a fixed, imperative hard-stop block directly in message text for every `stop-and-ask` signal, unconditionally. A companion cross-language hook-installation check was added in the same stage to nudge humans toward the trusted-hooks path where it remains available.

## New Design Decisions

### Decision 1: Message text becomes self-sufficient for `stop-and-ask` signals
**Chosen:** `askfirst_signal()` assembles a bounded hard-stop block — fixed start delimiter, fixed first-person-to-agent consequence text, the existing `askfirst::<lang>::<pkg>::<type>`/`directive:` line pair, the package-authored body, a fixed end delimiter, then the `See:` URL — for `askfirst_error_redirect`, `askfirst_capability_gap`, and `askfirst_scenario_check`. `askfirst_notice` instead gets a short, non-halting forward-reference sentence.
**Rationale:** Many sessions run without `agent-hooks/` installed, or with stale hooks predating a fix; the field report showed the signal failed even with hooks present. The instruction must work without hook-taught interpretation.
**Tradeoffs:** Reopens exposure to a deliberately spoofing package, since no hook context vouches for message-text legitimacy absent hooks; emitted unconditionally rather than escalating only once hooks are confirmed current, trading a residual guardrail-rejection risk for implementation simplicity.
**Proposed by:** joint
**Relates to:** Stage 007 (Decision 4, the boundary reopened here), Stage 011 (Decision 1, the hooks-only reinforcement this supersedes for `stop-and-ask` signals), Stage 012 (directive severity this builds on)

### Decision 2: Fixed text interpolates `pkg` via `sprintf`, not glue syntax
**Chosen:** The new delimiter/consequence/prime strings interpolate `pkg` directly inside `askfirst_signal()` via `sprintf()`, rather than embedding `{pkg}` glue syntax resolved through the caller-supplied `.envir`.
**Rationale:** `askfirst_capability_gap()` resolves glue interpolation against the *adopting function's own frame* (so package authors can reference their own local variables), which generally has no variable named `pkg` — `{pkg}` there would error rather than resolve.
**Proposed by:** agent

### Decision 3: Hook-installation detection added to this stage, not deferred
**Chosen:** A hand-maintained `agent-hooks/manifest.json` and a `# askfirst-hook-version:` marker line in the canonical hook scripts back a new `askfirst_hooks_status()` check, called once per session from `askfirst_init()` independent of AI-agent confidence. On `not_installed`/`stale`, a human-directed (not agent-directed) nudge points at `tools/install-agent-hooks.sh`.
**Rationale:** Getting hooks installed in the first place complements making message text self-sufficient; the check's manifest/path/version-marker shape is deliberately language-agnostic so future non-R bindings can implement the equivalent without redesign.
**Tradeoffs:** opencode's own config file (`opencode.json`) is discovered via a precedence order across several locations, not a fixed path, so the manifest records only `hooks_dir` (askfirst's own, fixed script-install location) and omits any config path claim for opencode. A related, pre-existing inaccuracy was also found and fixed in the same pass: `tools/install-agent-hooks.sh`'s `detect_tools()` had been auto-detecting opencode via a `.opencode/settings.json` file check that can never actually exist under opencode's real config discovery; that dead detection branch was removed, so opencode must now be selected via explicit `--tool opencode`. The installer's separate opencode config-*registration* path (`TARGET_CONFIG=".opencode/settings.json"`, written post-install) was left unchanged and remains a known, out-of-scope inaccuracy.
**Proposed by:** joint (config-path and detection-branch corrections: mpadge)

### Decision 4: Consequence text redirects to the package's developers, not the human's own judgment
**Chosen:** The fixed consequence text tells the agent to direct the human to ask `{pkg}`'s developers whether/how to add the capability, rather than asking the human to judge whether it belongs upstream.
**Rationale:** The human user typically has no basis to judge that; the package's developers do.
**Proposed by:** mpadge (correction of the agent's first draft)
**Relates to:** Stage 013, Decision 4 (no ambiguous second-person "you" — this stage's "you" unambiguously addresses the agent, while "the human user" and "the developers of `{pkg}`" remain explicitly named, preserving that principle for a newly-introduced addressee)

## Integration with Prior Work
Reopens stage 007's message-text neutrality decision (reaffirmed stage 011) specifically for `stop-and-ask` signals, while keeping its untrusted-body/trusted-structure split intact in spirit: the package-authored body still cannot inject or override the now-stronger fixed structural text around it. Does not alter stage 010's confidence gating or stage 012's directive-severity mapping — only what the message says and how it's laid out. Extends stage 013's referent-naming principle to a case that stage previously avoided entirely (the agent as an explicit "you").

## Issues Resolved
- Field report: agent read a hooks-reinforced `stop-and-ask` signal and offered a workaround as a menu option anyway — resolved via a self-sufficient, delimited hard-stop message shape that doesn't depend on hook-taught interpretation.
- No mechanism existed to detect or nudge toward installing/updating `agent-hooks/` at all — resolved via `askfirst_hooks_status()` and a load-time human-directed nudge.

## Deferred Items
- Anti-spoofing mechanism (signing, checksums, allowlisting) for message-text legitimacy in sessions without hooks — flagged as a future-stage candidate, not attempted here.
- Fixing `tools/install-agent-hooks.sh`'s pre-existing opencode config-*registration* path (`TARGET_CONFIG=".opencode/settings.json"`, written after install), which likely never matches opencode's actual config discovery — out of scope; only the always-false opencode *detection* branch in `detect_tools()` was removed this stage, not the separate registration-write path.

## Process Notes
- The imperative consequence wording went through one explicit correction: the first draft asked the human to judge whether a capability belongs upstream; revised to direct the human to ask the package's own developers instead, since they are the ones who would know.
- Whether hard-stop strength should vary by hook-installation status was raised as an open question in `plan.md` and resolved during `/designlens.make-tasks` review, before task generation, in favor of unconditional emission.
- The opencode `detect_tools()` fix was raised after implementation was otherwise complete, once the config-precedence correction to the new manifest (Decision 3) prompted a closer look at the pre-existing installer's own opencode detection logic.
