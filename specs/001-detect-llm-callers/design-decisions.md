---
created: 2026-07-25T15:08:44Z
agent: claude-sonnet-5
git_hash: beeed0a39a475fe866a605b4a58f6ad68b83a2a7
---

# Design Decisions: detect-llm-callers

## Summary
This stage is the project's first design stage: a research-only
investigation into how `pkghooks` could detect that an R package is being
driven by an LLM/AI agent, and how it could deliver a redirect-to-maintainer
message. All twelve planned research tasks were completed and synthesized
into `design.md`, which is decision-ready input for a follow-up
implementation stage.

## New Design Decisions

### Decision 1: Env-var table as primary detection signal, TTY/ancestry as corroboration only
**Chosen:** A maintained table of per-tool environment-variable markers
(e.g. `CLAUDECODE`, `CURSOR_AGENT`, `GEMINI_CLI`), checked once per session,
as the primary signal. TTY attachment and parent-process ancestry are
optional, non-standalone corroborating signals.
**Rationale:** Env vars are set by the calling tool's own process spawning
and require no cooperation from the target package or its users; TTY alone
false-positives on ordinary non-interactive human automation (CI, scripted
runs), so it cannot stand alone.
**Tradeoffs:** No coverage for agent tools that reuse a human's existing
terminal without a distinct marker (a known gap for at least one current
tool).

### Decision 2: Call-stack introspection rejected; `btw` cooperation deferred
**Chosen:** R call-stack/frame introspection is excluded entirely as a
detection category. `btw` package cooperation is treated as a real but
deferred signal, not built into v1.
**Rationale:** Call-stack shape is identical for human- and agent-driven
invocation once execution reaches a hooked function. `btw` cooperation would
require an upstream change and covers only `btw`-mediated sessions.
**Tradeoffs:** Leaves a higher-confidence cooperative signal unused for now.

### Decision 3: Three independent message intervention points
**Chosen:** Load-time, error-time, and capability-gap-time messaging, each
independent; first-call and every-call points explicitly ruled out.
**Rationale:** Load-time is cheapest/most reliable; error-time reuses R's
condition system; capability-gap-time cannot piggyback on error-time since
nothing errors, and was found to require author opt-in with no viable
mechanical alternative.
**Tradeoffs:** Capability-gap detection depends on package authors
proactively instrumenting known limitations.

### Decision 4: Layered message-delivery mechanism
**Chosen:** A custom, self-describing R condition class as the primary
channel (non-fatal at load time), with an actual halting error reserved for
capability-gap/error-time interventions.
**Rationale:** No single R condition-system primitive is guaranteed to be
surfaced across all agent-tool architectures (raw subprocess capture vs.
MCP tool call vs. persistent session).
**Tradeoffs:** Delivery reliability is not guaranteed under any mechanism;
design accepts probabilistic surfacing rather than certainty.

### Decision 5: R-only package, portable detection data
**Chosen:** `pkghooks` ships as an R-only package; its detection table is
structured as swappable data rather than logic entangled with R-specific
integration code.
**Rationale:** Detection signals are OS/process-level facts, not R-specific,
and direct prior art (`vercel/detect-agent`, `unjs/std-env`) already
implements the same pattern outside R.
**Tradeoffs:** None significant.

## Integration with Prior Work
This is the project's first stage; there is no prior work to integrate with.

## Issues Resolved
- Whether `interactive()` alone suffices for detection: resolved no — it
  cannot distinguish a human console session from an agent driving a
  persistent interactive R session via piped input.
- Whether capability-gap detection can avoid author opt-in: resolved no.
- Whether R-only scope is the right boundary: resolved yes for the package
  itself, with detection logic kept portable internally.

## Deferred Items
- `btw` upstream marker integration.
- Registry-style (vs. inline) capability-gap declarations.
- Parent-process ancestry (`ps`-based) detection as a built-in v1 feature.
- Exposing detection confidence tiers to adopting packages.
- Env-var table maintenance process and sync strategy with external specs.
- Testing strategy for environment-dependent detection code.

## Process Notes
- No blockers encountered. Findings were grounded in current, authoritative
  external sources (`vercel/detect-agent`'s `agents.json`, `unjs/std-env`,
  official `btw` documentation) rather than assumption.
