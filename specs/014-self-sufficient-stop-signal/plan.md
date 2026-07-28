---
created: 2026-07-28T08:50:47Z
agent: claude-sonnet-5
git_hash: 096d0a5a43d65401c18badff63524b8dd6df8fb6
---

# Plan: self-sufficient-stop-signal

## Overview
Reopen the stage 007/011 message-text trust boundary: make askfirst_signal() message text self-sufficient for stop-and-ask signals, carrying an unambiguous hard-stop delimiter, first-person imperative consequence, and bounded instruction block, so an agent is halted correctly even without pre-loaded agent-hooks context — closing a field-reported gap where a hooks-reinforced signal still failed to stop a workaround

## Context
A field report (`askfirst-advice.md`) describes an AI agent that read a `stop-and-ask` signal — already carrying stage 011/012's structured `askfirst::<lang>::<pkg>::<type>` prefix and `directive: stop-and-ask` line — and offered a workaround as a menu option anyway. The agent's own diagnosis: the message body reads as ordinary R error/package output (credits, URL, backtrace) with the actual directive buried inline, and nothing in the *message text itself* unambiguously says "this is an instruction to you, the agent, not content to reason over."

This sits directly on top of a deliberate architecture decision from stage 007 (reaffirmed in stage 011): message text emitted by `askfirst_signal()` (bindings/r/R/conditions.R) is package-authored and therefore untrusted/spoofable by any adopting package, so it was stripped of second-person/imperative phrasing specifically to avoid triggering prompt-injection guardrails. Behavioral instruction strength was instead placed entirely in `agent-hooks/*/session_start.sh` — pre-loaded, trusted, non-package content — which teaches the agent to recognize the prefix and treat `stop-and-ask` as a hard gate (stage 011 decision 1, stage 012 decisions 1–3).

Discussed with the user: given the field report shows even the hooks-reinforced version still failed, and that many sessions will never have `agent-hooks/` installed (or will have stale hooks predating this stage's changes) at all, the trust boundary itself is being reopened. Decision: message text becomes self-sufficient for `stop-and-ask` signals — it must carry the full instruction and consequence on its own — rather than depending on hook-taught interpretation. This creates two interfaces to the same underlying signal: (1) hooks installed and current — hooks reinforce/prime recognition of the now-stronger message text; (2) no hooks, or stale hooks predating this change — the message text alone must still halt the agent. This stage implements interface (1) reinforcement and interface (2) self-sufficiency together, since both read the same `askfirst_signal()` output; it does not attempt to solve the harder, open-ended problem of proving message-text legitimacy against a *deliberately spoofing* package without hooks (see Open Questions).

Existing literal-text test constraints (bindings/r/tests/testthat/test-init.R, test-scenarios.R) assert presence of `"askfirst::r::mypkg::notice"`, `"directive: notice"`/`"directive: stop-and-ask"`, and `"See: https://ropensci.github.io/askfirst/"` via `expect_match()`/`expect_no_match()` on the rendered message — these are substring checks, not order checks, so the prefix/directive/body/URL can be reordered and a new delimiter block added around them without breaking existing assertions, as long as the literals remain present (and remain fully absent under `prefix = FALSE`).

## Design Goals
- For every `directive: stop-and-ask` signal (`askfirst_capability_gap`, `askfirst_scenario_check`, `askfirst_error_redirect`), the message text emitted by `askfirst_signal()` must, on its own — with no `agent-hooks/` context loaded — read unambiguously as an instruction to the agent to halt and ask the user, not as an error to work around or content to reason over.
- The instruction must arrive before any package credit, contribution URL, or explanatory body text, and must be visually/structurally bounded (clear start/end) so an agent can identify the instructional segment regardless of what a calling tool or R's own error printing appends afterward (e.g. a backtrace outside askfirst's control).
- `directive: notice` (load-time) signals get a lighter, non-halting "prime" addition only — a short forward-reference so the agent already knows what a later `stop-and-ask` block means — not the full stop block, since nothing has gone wrong yet at notice time.
- `agent-hooks/*/session_start.sh` is updated to describe and reinforce the new message-text markers (rather than being the sole carrier of instruction strength), so its guidance stays accurate for hooks-installed sessions instead of duplicating stale wording.
- All four signal classes stay gated by the existing `prefix` argument: `prefix = FALSE` continues to produce a message with none of the structural apparatus (prefix line, directive line, URL, and now the new delimiter/instruction block), preserving the existing test contract for condition-metadata-only tests.
- No change to *which* situations halt or to session-confidence gating (stage 010) — this stage only changes what the message text says and how it's laid out, not when it fires.
- At load time, independent of AI-agent confidence tier, detect whether askfirst-aware agent hooks are installed and current for this project, and if not, nudge the *human* user to install/update them — using a check mechanism whose shape (relative paths, version marker convention) generalizes to future Python/Julia/Rust bindings, not just R, mirroring how `agent-hooks/` is already the single cross-language source of truth for hook content (stage 007 decision 2).

## Proposed Approach

### 1. New message layering in `askfirst_signal()` (bindings/r/R/conditions.R)
Split message assembly into two shapes, both still gated by the existing `prefix` argument:

- **Hard-stop shape** (`directive_map[[class]] == "stop-and-ask"`, i.e. `askfirst_error_redirect`, `askfirst_capability_gap`, `askfirst_scenario_check`): a bounded block ordered as:
  1. A fixed, consistently-worded hard-stop delimiter line (same literal text every time, across every adopting package — the consistency itself is part of what makes it recognizable as structural rather than ad hoc package prose).
  2. A first-person-to-agent imperative consequence statement, non-package-authored (fixed template text, only `{pkg}` interpolated) — states plainly that the agent must not implement, draft, or offer a workaround this turn, and must ask the user instead.
  3. The existing structured line pair: `askfirst::<lang>::<pkg>::<type>` then `directive: stop-and-ask`.
  4. The (still package-authored) body `message` text.
  5. A fixed resume/end delimiter line, closing the bounded block.
  6. The `See: <url>` line, placed *after* the resume marker so it reads as trailing attribution rather than diluting the instruction.
- **Notice shape** (`askfirst_notice`): keep the current prefix/directive/body/URL layout, and append one short fixed forward-reference sentence after the body (before the URL) priming the agent for what a later stop-and-ask block from this package means.

Keep the imperative/delimiter text itself fixed and non-interpolated (aside from `{pkg}`) so it cannot be overridden or diluted by an adopting package's own `notice`/`message` arguments — those remain confined to the body position inside the block, consistent with the existing untrusted-body / trusted-structure split, just with the structural part now doing more work.

### 2. Update `agent-hooks/claude/session_start.sh` (and keep `agent-hooks/opencode/*` byte-identical, then regenerate the installer)
Revise the `<askfirst-context>` block so its guidance describes the new delimiter markers and confirms their meaning, rather than being the first or only place the agent learns that `stop-and-ask` is non-negotiable. Rule 6 (no workaround-as-menu-option in the same turn) stays, now framed as reinforcing what the message text itself already states. After editing, run `tools/generate-install-hooks.sh` to resync the embedded copy in `tools/install-agent-hooks.sh` (per stage 012 decision 4), and keep `agent-hooks/opencode/session_start.sh` byte-identical to the Claude version as today.

### 3. Update roxygen docs in `conditions.R`
`askfirst_signal()`'s existing extensive doc comment describes the current prefix/directive/URL layout in detail; revise it to document the new hard-stop vs. notice shapes, the fixed vs. package-authored text boundary, and why the delimiter/consequence text is deliberately non-interpolated.

### 4. Update tests
- `test-init.R`: add assertions for the new fixed delimiter/consequence literals on a `stop-and-ask`-class signal (use `askfirst_capability_gap` or a directly-constructed `askfirst_signal()` call, matching the file's existing pattern of testing `askfirst_signal()` directly), and confirm they are absent under `prefix = FALSE`. Keep existing notice-class assertions intact; add one for the new short forward-reference sentence.
- `test-scenarios.R`: update `askfirst_build_scenario_check_message()`-adjacent tests (this text is inserted into the hard-stop body, unaffected in content, but confirm it still renders correctly inside the new block).
- `test-capability-gap.R`: confirm existing domain-specific substring assertions (`"grouped input"`, etc.) still pass with the new surrounding structure.
- `test-install-agent-hooks.R`: no change expected (asserts installer structure, not message text), but re-run after step 2's regeneration to confirm no drift.

### 5. Hook-installation detection, shared across languages
- Add a small language-agnostic manifest (e.g. `agent-hooks/manifest.json`, sitting alongside `agent-hooks/claude/` and `agent-hooks/opencode/`) listing, per supported tool key (`claude`, `opencode`, future tools), the project-relative config path (e.g. `.claude/settings.json`) and hooks directory (e.g. `.claude/hooks/`), plus a single incrementing version marker for the current canonical hook content.
- Add a version-marker comment line (e.g. `# askfirst-hook-version: N`) into the canonical `agent-hooks/claude/session_start.sh`/`post_tool_use.sh` templates, propagated by `tools/generate-install-hooks.sh` into the embedded installer copies (per stage 012 decision 4) and thus into any hooks actually written by `tools/install-agent-hooks.sh`.
- Implement a filesystem-only check — no dependency on `agent-hooks/manifest.json` being present at the install location; each binding embeds its own compiled-in copy, analogous to how the installer embeds hook content — that, for each known tool key, looks for the hooks directory/file relative to the current working directory and, if found, reads the version marker. Reports one of `not_installed` / `stale` / `current`.
- In R, implement this as an internal function (e.g. `askfirst_hooks_status()`), called from `askfirst_init()`. On `not_installed`/`stale`, emit a message directed at the human user pointing at `tools/install-agent-hooks.sh` (or the package's own installer wrapper if one exists) — shown independent of AI-agent confidence tier, since the whole reason to show it is that hooks context can't be relied on to reach the agent at all in this state.
- Keep the manifest/version-marker convention identical in shape across future bindings (same relative paths, same marker format) so a Python/Julia/Rust binding can implement the equivalent check without redesigning the underlying scheme.

### 6. `askfirst-advice.md`
This file is the source field report driving this stage; leave it at the repo root as-is (it's the origin document, not generated output) — no action needed unless the user wants it archived into `specs/014-self-sufficient-stop-signal/` as supporting material.

## Open Questions
- ~~Whether hard-stop message strength/structure/emission should itself be conditioned on detected hook-installation status.~~ **Resolved:** always emit the full hard-stop shape regardless of `askfirst_hooks_status()` result. Stage 007's rationale for stripping imperative/second-person language depended on hooks context vouching for legitimacy, and no-hooks sessions lose that protection — but the decision is to accept the residual guardrail-rejection risk in that case as the lesser failure mode versus a workaround slipping through unchallenged, rather than add a runtime dependency between the message-shape and hook-detection mechanisms. The load-time human-directed install nudge (§5) is the mitigation for the no-hooks case, not a softer message shape.
- Exact wording of the fixed delimiter and imperative-consequence lines — draft during implementation and confirm with the user before finalizing, since these are the literal strings every future adopting package's users will see, and are the hardest to change again later without another drift/versioning concern.
- Whether R's own error-printing (backtrace, `options(error = ...)` chaining) can ever be fully suppressed after the resume marker, or whether askfirst can only guarantee its own block is well-bounded regardless of what trails it — needs a small empirical check during implementation (e.g. does `rlang::abort()` under this project's typical calling context print a backtrace by default, and if so, is it within askfirst's control at all).
- Longer-term, unresolved by this stage: reopening the trust boundary means message text now carries real instructional weight without hooks to vouch for it — this reintroduces exposure to a *deliberately spoofing* adopting package faking the askfirst format to manipulate agent behavior for ends unrelated to the real askfirst project. No mechanism (signing, checksums, allowlisting) is proposed here; flagged as a candidate for a future stage rather than solved now, per the user's note that "the trust boundary has two interfaces" and hooks-based verification remains the stronger of the two where available.
