---
created: 2026-07-27T10:05:00Z
agent: claude-sonnet-5
git_hash: 5a37264df26b0fa98265a841fc89c187940cb74b
---

# Design Decisions: scenario-check

## Summary
This stage added `pkghooks_check_scenarios()`, a new, fully independent
mechanism for LLM/AI-agent callers who might be extending or duplicating a
package's functionality externally, complementing (not replacing) the
existing author-driven `flag_capability_gap()`. Unlike every other
intervention point in `pkghooks`, this one is *agent-invoked*: it fires
only because the calling LLM chooses to call it, since no reliable
execution-time trigger exists for the case it targets.

## New Design Decisions

### Decision 1: Reject mechanical workaround-detection entirely
**Chosen:** No detection of monkey-patching or namespace-manipulation
calls (`assignInNamespace()`, `trace()`, etc.) targeting an adopting
package was built.
**Rationale:** Such calls are rare in practice, and more fundamentally,
code an LLM writes to extend a package's functionality typically lives
entirely in the calling project — it never touches the package's
namespace or triggers any event `pkghooks` could observe. There is no
reliable execution-time trigger for this case, mechanical or otherwise.
**Tradeoffs:** None — this was a genuine dead end, not a deprioritized
option.
**Proposed by:** mpadge

### Decision 2: An agent-invoked intervention point
**Chosen:** `pkghooks_check_scenarios(pkg)`, a new exported function the
LLM calls on its own initiative at any point in a session, combined with a
strengthened load-time notice that always includes a generic instruction
to call it, plus (if supplied) the author's own "plausible extension
scenario" descriptions.
**Rationale:** With no mechanical trigger available, the only viable
delivery path is priming the LLM early (load-time notice) and giving it a
callable tool to consult later, once the initial notice may have scrolled
out of context in a long session.
**Tradeoffs:** Entirely dependent on the LLM's own cooperation — nothing
forces the check, unlike `flag_capability_gap()`'s halting behavior for
author-known gaps. Accepted as inherent to the problem, not a shortcut.
**Relates to:** Extends stage 002's three *system-triggered* intervention
points (`load_time`/`error_time`/`capability_gap_time`,
`specs/002-design-agnostic-spec/design.md` T002-5) with a conceptually
different, fourth kind — agent-invoked, not system-invoked. Not
back-ported into stage 002's own documents in this stage (see Deferred
Items).

### Decision 3: Fully additive, non-fatal, confidence-gated
**Chosen:** `flag_capability_gap()`, `on_error` wrapping, and all existing
condition classes are unchanged. `pkghooks_scenario_check` is signalled
non-fatally (never halting). At `"low"` confidence,
`pkghooks_check_scenarios()` returns the scenario list as a plain
invisible vector with no condition signalled and no "ask the human"
framing.
**Rationale:** Heuristic/self-assessed triggers carry more false-positive
risk than an author-confirmed gap, so halting was rejected. A human
calling this deliberately doesn't need to be told to ask themselves.
**Tradeoffs:** None significant.

### Decision 4: Scenario shape and generic instruction always included
**Chosen:** `scenarios` is a flat `character` vector (not a structured/named
list). The generic "call `pkghooks_check_scenarios()` first" instruction
is unconditionally folded into the load-time notice, regardless of whether
`scenarios` is empty, and is not author-configurable in v1.
**Rationale:** A flat vector is simplest for authors to write, matching
`notice`'s own plain-string shape. Centralizing the generic wording (not
letting each author reword it) matches `pkghooks`'s existing rationale for
owning *how* messages are delivered, not just *whether*.
**Tradeoffs:** Authors can't customize the generic instruction's wording
in v1; revisit if that proves limiting.

## Integration with Prior Work
Builds directly on stage 003's registry (`.pkghooks_state$packages`),
signaling helper (`pkghooks_signal()`), and condition-class hierarchy
(new `pkghooks_scenario_check` rooted at the existing `pkghooks_condition`
base) — no new infrastructure was needed. Extends `pkghooks_init()`'s
existing signature rather than introducing a parallel registration
function.

## Issues Resolved
- Whether mechanical detection of in-progress workarounds is feasible:
  resolved no.
- Low-confidence return behavior for the new function: resolved as a
  plain, invisible vector with no signalled condition.
- Shape of author-supplied scenario data: resolved as a flat character
  vector.

## Deferred Items
- Whether to formalize "agent-invoked" as a fourth, language-neutral
  intervention point in stage 002's abstract model
  (`specs/002-design-agnostic-spec/design.md`) — left undecided; this
  stage's own scope is R-only regardless of how it resolves.
- Author configurability of the generic instruction wording.
- A more structured `scenarios` shape (e.g. named list) if a flat vector
  proves insufficient in practice.

## Process Notes
- The initial two candidate mechanisms proposed for this stage (mechanical
  monkey-patch detection; a strengthened error-time message only) were
  both rejected by mpadge in favor of a mechanism that works in general,
  error-free contexts — reshaping the stage's design before `plan.md` was
  written, not after.
