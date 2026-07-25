---
created: 2026-07-25T15:08:44Z
agent: claude-sonnet-5
git_hash: beeed0a39a475fe866a605b4a58f6ad68b83a2a7
---

# Design Decisions: pkghooks

## Current Architecture
`pkghooks` is an R package, in its first design stage, intended to let R
package maintainers detect when their functions are being called from an
LLM/AI coding agent rather than a human, and to issue a message that
redirects the agent to tell the human user to contact the maintainer
directly — instead of the agent silently working around a bug or missing
capability. No implementation code exists yet; this stage produced a
decision-ready design (`specs/001-detect-llm-callers/design.md`) covering
detection, messaging, and integration points, intended as direct input for
a follow-up implementation stage.

## Key Decisions

### Detection: env-var table as primary signal
**Outcome:** A maintained table of per-tool environment-variable markers
(e.g. `CLAUDECODE`, `CURSOR_AGENT`, `GEMINI_CLI`), read once per session via
`Sys.getenv()`, is the primary detection signal. TTY attachment and
parent-process ancestry serve only as corroborating signals, never
standalone.
**Rationale:** These markers are set by the calling tool's own process
spawning, requiring no cooperation from the target package's users, and
carry a low false-positive risk for ordinary human/CI use. Direct prior art
exists outside R (`vercel/detect-agent`, `unjs/std-env`), which use the same
approach and de-risk it as proven, not speculative.
**Roads not taken:** R call-stack/frame introspection (identical shape for
human- and agent-driven calls, no usable signal); `commandArgs()` alone (too
coarse); `interactive()` alone (true for both a human console and an agent
driving a persistent interactive session via piped input); cooperative-only
detection via the `btw` package (would require an upstream change and only
covers `btw`-mediated sessions — deferred, not rejected).
**Stages:** 001

### Messaging: three independent intervention points, layered delivery
**Outcome:** Redirect messages fire at three independent points —
package-load (a general one-time notice), error-time (layered onto errors
the package already raises), and capability-gap-time (a distinct point
requiring explicit author instrumentation, since nothing errors in a
capability-gap case). Delivery uses a custom R condition class as the
primary, non-fatal channel, reserving actual halting errors for the
error-time/capability-gap-time points.
**Rationale:** Load-time is the cheapest, most reliable point and
sidesteps per-call overhead entirely. Error-time reuses R's existing
condition system at no extra detection cost. Capability-gap-time cannot
piggyback on error-time because no condition is raised; after evaluating
mechanical/heuristic alternatives, only author-driven annotation (an inline
`flag_capability_gap()` call) satisfied the no-false-positive constraint.
No single R condition primitive is guaranteed to be surfaced across every
possible agent-tool architecture, so delivery is intentionally layered
rather than committed to one mechanism.
**Roads not taken:** First-call and every-call intervention points (ruled
out for overhead and message-fatigue reasons); help/documentation-access
hooking (not readily hookable in R, deferred); a registry-style
capability-gap declaration (adds a rules-engine problem without clear v1
payoff over inline marking); return-value attribute annotation as a primary
channel (too easily dropped/ignored to serve as more than a secondary,
structured channel).
**Stages:** 001

### Scope: R-only package, portable detection data
**Outcome:** `pkghooks` ships and is branded as an R-only package. Its
detection table is structured internally as swappable data (an env-var →
tool mapping) rather than logic entangled with R-specific integration code.
`.onLoad()`/`.onAttach()` remain the concrete R integration point.
**Rationale:** The detection signals themselves are OS/process-level facts,
not R-specific, and a data-driven structure eases keeping the table current
as new agent tools appear, and leaves room for reuse by a non-R
implementation later without redesigning the detection logic.
**Roads not taken:** A fully language-agnostic multi-language project in
this stage — considered and explicitly scoped out as premature; the
recommendation is a structuring choice for `pkghooks`'s internals, not a
commitment to building beyond R now.
**Stages:** 001

## Architectural Evolution
Stage 001 established the project's foundational research: what signals
can identify an LLM-driven caller, how a redirect message could reach it,
and where in an R session that message should fire. No architecture has
been built yet — this stage's output is a design document, not code. The
next stage is expected to turn this into an actual `pkghooks` implementation
plan (see `specs/001-detect-llm-callers/design.md`'s open questions for
what remains unresolved: detection-table schema, condition-class naming,
`btw` integration timing, `ps`-based ancestry detection scope, confidence
tiering, and testing strategy for environment-dependent code).

## Important Roads Not Taken
**Detection:**
- Call-stack/frame introspection — no usable signal exists at the R
  language level; identical shape for human and agent callers.
- `interactive()` as a standalone detector — true for both a human console
  session and an agent driving a persistent interactive session.
- TTY attachment or `commandArgs()` as standalone detectors — both
  false-positive on ordinary non-interactive human automation (CI, scripted
  runs).

**Messaging:**
- Firing on every function call — violates the low-overhead constraint and
  produces noise that would undermine rarer, more important messages.
- Firing on first function call only — marginal benefit over load-time for
  added bookkeeping complexity.
- Mechanical/heuristic capability-gap detection without author
  involvement — every approach explored (short/NULL return heuristics,
  silently-ignored-argument detection, cross-call error-pattern matching)
  risked false positives or required reimplementing domain knowledge only
  the package author has.

**Scope:**
- Building a language-agnostic implementation now, rather than R-only with
  portable internals — deferred as premature for a research-only first
  stage.
