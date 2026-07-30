---
created: 2026-07-30T11:10:41Z
agent: claude-sonnet-5
git_hash: a1fe97bb09285f479237750ec46180034244e42d
---

# Design Decisions: fix-installer-and-halt-clause

## Summary
Closed a field-reported installer bug that left agent hooks silently
unregistered, and revised the HALT directive's workaround-mention clause
— duplicated across two independent canonical text sources — to permit a
subordinate, labeled mention while preserving the anti-menu-option rule
three prior stages established.

## New Design Decisions

### Decision 1: Installer creates `.claude/settings.json` unconditionally when absent
**Chosen:** `agent-hooks/install-agent-hooks.sh`'s Claude Code branch now
runs `[[ -f "$TARGET_CONFIG" ]] || echo '{}' > "$TARGET_CONFIG"` followed
by an unconditional `register_hooks_claude` call, removing the prior
silent-skip branch that logged one stderr line and still exited 0 as a
reported success.
**Rationale:** A field trial (`askfirst-advice.md`) found fully-installed,
version-tagged, completely inert hooks with no observable failure signal,
traced to this exact silent-skip branch.
**Tradeoffs:** None — the only remaining early-exit path (`jq` missing)
already warns loudly.
**Proposed by:** agent

### Decision 2: Loosen the "no workaround as an option" clause without reopening the menu-option gap
**Chosen:** Revised wording (in both
`agent-hooks/askfirst-context.txt` and
`agent-content/askfirst-stop-consequence.txt` /
`askfirst-notice-prime.txt`) requires surfacing the upstream question
first, and permits mentioning an unvetted workaround only as a clearly
subordinate, explicitly-labeled aside — never as a selectable,
co-equal, or "recommended" menu option.
**Rationale:** Stages 011, 012, and 014 each hardened this clause after
field reports of agents offering workarounds as menu options. This
stage's own reconciliation trial showed hook reinforcement fixes
injection-distrust behavior but not the mention prohibition, because
withholding a known option from a principal conflicts with a stronger
transparency norm than reinforcement addresses. Loosening only the
mention ban, while keeping the menu-option prohibition intact, targets
the part of the rule agents actually override without reopening the
specific gap those three stages closed.
**Tradeoffs:** First stage to walk back a repeatedly-hardened directive
rather than tighten it; carries some reversal risk if future field
reports show agents drifting back toward menu-style framing under the
loosened wording.
**Proposed by:** joint
**Relates to:** Stages 011 (`sharpen-workaround-guidance`), 012
(`harden-ask-first-gate`), and 014 (`self-sufficient-stop-signal`), all of
which progressively hardened the same clause in the opposite direction.

### Decision 3: Fix wording in both canonical copies of the clause, not just one
**Chosen:** Applied equivalent revised wording to both the hook-context
copy (`agent-hooks/askfirst-context.txt`, reinforcement read by a coding
agent tool with hooks installed) and the hook-independent copy
(`agent-content/askfirst-stop-consequence.txt` /
`askfirst-notice-prime.txt`, embedded directly in `askfirst_signal()`'s
own message text per stage 014, synced into
`bindings/r/inst/agent-content/`).
**Rationale:** These are two separately-maintained mechanisms; fixing
only the hook-context copy would leave the self-sufficient stop signal —
the one designed specifically not to depend on hooks — carrying the old,
unrevised wording.
**Proposed by:** agent
**Relates to:** Stage 019 (established `agent-content/` as the
binding-runtime-facing canonical text home), stage 018 (established
`askfirst-context.txt` as the coding-agent-tool hook-context source).

## Integration with Prior Work
This stage is the first since 011/012/014 to loosen rather than tighten
the workaround-mention clause, doing so deliberately based on new
reconciliation-trial evidence rather than as an unexamined reversal. It
reuses stage 018/019's split between hook-context and binding-runtime
canonical text sources, updating both in step.

## Issues Resolved
- Installer silent-skip bug from `askfirst-advice.md`: fixed and covered
  by new runtime tests exercising both the absent- and
  present-`settings.json` cases.
- Workaround-mention clause overridden regardless of hook reinforcement:
  addressed by narrowing what the clause actually prohibits.

## Deferred Items
- Whether other coding-agent-tool integrations besides Claude Code and
  opencode will need an equivalent settings-file-creation fix if they
  gain a fixed, predictable config path in the future.

## Process Notes
- Verified the installer bug was still live (not already fixed by stage
  021) before scoping this stage.
- Verified via `grep` that no existing test asserted on the literal
  pre-change prose, so the wording change carried no expected test
  breakage beyond the new assertions added in this stage.
