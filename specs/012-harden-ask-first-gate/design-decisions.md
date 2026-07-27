---
created: 2026-07-27T18:25:00Z
agent: claude-sonnet-5
git_hash: beafb6fe16abee766676cb2455d6154b2fed530e
---

# Design Decisions: Harden the Ask-First Gate

## Summary
Resolved a field-reported failure where an agent read `askfirst_check_scenarios()`'s advisory message and then offered a workaround as a menu option anyway. Closed the gap by making the self-check actually halt, making the `directive:` field reflect real severity, removing the last vestige of workaround-as-menu-option framing from hook guidance, and fixing a previously silent drift bug in the shipped installer.

## New Design Decisions

### Decision 1: `askfirst_check_scenarios()` halts at high confidence
**Chosen:** The high-confidence branch now signals via `askfirst_signal(..., call_stop = TRUE)`, the same mechanism `askfirst_capability_gap()` already used, instead of `rlang::inform()`. The scenario vector is attached as a condition field so it remains inspectable via `tryCatch()` even though the call no longer returns normally on that path.
**Rationale:** A self-check the calling agent can read and continue past in the same turn does not function as a gate; the field report's core failure was exactly this — the message printed, and the agent proceeded anyway.
**Tradeoffs:** At high confidence the function no longer returns a usable scenario vector to R code; only the medium/low-confidence paths still do.
**Proposed by:** joint
**Relates to:** Stage 004 (introduced the function as non-fatal by design), stage 010 (scoped it to high confidence only)

### Decision 2: `directive:` field differentiated by actual severity
**Chosen:** `askfirst_signal()` now emits `directive: stop-and-ask` for `capability_gap`, `scenario_check`, and `error_redirect`, and `directive: notice` only for the load-time notice — replacing the single uniform `ask-before-proceeding` value stage 011 introduced for all four signal types.
**Rationale:** `error_redirect` always accompanies a real error already propagating from the adopting package's own code, so by the time the agent sees it the call has already halted, even though `askfirst_signal()`'s own delivery for that class stays non-fatal (`rlang::inform()`). The directive value now describes the situation the agent is in, not the internal delivery mechanism of that particular call.
**Proposed by:** joint, with the `error_redirect` inclusion added by explicit correction during plan review
**Relates to:** Stage 011, Decision 3 (introduced the uniform directive line this stage differentiates)

### Decision 3: Hook guidance drops the workaround-as-menu-option framing entirely
**Chosen:** `agent-hooks/{claude,opencode}/session_start.sh` rule 6 no longer instructs marking "ask the user" as a recommended option within a two-option choice. It now states that on a `stop-and-ask` signal, the only immediate next step is to surface the upstream question and wait for an answer — no workaround may be presented as an option, marked or otherwise, in the same turn.
**Rationale:** Reviewing the field report against stage 011's fix showed the "mark as recommended" mitigation still offered the workaround as a selectable choice — precisely the pattern the report identified as defeating the rule's intent, regardless of which option carried a recommendation label.
**Proposed by:** joint
**Relates to:** Stage 011, Decision 1 (the mitigation this decision supersedes)

### Decision 4: Installer drift fixed via dev-time generation, not runtime path resolution
**Chosen:** A new `tools/generate-install-hooks.sh` regenerates the shared installer's embedded `session_start.sh`/`post_tool_use.sh` content from the canonical `agent-hooks/claude/*.sh` files at development time. `tools/install-agent-hooks.sh` itself remains fully self-contained at runtime, with no filesystem lookup of `agent-hooks/`. A regression test compares the installer's embedded content against the canonical source directly.
**Rationale:** Investigation found the shipped installer had never received stage 011's fixes at all — it embedded an independent, hand-maintained copy that had silently gone stale. An initial plan to fix this by having the installer resolve `agent-hooks/` via relative filesystem paths at runtime (restoring an approach used earlier in stage 007's history) was corrected during review: `tools/` is shared, language-agnostic infrastructure meant to serve every current and future language binding, and that stage-007 runtime-lookup approach had itself been deliberately replaced with inline embedding specifically to avoid coupling the shared installer's behavior to any one binding's install-layout assumptions. Reintroducing it would have undone that reasoning. A dev-time generation step preserves runtime self-containment while still guaranteeing the embedded copy cannot drift silently, since a regression test now compares it against the canonical source directly.
**Tradeoffs:** The generation script must be remembered and run manually after editing `agent-hooks/`; the regression test is what actually prevents silent drift if it isn't.
**Proposed by:** mpadge
**Relates to:** Stage 007, Decision 2 (single-source-of-truth intent) and Decision 3 (the shared installer script this decision keeps runtime-generic)

## Integration with Prior Work
Builds directly on stage 011's structured-prefix and directive-line mechanism, sharpening both the delivery guarantee (halting vs. advisory) and the field's truthfulness (severity-differentiated rather than uniform), without reopening stage 007's message-text/hook-context trust-boundary split. Decision 4 also reaffirms stage 007's own "single source of truth avoids drift" rationale for `agent-hooks/`, which a later, undocumented commit within that same stage had silently undermined.

## Issues Resolved
- Field report: agent read the scenario-check advisory and offered a workaround as a menu option anyway — resolved via halting (Decision 1) and removing the menu framing from hook guidance (Decision 3).
- `directive:` field carrying the same value regardless of whether a signal actually gated anything — resolved via severity differentiation (Decision 2).
- Shipped R-package installer never having received stage 011's hook-text fixes, silently, since the moment they were introduced — resolved via dev-time generation plus a drift regression test (Decision 4).

## Deferred Items
- Advice point regarding making package-author scenario text maximally concrete/actionable — no new mechanism found missing; the existing free-text `scenarios` argument to `askfirst_init()` already supports it.

## Process Notes
- The plan for Decision 4 changed direction mid-review: the first draft proposed restoring stage 007's original relative-path hook resolution in the installer; this was corrected once it was pointed out that the earlier reversion away from that approach was itself a deliberate language-agnosticism decision, not an oversight, redirecting the fix toward dev-time generation instead.
