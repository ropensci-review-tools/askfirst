---
created: 2026-07-29T14:29:38Z
agent: claude-sonnet-5
git_hash: e87e2de04bde998dea889cbf8cfdb729ba9970d3
---

# Design Decisions: Harden Hooks-Nudge Relay

## Summary
Closed a field-reported gap where an agent-directed `askfirst_hooks_nudge`
notice was silently dropped from an agent's summary when it co-occurred
with a `stop-and-ask` halt in the same session, by giving the nudge its
own always-relay delimiter and folding it into a following halt as one
message rather than two independently-summarizable ones.

## New Design Decisions

### Decision 1: A third, `TELL-USER`-bounded message shape for `askfirst_hooks_nudge`
**Chosen:** `agent-content/askfirst-markers.txt` gained a `TELL-USER` /
`END-TELL-USER` marker pair, distinct from `HALT`/`RESUME`.
`askfirst_signal()` now assembles `askfirst_hooks_nudge`'s message as
header + body bounded by these markers + a `See:` line — a shape of its
own, not the plain notice shape it previously shared with
`askfirst_notice`.
**Rationale:** The field report's diagnosed mechanism: only `stop-and-ask`
signals carried a hard, always-relay delimiter (stage 014); the
plain-notice shape has none, so a must-relay-to-human directive
("tell your human user...") read exactly like ordinary, weighable output
once it co-occurred with a higher-severity halt.
**Tradeoffs:** Scoped to `askfirst_hooks_nudge` only, not a new
general-purpose "must-relay" directive tier in `directive_map` — the only
condition class today that is both non-halting and must-relay-to-a-human
rather than must-act-on-by-the-agent.
**Proposed by:** joint
**Relates to:** Stage 014 (the hard-stop delimiter precedent this
extends to a second, non-halting case); Stage 019 (introduced
`askfirst_hooks_nudge` and the `agent-content/` canonical-text mechanism
this stage's new marker file and wording revision both use)

### Decision 2: Merge a pending nudge into the next same-session halt
**Chosen:** New `.askfirst_state` fields (`hooks_nudge_pending_relay`,
`hooks_nudge_relay_text`) let `askfirst_signal()`'s hard-stop-shape branch
prepend an earlier-fired nudge's bare `TELL-USER` block (no `See:` line of
its own) before the halt's own `HALT`/`RESUME` block, clearing the flag so
only the first halt after a fresh nudge absorbs it.
**Rationale:** Reduces the chance that summarization independently keeps
or drops two separately-styled messages; the merge applies uniformly via
the shared hard-stop-shape branch to every `stop-and-ask` class, including
`askfirst_error_redirect`, with no special-casing needed — the nudge fires
once, at session outset, so by the time any later halt fires the pending
relay is either already consumed or still available by construction.
**Tradeoffs:** The merged nudge block keeps its own
`askfirst::.../type:` header line (kept machine-identifiable even folded
in) but drops its own trailing `See:` line (the halt's own `See:` line is
the only one in the merged message).
**Proposed by:** joint

### Decision 3: Revised hooks-nudge body wording
**Chosen:** `agent-content/askfirst-hooks-nudge.txt`'s "Tell your human
user to run `agent-hooks/install-agent-hooks.sh` (from the askfirst
repository)..." phrasing was replaced with "Tell your human user to
install 'askfirst' agent hooks from
`https://github.com/ropensci-review-tools/askfirst`...".
**Rationale:** A direct repository URL rather than a script-relative path
assumes less about the human's local environment.
**Tradeoffs:** Scoped to the agent-directed condition text only; the
separate, unchanged human-directed console nudge from stage 014
(`askfirst_maybe_nudge_hooks_install()`'s own `cli::cli_inform()` call)
still references `agent-hooks/install-agent-hooks.sh` directly.
**Proposed by:** git-user

## Integration with Prior Work
Extends stage 014's self-sufficient hard-stop delimiter precedent to a
second, non-halting case, and stage 019's `askfirst_hooks_nudge` condition
and `agent-content/` canonical-text mechanism, without altering either's
existing confidence-gating or once-per-session semantics.

## Issues Resolved
- A `hooks_nudge` notice sharing a session with a later `stop-and-ask`
  halt could be selectively dropped from an agent's relay to the human,
  since only the halt carried a hard, always-relay delimiter — resolved
  via the new `TELL-USER` shape and the merge into the following halt.

## Deferred Items
- Re-running the `askfirst-tests` harness's relevant trial cell to move
  this from a single-session hypothesis to a confirmed failure mode —
  left entirely to that separate repo's own process, not tracked here.

## Process Notes
- Three open questions raised while drafting the plan (whether
  `askfirst_error_redirect` needs special-casing, the exact merged-message
  wording/placement, and whether to track the `askfirst-tests` re-run as a
  task) were all resolved before implementation began: the first two with
  concrete reasoning recorded directly in `plan.md`, the third by removing
  it as out of scope.
- The exact merged-message text was drafted and shown for review before
  any code was written, per an explicit request to see it concretely
  rather than only as a structural description.
