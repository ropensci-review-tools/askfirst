---
created: 2026-07-29T13:33:56Z
agent: claude-sonnet-5
git_hash: 9a84f92a25af9435f8f22c2a1b82129a98791244
---

# Plan: harden-hooks-nudge-relay

## Overview
Give the agent-directed `askfirst_hooks_nudge` notice its own always-relay
delimiter (distinct from the `<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>`
hard-stop markers), and merge a `hooks_nudge` with a same-session
`stop-and-ask` halt into one emitted block, so a human-directed relay
instruction isn't dropped when an agent's summary collapses toward the
single most consequential signal. This closes a field-observed gap
(`askfirst-advice.md`, `ropensci-review-tools/askfirst-tests`) that doesn't
match any of the six failure modes already catalogued in that sibling
repo's `failure-examples.md`.

## Context

**Stage 014** (`specs/014-self-sufficient-stop-signal`) gave every
`stop-and-ask` condition class a self-sufficient hard-stop message shape:
a fixed `<<<ASKFIRST:HALT>>>` / `<<<ASKFIRST:RESUME>>>` delimiter pair
(read from `agent-content/askfirst-markers.txt`, stage 019) bounding a
first-person-to-agent consequence statement, so the instruction doesn't
depend on hook-taught interpretation to be read as binding rather than as
ordinary output that can be reasoned past (`failure-examples.md` mode #5).
That same stage added `askfirst_hooks_status()` and a human-directed,
confidence-independent console nudge toward
`agent-hooks/install-agent-hooks.sh` when hooks are missing/stale
(`failure-examples.md` mode #6).

**Stage 019** (`specs/019-nudge-agent-hooks-install`) added a second,
agent-directed channel for that same hooks-missing/stale event: a new
`askfirst_hooks_nudge` condition class, signalled via the existing
`askfirst_signal()` machinery but using the plain **notice shape** (header
+ body + `askfirst_notice_prime()`'s forward-reference sentence + URL —
see `bindings/r/R/conditions.R`), gated on `confidence == "high"`, additive
to the unchanged human-directed nudge. That stage also extracted all fixed
condition/notice text out of R string literals into a new binding-agnostic
`agent-content/` directory, synced into `bindings/r/inst/agent-content/`
and read at runtime via `system.file()` — the mechanism this stage reuses
for its own new marker/text file.

**The field report** (`askfirst-advice.md`, single-session note, not yet
confirmed via `askfirst-tests`' multi-trial harness): in one investigation,
a `hooks_nudge` notice and a later `askfirst_scenario_check` halt appeared
in the same combined stderr stream from one R invocation. The agent read
both correctly and obeyed the halt, but its summary to the human dropped
the `hooks_nudge`'s "tell your human user to run
`agent-hooks/install-agent-hooks.sh`" instruction entirely, surfacing only
the halt/scenario-check result. The diagnosed mechanism: only the halt is
wrapped in a hard, always-relay delimiter (`<<<ASKFIRST:HALT>>>`); the
notice shape has no equivalent, so it reads exactly like the kind of
ordinary, weighable output stage 014 fixed for halts — but for a *relay*
directive ("tell the human") rather than an *execution* directive ("don't
implement a workaround"). This doesn't fit any of `failure-examples.md`'s
six modes, which are all about a single signal being misread or diluted;
this is selective relay under multi-signal triage, where two must-relay
signals of different severity co-occur and only the more severe one
survives summarization.

**Decisions made when scoping this stage** (see also Design Goals and
Deferred candidates below): implement now rather than waiting for
multi-trial harness confirmation in `askfirst-tests`, since the fix is
low-risk and directly analogous to stage 014's own precedent; scope the
new delimiter to `askfirst_hooks_nudge` only (the one condition class that
is today both non-halting and must-relay-to-a-human, as opposed to
must-act-on-by-the-agent — `askfirst_notice`'s existing forward-reference
priming sentence is agent-directed, not a "tell the human" instruction, so
it is out of scope); and also attempt the advice note's second
recommendation, merging a `hooks_nudge` with a same-session halt into one
emitted block.

## Design Goals
- Give `askfirst_hooks_nudge` a fixed, always-relay delimiter pair —
  distinct from `<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>`, e.g.
  `<<<ASKFIRST:TELL-USER>>>` / `<<<ASKFIRST:END-TELL-USER>>>` — so the
  "tell your human user..." instruction is bounded the same
  non-optional way stage 014 bounded `stop-and-ask` signals, rather than
  sitting as free-form notice text.
- Keep this additive and scoped: only `askfirst_hooks_nudge`'s shape
  changes. `askfirst_notice`'s existing notice shape (used for the
  forward-reference priming sentence) is untouched, since it isn't a
  must-relay-to-human directive.
- When a `askfirst_hooks_nudge` has already fired earlier in the current
  session and a `stop-and-ask` signal fires later in that same session,
  emit the nudge's `TELL-USER` block folded into the halt's own message
  (nudge content first, then the existing `HALT`/`RESUME` block) as a
  single `rlang::inform()`/`rlang::abort()` call's message text, instead
  of relying on two separately-styled prior/later messages that
  summarization can independently keep or drop.
- Preserve stage 019's existing gating exactly: `askfirst_hooks_nudge`
  still only fires at `confidence == "high"`, still shares the
  once-per-session `hooks_nudge_shown` flag with the unchanged
  human-directed console nudge, still fires alongside (not instead of)
  that console nudge.
- Fixed marker/text additions go through the existing `agent-content/` →
  `bindings/r/inst/agent-content/` sync-and-check pipeline (stage 019),
  not as new hardcoded R string literals.

## Proposed Approach

**New markers.** Add a `TELL-USER` / `END-TELL-USER` section pair to
`agent-content/askfirst-markers.txt`, alongside the existing `HALT` /
`RESUME` pair, e.g.:
```
--- TELL-USER ---
<<<ASKFIRST:TELL-USER>>>
--- END-TELL-USER ---
<<<ASKFIRST:END-TELL-USER>>>
```
Read via the existing `askfirst_load_marker()` helper
(`bindings/r/R/conditions.R`) — no new file-reading mechanism needed.

**Revised hooks-nudge wording.** `agent-content/askfirst-hooks-nudge.txt`'s
body text also changes, at mpadge's direction: the
"Tell your human user to run `agent-hooks/install-agent-hooks.sh` (from
the askfirst repository) to install or update hooks that help you and
other..." phrasing is replaced with "Tell your human user to install
'askfirst' agent hooks from
`https://github.com/ropensci-review-tools/askfirst` to help you and
other...", with the remainder of the sentence unchanged. This only
touches the agent-directed condition text (`askfirst_hooks_nudge`'s own
body); the separate, unchanged human-directed console nudge from stage
014 (`askfirst_maybe_nudge_hooks_install()`'s own `cli::cli_inform()`
call, still referencing `agent-hooks/install-agent-hooks.sh` directly) is
out of scope for this revision.

**`askfirst_hooks_nudge`'s shape.** In `askfirst_signal()`
(`bindings/r/R/conditions.R`), `askfirst_hooks_nudge` currently falls into
the generic "notice shape" branch (`directive_map[["askfirst_hooks_nudge"]]
== "notice"`), identical in structure to `askfirst_notice`. Give it a
**third** message shape, distinct from both the hard-stop and plain-notice
shapes: header + body bounded by the new `TELL-USER`/`END-TELL-USER`
delimiters + URL line — no `askfirst_notice_prime()` forward-reference
sentence (that sentence exists to prime for a *later hard stop*, which
doesn't apply here). This is a targeted third branch keyed on
`class == "askfirst_hooks_nudge"` specifically, not a new general-purpose
directive tier in `directive_map` — the tier stays `"notice"` (non-halting
delivery via `rlang::inform()` is unchanged), only the message-assembly
shape gains a case.

**Session-state for the merge.** Add two new fields to `.askfirst_state`
(`bindings/r/R/state.R`): `hooks_nudge_pending_relay` (logical, default
`FALSE`) and `hooks_nudge_relay_text` (character, default `NULL`). The
`askfirst_hooks_nudge` shape in `askfirst_signal()` assembles its
`TELL-USER`/`END-TELL-USER`-bounded block (start delimiter, header, body,
end delimiter — no `See:` line) as its own value first, then appends the
`See:` line only for the *standalone* message actually signalled; the
undecorated block (sans `See:` line) is what gets stashed into
`.askfirst_state$hooks_nudge_relay_text`, with `pending_relay <- TRUE`, at
the same point `askfirst_maybe_nudge_hooks_install()`
(`bindings/r/R/hooks_status.R`) currently sets `hooks_nudge_shown <- TRUE`
— immediately after signalling `askfirst_hooks_nudge` (only reached at
`confidence == "high"`, so the merge only ever applies when the nudge
itself was agent-directed in the first place).

**The merge itself.** In `askfirst_signal()`'s hard-stop-shape branch: if
`.askfirst_state$hooks_nudge_pending_relay` is `TRUE`, prepend
`.askfirst_state$hooks_nudge_relay_text` (the bare `TELL-USER` block, no
`See:` line of its own) before the existing `askfirst_stop_start_delimiter()`
block (nudge content first, then the halt block, per the advice note) —
so the halt's own trailing `url_line` is the only `See:` line in the
merged message — and clear `hooks_nudge_pending_relay <- FALSE` so only
the *next* halt after a fresh nudge absorbs it, not every subsequent halt
for the rest of the session. The nudge block's own `askfirst::r::pkg::notice`
/ `type: hooks_nudge` header line is kept in the merged form (not
suppressed), so the nudge content stays machine-identifiable even folded
into a halt. The standalone `askfirst_hooks_nudge` condition already fired
earlier (unchanged, still carries its own `See:` line) — the merge affects
only what additionally gets folded into a later halt's own message text,
not whether the standalone notice itself still fires.

**Confirmed merged-message shape** (drafted and reviewed with mpadge
before implementation, per the blocking Open Question below):
```
<<<ASKFIRST:TELL-USER>>>

askfirst::r::{pkg}::notice
type: hooks_nudge

This project has no current askfirst-aware agent hooks installed (or they
are stale) -- detected while loading {pkg}. Tell your human user to
install 'askfirst' agent hooks from
https://github.com/ropensci-review-tools/askfirst to help you and other
AI coding assistants recognise askfirst's structured signals directly,
rather than relying solely on this per-call condition text.

<<<ASKFIRST:END-TELL-USER>>>

<<<ASKFIRST:HALT>>>

YOU ARE BEING INSTRUCTED TO STOP HERE. ...(askfirst_stop_consequence())...

askfirst::r::{pkg}::stop-and-ask
type: {halt type, e.g. scenario_check}

...(package-authored halt body)...

<<<ASKFIRST:RESUME>>>

See: {askfirst_url()}
```
Confirmed decisions: the nudge's own `See:` line is dropped when merged
(only the halt's trailing `See:` line survives); the nudge's own
`askfirst::.../type:` header line is kept (not suppressed) so the merged
nudge content remains independently identifiable.

**Test coverage.** New/updated tests in `bindings/r/tests/testthat/`:
marker file has the new `TELL-USER`/`END-TELL-USER` section pair and
round-trips through `askfirst_load_marker()`; `askfirst_hooks_nudge`'s
assembled message is bounded by the new delimiters and does *not* contain
`askfirst_notice_prime()`'s forward-reference text; a `stop-and-ask` signal
fired after a `hooks_nudge` in the same (simulated) session contains both
the `TELL-USER` block and the `HALT`/`RESUME` block in one message, in
that order; a `stop-and-ask` signal fired with no prior `hooks_nudge` this
session is unchanged (no `TELL-USER` block at all); a *second*
`stop-and-ask` signal after the first already consumed the pending relay
does not repeat the `TELL-USER` block.

## Open Questions
None outstanding — all questions raised during planning were resolved
before implementation (see Resolved During Review).

## Resolved During Review
- Wording of `agent-content/askfirst-hooks-nudge.txt`'s body text: revised
  from "Tell your human user to run `agent-hooks/install-agent-hooks.sh`
  (from the askfirst repository) to install or update hooks that help you
  and other..." to "Tell your human user to install 'askfirst' agent
  hooks from `https://github.com/ropensci-review-tools/askfirst` to help
  you and other...", remainder of the sentence unchanged. Scoped to the
  agent-directed condition text only — stage 014's separate human-directed
  console nudge is untouched. (mpadge)
- Exact wording/placement of the `TELL-USER` block relative to
  `askfirst_stop_consequence()`'s own first-person text when merged into a
  halt: drafted concretely (see "Confirmed merged-message shape" above)
  and reviewed with mpadge before any implementation — placed as two
  back-to-back delimited blocks (nudge block, then halt block), nudge's
  own `See:` line dropped, nudge's own header line kept. (mpadge)
- Whether `askfirst_error_redirect` also needs special-case handling for
  the merge: no — `askfirst_hooks_nudge` only ever fires once, at session
  outset (library-load time via `askfirst_init()`), while
  `askfirst_error_redirect` fires later, once execution is already
  underway. By the time any error-time `stop-and-ask` signal could fire,
  either an earlier `stop-and-ask` signal already consumed the pending
  relay (in which case there's nothing left to merge) or none has fired
  yet (in which case the pending relay is still available and the shared
  hard-stop-shape branch picks it up automatically, exactly as for any
  other `stop-and-ask` class). No separate decision or code path needed.
  (mpadge)
- Whether to track re-running the `askfirst-tests` harness as part of
  this stage: no — `askfirst-tests` is a separate repo under mpadge's own
  manual control, not something this stage's process should track or
  reference as a dependency. (mpadge)
