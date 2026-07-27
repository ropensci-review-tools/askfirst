---
created: 2026-07-27T18:00:00Z
agent: claude-sonnet-5
git_hash: b652c8ee47a05301f71cadd1369d50a92d6fbc78
---

# Plan: sharpen-workaround-guidance

## Overview
Sharpen askfirst's workaround-vs-ask guidance: split directive strength between trusted agent-hooks context and untrusted-but-always-present message text, remove redundant/inconsistent scenario-bullet duplication between load-time notice and on-demand scenario_check, and make scenario examples explicitly non-exhaustive.

## Context
Triggered by field feedback (`askfirst-advice.md`, dodgr path-uncontraction case): an agent hit both the load-time notice and an explicit `askfirst_check_scenarios("dodgr")` call, but because the task didn't literally match any of the three registered example scenarios, the agent treated the general "ask before implementing a workaround" rule as softly applicable rather than binding, and presented the workaround as a co-equal option in a neutral menu -- the exact action the notice said not to take unilaterally.

Two prior stages are directly load-bearing here:
- **Stage 007 (revise-messaging)** introduced the structured `askfirst::<language>::<pkg>::<type>` prefix, the `agent-hooks/` SessionStart/PostToolUse hooks, *and* Decision 4: stripped all second-person/imperative phrasing from message text project-wide. Decision 4's rationale was that message text originates from an adopting package's own (potentially untrusted/spoofable) signal call, so directive-sounding prose there risks tripping an agent's prompt-injection guardrails -- whereas hook context is pre-loaded by the user/system before any session starts and is inherently trusted, so it can be as directive as needed. Hooks and Decision 4 shipped in the same commit (`4537317`); the softened message text was not a stopgap "we didn't have hooks yet" measure, it was a deliberate trust-boundary split that this stage continues rather than reverses.
- **Stage 010 (restrict-to-high-confidence)** narrowed all four signal points (notice, error_redirect, scenario_check, capability_gap) to fire only at high-confidence (known-agent) detection, so this stage's changes only ever reach sessions already identified as an AI agent.

This stage keeps stage 007's trust-boundary split intact and resolves the feedback by strengthening each side of it rather than collapsing it: hook context gets more explicit behavioral instruction, message text gets a structural (not tonal) fix.

## Design Goals
- Goal 1: Hook context (`agent-hooks/claude/session_start.sh`, `agent-hooks/opencode/session_start.sh`) explicitly instructs agents to: (a) treat any registered scenario/example list as non-exhaustive illustrations, never a literal-match gate -- the general rule in the notice always applies to any missing/buggy capability; (b) when presenting an ask-the-user-vs-implement-workaround choice, use the calling tool's own asymmetric/recommended-option convention (e.g. Claude Code's "(Recommended)" option labelling) with "ask the user" as the recommended default, never a neutral coin-flip menu that includes the workaround as a co-equal option.
- Goal 2: Eliminate the redundant, inconsistently-worded scenario-bullet duplication between `askfirst_build_notice()` (load-time) and `askfirst_build_scenario_check_message()` (on-demand) so there is nothing left for an agent to reconcile/average across the two.
- Goal 3: Make the on-demand scenario_check message's bullet list explicitly non-exhaustive in its own wording, independent of whether hooks are installed, since hooks are opt-in infrastructure and the message text is the only thing guaranteed to reach every agent.
- Goal 4: Give message text (not just hook context) a structural signal that it is actionable rather than descriptive filler, without reintroducing second-person/imperative prose -- since a user of some askfirst-adopting package may never have installed the hooks, and the message text can't rely entirely on hook context to carry the directive.

## Proposed Approach
Two-layer split, matching stage 007's existing trust boundary:

- **Trusted layer -- agent-hooks context (`session_start.sh`, both `claude/` and `opencode/` variants, kept identical per the existing pattern):** Add explicit points to the `<askfirst-context>` block: scenario/example lists are illustrative, not exhaustive gates; the general "ask before workaround" rule in a notice always applies regardless of literal scenario match; when presenting the choice to the user, mark "ask the user" as the recommended option using the agent's own tool conventions rather than a neutral multiple-choice menu.
- **Untrusted-but-always-present layer -- message text (`conditions.R`):**
  - `askfirst_build_notice()`: drop the scenario bullet list entirely from the load-time notice; keep only the short generic reminder to call `askfirst_check_scenarios()`. Scenario details live in exactly one place now.
  - `askfirst_build_scenario_check_message()`: reword the bullet-list header to state explicitly that the list is illustrative/non-exhaustive (e.g. "...for {pkg}, including but not limited to:").
  - `askfirst_signal()`: add a lightweight structural field to the existing prefix block (alongside `askfirst::<language>::<pkg>::<type>` and `See: <url>`) that marks the message as carrying an actionable directive, without using second-person or imperative sentence-level phrasing -- a labelled field, not a tone change. Applied uniformly to all four signal types (`notice`, `error_redirect`, `scenario_check`, `capability_gap`), not just the ones that recommend asking rather than halting -- resolved below.

## Open Questions
- **Resolved:** the structural directive field in `askfirst_signal()` applies evenly across all four signal types, including `capability_gap` (even though it already halts via `rlang::abort()`), for consistency of the prefix-block format. Exact field name/format (e.g. `directive: ask-before-workaround`) is left to implementation judgment.
- Still open: whether `askfirst_build_notice()`'s remaining generic-reminder-only text needs any wording adjustment now that it no longer carries scenario bullets, or is left as-is from stage 007. Deferred -- decide during implementation.
- Still open: whether the PostToolUse hooks (`post_tool_use.sh`) need any change, or whether all of this stage's changes belong solely in `session_start.sh` and `conditions.R`. Deferred -- decide during implementation.
