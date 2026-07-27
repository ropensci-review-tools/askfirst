---
created: 2026-07-27T16:52:00Z
agent: claude-sonnet-5
git_hash: 01e8c3fb12f24b22888144a4eb02ae71a5d91f87
---

# Design Decisions: Contribute Upstream Guidance

## Summary
Replaced the vague, unattributed "the capability may belong in `{pkg}` itself" framing in askfirst's two generated messages with a concrete, attributed invitation, backed by two new optional `askfirst_init()` fields (`contribute_how`, `contribute_url`) maintainers can use to point at their own contribution process.

## New Design Decisions

### Decision 1: Two new optional `askfirst_init()` fields, package-level only
**Chosen:** `contribute_how` (free text) and `contribute_url` (a single URL), both default `NULL`, stored in the package registry alongside `notice`/`scenarios`/`on_error`. No per-call override on `askfirst_capability_gap()`.
**Rationale:** Keeps one place per package to register contribution guidance; `askfirst_capability_gap()` doesn't consume these fields at all this stage (see Decision 2), so a per-call override was moot.
**Tradeoffs:** A single capability-gap call can't point somewhere more specific than the package-wide default; not needed since capability_gap is out of scope here.
**Proposed by:** joint

### Decision 2: Scope limited to `askfirst_build_notice()` and `askfirst_build_scenario_check_message()`
**Chosen:** The new invitation text is wired into exactly these two askfirst-generated message builders. `askfirst_capability_gap()` (message fully author-supplied, no askfirst-added boilerplate) and `askfirst_error_redirect` (deliberately reuses raw `notice` text verbatim, stage 003) are unchanged.
**Rationale:** These two functions are the only places carrying the vague generic phrasing this stage set out to fix; extending to the other two signal types would have been a different, unrequested change to their existing, deliberate behavior.
**Proposed by:** joint
**Relates to:** Stage 003 (established `error_redirect`'s verbatim-`notice`-reuse behavior, left intact here)

### Decision 3: Shared `askfirst_build_contribute_line()` helper, base sentence always present
**Chosen:** One internal helper builds the "contribute" text for both message points. It always returns a base sentence naming `askfirst` by name ("The developers of `{pkg}` use the 'askfirst' system...") even when neither optional field is registered, with "how"/"where" sentences appended only when supplied.
**Rationale:** A single shared builder prevents the two messages' wording from independently drifting, the way stage 011 found duplicated scenario bullets had. The always-present base sentence means the message never silently reverts to the old, fully unattributed wording — every adopter gets at least the attribution, whether or not they've supplied concrete guidance.
**Proposed by:** joint
**Relates to:** Stage 011, Decision 2 (the scenario-bullet-duplication drift this stage's shared-helper approach avoids repeating)

### Decision 4: No unqualified second-person "you" in the new text
**Chosen:** Every sentence in the new "contribute" text names its addressee explicitly (e.g. "the human user of `{pkg}`"), rather than the "You are invited to contribute" phrasing originally proposed.
**Rationale:** Identified during plan review: the calling agent is the direct reader/parser of this message text, not a human reading over its shoulder. An unqualified "you" defaults to being read as addressing the agent itself — not merely a tone issue, but actively wrong, since the invitation is meant for the human. A misread invitation could plausibly lead an agent to conclude it should go open an upstream PR unsupervised, which is precisely the kind of autonomous action askfirst exists to route through the human first.
**Proposed by:** git-user
**Relates to:** Stage 007, Decision 4 (message text stays neutral/non-second-person; this decision extends that constraint to cover referent ambiguity, not just imperative tone)

## Integration with Prior Work
Builds on the message-generating functions established in stages 003/004 (`askfirst_build_notice()`, `askfirst_build_scenario_check_message()`) without touching their signalling mechanism — stage 012's halting/directive-severity work for `scenario_check` is unaffected; this stage only changes message *content*, not delivery. Extends stage 007's message-text-stays-neutral principle with a more specific rule about second-person referent ambiguity that hadn't been articulated before.

## Issues Resolved
- Vague, unattributed "capability may belong in `{pkg}` itself" framing in the load-time notice and scenario-check message: resolved via the shared contribute-line helper and new optional fields.
- Ambiguous "you" in the originally-proposed message wording (would have been read by the agent as addressing itself): caught during plan review before implementation, resolved by naming the addressee explicitly in every sentence.

## Deferred Items
- Extending this messaging to `askfirst_capability_gap()` or `error_redirect` — not attempted this stage; would need its own scoping discussion given `error_redirect`'s deliberate verbatim-notice-reuse design.
- Per-call contribution overrides on `askfirst_capability_gap()` — deferred as unnecessary until/unless that function gains this messaging at all.

## Process Notes
- The plan's first draft used "You are invited to contribute by ..." (the literal phrasing from the initial feature request) before the referent-ambiguity issue was raised and the plan was revised to remove all unqualified second-person address.
- After implementation, the `askfirst-development.Rmd` vignette's demo `.onLoad()` was also updated to include the new fields, on request, for consistency with `using-askfirst.Rmd` — not part of the original task list.
