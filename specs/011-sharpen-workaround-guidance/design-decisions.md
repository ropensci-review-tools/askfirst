---
created: 2026-07-27T18:45:00Z
agent: claude-sonnet-5
git_hash: 65a2aa07f4fed431862d6542991f629bc64caf31
---

# Design Decisions: Sharpen Workaround Guidance

## Summary
Fixed a real failure mode reported via field feedback: an agent treated askfirst's "ask before workaround" rule as soft because the task didn't literally match one of the registered example scenarios, and offered the workaround as a co-equal menu option. Resolved by strengthening agent-hooks context and message text on two separate trust layers, without collapsing the split stage 007 established between them.

## New Design Decisions

### Decision 1: Preserve the stage-007 trust-boundary split; strengthen both sides instead of reversing it
**Chosen:** Message text signalled by an adopting package (`askfirst_signal()` output) stays non-imperative and non-second-person. Directive-strength behavioral instruction — explicit non-exhaustive framing and a "mark the ask-first option as recommended" rule — is added to the pre-loaded `agent-hooks/*/session_start.sh` context instead.
**Rationale:** Stage 007 introduced both the `agent-hooks/` infrastructure and the neutral-message-framing decision in the same commit; the softened message text was a deliberate response to message text being potentially untrusted (spoofable by arbitrary package code), not a stopgap awaiting hooks. Hook context is pre-loaded and trusted, so it can carry stronger instruction without prompt-injection guardrail risk.
**Tradeoffs:** An agent without the hooks installed still only sees the structurally-marked-but-non-imperative message text.
**Proposed by:** joint
**Relates to:** Stage 007, Decision 4 (neutral, non-instructive message framing)

### Decision 2: Consolidate duplicated scenario bullets to a single location
**Chosen:** `askfirst_build_notice()` (load-time) no longer includes scenario bullets at all — only the generic reminder to call `askfirst_check_scenarios()`. The bullet list appears exactly once, in `askfirst_build_scenario_check_message()` (on-demand), with wording made explicitly non-exhaustive ("including but not limited to").
**Rationale:** The two messages previously repeated the same scenarios under different headers ("Situations to watch for" vs. "Known situations where this applies"), inviting an agent to reconcile/average the two into a softer combined reading. A single, non-exhaustive location removes the ambiguity.
**Proposed by:** mpadge

### Decision 3: Uniform structural directive field across all signal types
**Chosen:** `askfirst_signal()` now inserts a `directive: ask-before-proceeding` line into its structured prefix block (between the `askfirst::<language>::<pkg>::<type>` line and the message body), applied to all four signal classes — `notice`, `error_redirect`, `scenario_check`, and `capability_gap` — uniformly.
**Rationale:** Gives message text a machine-parseable, non-tonal marker of actionability, independent of whether hooks are installed. Applying it uniformly (rather than only to the "ask" types) keeps the prefix-block format consistent across all signal classes.
**Proposed by:** mpadge

## Integration with Prior Work
Builds directly on stage 007's structured-prefix mechanism (`askfirst_signal()`) and agent-hooks infrastructure, and stage 010's high-confidence-only gating (these changes only ever reach sessions already identified as an AI agent). Does not revisit stage 007 Decision 4 -- extends it by giving the trusted (hooks) and untrusted (message text) layers each a more effective form of the same guidance.

## Issues Resolved
- Agent treating "ask before workaround" as conditional on literal scenario match: resolved via explicit non-exhaustive framing in both hook context and scenario_check message text.
- Workaround presented as a co-equal neutral-menu option: resolved via hook-context instruction to use the calling tool's recommended-option convention.
- Redundant, inconsistently-worded scenario bullets across two signal points: resolved by consolidating to one location.

## Deferred Items
- Whether `askfirst_build_notice()`'s remaining generic-reminder wording needs further adjustment now that it no longer carries scenario bullets -- left as-is; no issue surfaced during implementation.
- Whether `post_tool_use.sh` needs changes -- left unchanged; all behavioral strengthening landed in `session_start.sh` and the R message-building functions.

## Process Notes
- The plan initially proposed reintroducing imperative message-text phrasing directly; checking git history showed this would have reversed a deliberate stage-007 trust-boundary decision rather than extended it, which redirected the approach to the two-layer split ultimately adopted.
