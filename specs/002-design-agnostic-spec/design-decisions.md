---
created: 2026-07-27T10:35:00Z
agent: claude-sonnet-5
git_hash: 1665282db9e3310c9b376db1e1c5b844058a4189
---

# Design Decisions: design-agnostic-spec

## Summary
This stage produced `agent-detect-spec/`, a language-agnostic contract for
LLM/AI-agent-caller detection and messaging. Its scope was revised
mid-stage: rather than designing an independent detection-signal schema,
it vendors `vercel/detect-agent`'s `agents.json` verbatim and adds only
the confidence-tiering and intervention-point layers that upstream data
doesn't provide.

## New Design Decisions

### Decision 1: Vendor upstream detection data instead of re-deriving it
**Chosen:** `agent-detect-spec/vendor/agents.json` and
`agents.schema.json` are unmodified copies of `vercel/detect-agent`'s
files, consumed directly using upstream's own schema.
**Rationale:** Stage 001 had already identified `agents.json` as
proven, actively maintained prior art. Designing a parallel schema and
hand-populating an equivalent data file was found, mid-stage, to
duplicate that maintenance burden for no coverage gain.
**Tradeoffs:** Couples this project to upstream's schema shape; any
`pkghooks`-specific concept (confidence, messaging) must live in a
separate layer rather than annotated directly onto detection entries.
**Relates to:** Builds directly on stage 001's Decision 5 (portable
detection data) and its prior-art finding (T001-10 in that stage's
research), taking the "model it the same way" recommendation one step
further into "vendor it directly."

### Decision 2: Confidence-tiering model as an explicit layer
**Chosen:** `agent-detect-spec/confidence-model.md` defines a closed
`high`/`medium`/`low`/`cooperative` enum, with mapping rules from a raw
vendored-data match (plus optional TTY/process-ancestry corroboration)
onto a tier. `cooperative` is reserved, currently unused, for a future
tool-initiated signal.
**Rationale:** Vendored data identifies *which* tool is calling but
carries no confidence concept; a closed enum is simpler for every
consuming implementation to reason about, and is additive to extend
later.
**Tradeoffs:** A closed enum may eventually need a breaking revision if
future language implementations need finer-grained tiers than
high/medium/low.
**Relates to:** Resolves stage 001's open question on confidence-tier
exposure.

### Decision 3: Intervention-point model as a separate, language-neutral layer
**Chosen:** `agent-detect-spec/intervention-model.md` specifies three
independent points — `load_time`, `error_time`, `capability_gap_time` —
each with trigger, default severity, and cardinality, deliberately
excluding any language-specific delivery mechanism.
**Rationale:** Extracts the language-neutral concepts behind stage 001's
R-specific condition-class recommendation, so future non-R
implementations can map the same three points onto their own native
mechanisms.
**Tradeoffs:** None significant; carries forward stage 001's rejection of
`first_call`/`every_call`/`help_access` rather than re-litigating them.
**Relates to:** Directly derived from stage 001's Decisions 3 and 4.

### Decision 4: Automated, PR-gated upstream sync
**Chosen:** `.github/workflows/sync-agent-detect-spec.yml` runs weekly
(plus manual dispatch), diffs upstream `agents.json` against the vendored
copy, and opens a pull request on any difference rather than auto-merging.
**Rationale:** Keeps vendored data current without manual polling, while
requiring human review before a detection-data change takes effect for
all consumers.
**Tradeoffs:** Adds a recurring CI dependency and a third-party GitHub
Action.

## Integration with Prior Work
This stage operationalizes stage 001's research: its env-var/TTY/ancestry
detection findings are now backed by real vendored data instead of a
research table, and its three-intervention-point and confidence-tier
recommendations are now written as concrete, versioned specification
files rather than prose recommendations.

## Issues Resolved
- Whether to model `pkghooks`'s own schema on `agents.json` or consume it
  directly: resolved in favor of direct consumption, reversing this
  stage's own initial plan.
- Confidence-tier enum openness (stage 001's open question): resolved as
  a closed enum for v1.
- Detection-data shape (flat vs. namespaced): resolved as moot, since the
  vendored file's shape is inherited from upstream rather than designed
  independently.

## Deferred Items
- `btw`-style cooperative signal implementation (the `cooperative` tier
  remains unused).
- Exact reconciliation process if a future upstream change requires more
  than a straight file replacement.
- R-specific integration mechanics (`.onLoad()`/`.onAttach()` wiring,
  condition-class naming, `pkghooks_init()`/`flag_capability_gap()` API
  shape) — left for a follow-up implementation stage.

## Process Notes
- Scope was reduced mid-stage after a direct question about redundancy
  with existing prior art; the plan and tasks were revised before
  implementation began, rather than after.
- A follow-up request removed all references to internal stage/task
  identifiers from every file under `agent-detect-spec/`, so the
  directory is understandable independent of this project's `specs/`
  history.
