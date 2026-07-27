---
created: 2026-07-25T15:08:44Z
agent: claude-sonnet-5
git_hash: 1665282db9e3310c9b376db1e1c5b844058a4189
---

# Design Decisions: pkghooks

## Current Architecture
`pkghooks` is an R package intended to let R package maintainers detect
when their functions are being called from an LLM/AI coding agent rather
than a human, and to issue a message that redirects the agent to tell the
human user to contact the maintainer directly — instead of the agent
silently working around a bug or missing capability. Two design stages are
complete. Stage 001 produced research-only findings (no code). Stage 002
produced the project's first concrete artifact: `agent-detect-spec/`, a
language-agnostic contract consisting of vendored upstream detection data
(`vendor/agents.json`, from `vercel/detect-agent`), a confidence-tiering
model, an intervention-point model, a versioned manifest, and an automated
GitHub Action that keeps the vendored data synced with upstream. No
R-specific implementation code exists yet; that is the next stage's work.

## Key Decisions

### Detection: vendor upstream data directly, no independent schema
**Outcome:** `agent-detect-spec/vendor/agents.json` and
`agents.schema.json` are unmodified copies of `vercel/detect-agent`'s
files, consumed as-is via a weekly, PR-gated GitHub Action sync. No
`pkghooks`-specific detection schema or data file exists.
**Rationale:** Stage 001 found direct prior art outside R
(`vercel/detect-agent`, `unjs/std-env`) implementing the same
env-var/process detection pattern. Stage 002 initially planned to model a
parallel schema on that prior art, but this was identified mid-stage as
pure duplication with no coverage benefit, since the upstream data already
covers the tools stage 001 surveyed (plus additional ones). Vendoring
directly, kept current by automation, avoids maintaining two divergent
representations of the same facts.
**Roads not taken:** R call-stack/frame introspection (identical shape for
human- and agent-driven calls, no usable signal); `commandArgs()` alone
(too coarse); `interactive()` alone (true for both a human console and an
agent driving a persistent interactive session via piped input);
cooperative-only detection via the `btw` package (would require an
upstream change and only covers `btw`-mediated sessions — deferred, not
rejected); designing an independent `pkghooks`-specific detection schema
(reversed mid-stage 002 in favor of direct vendoring).
**Stages:** 001, 002

### Confidence: a closed, language-neutral tier enum layered on vendored data
**Outcome:** `agent-detect-spec/confidence-model.md` defines
`high`/`medium`/`low`/`cooperative` as a closed enum, with mapping rules
from a raw detection outcome (vendored-data match, plus optional
TTY/process-ancestry corroboration) onto a tier. `cooperative` is reserved
for a future tool-initiated signal, currently unused.
**Rationale:** Vendored detection data carries no confidence concept of
its own; this layer is `pkghooks`'s own contribution on top of it. A
closed enum is simpler for every consuming implementation to reason about,
and extending it later is additive rather than breaking.
**Roads not taken:** An open/extensible tier set (deferred as unnecessary
complexity for v1); exposing confidence tiers only internally rather than
as a documented contract (rejected, since future non-R implementations
need the same mapping rules).
**Stages:** 001, 002

### Messaging: three independent intervention points, layered delivery, now language-neutral
**Outcome:** Redirect messages fire at three independent points —
package-load (a general one-time notice), error-time (layered onto errors
the package already raises), and capability-gap-time (a distinct point
requiring explicit author instrumentation). These are now specified in
`agent-detect-spec/intervention-model.md` as language-neutral concepts
(trigger, default severity, cardinality), independent of any language's
native delivery mechanism. R's own delivery mechanism (a custom condition
class, non-fatal at load time, reserving halting errors for
capability-gap/error-time) remains a stage-001 finding not yet
re-specified at the language-neutral layer, since it is R-specific by
nature.
**Rationale:** Load-time is the cheapest, most reliable point and
sidesteps per-call overhead entirely. Error-time reuses the existing
error/condition system at no extra detection cost. Capability-gap-time
cannot piggyback on error-time because no condition is raised; only
author-driven annotation satisfies the no-false-positive constraint.
Extracting the abstract model (stage 002) lets future non-R
implementations reuse the same three points without re-deriving them.
**Roads not taken:** First-call and every-call intervention points (ruled
out for overhead and message-fatigue reasons); help/documentation-access
hooking (not readily hookable in R, deferred; future implementations
should re-evaluate for their own language); a registry-style
capability-gap declaration (adds a rules-engine problem without clear v1
payoff over inline marking); return-value attribute annotation as a
primary channel (too easily dropped/ignored to serve as more than a
secondary, structured channel).
**Stages:** 001, 002

### Scope: R-only package, portable contract as a separate directory
**Outcome:** `pkghooks` ships and is branded as an R-only package. Its
detection/confidence/messaging contract lives in a top-level
`agent-detect-spec/` directory, independent of the R package's own `R/`,
`man/`, `tests/` structure and understandable without reference to this
project's internal stage history. `.onLoad()`/`.onAttach()` remain the
concrete R integration point, not yet implemented.
**Rationale:** The detection signals and messaging model are language-,
not R-, specific facts; keeping them in a separate, self-contained
directory (rather than entangled with R package internals, and rather than
standing up a separate repo pre-emptively) eases both future non-R reuse
and current R implementation, following a comparable project's precedent
of splitting into independently-shippable units only once genuinely
independent consumers exist.
**Roads not taken:** A fully language-agnostic multi-language project in
this stage — still explicitly out of scope; the recommendation is a
structuring choice for `pkghooks`'s internals, not a commitment to
building beyond R now. A standalone repo for `agent-detect-spec/` from day
one — deferred until a second, genuinely independent language
implementation actually exists.
**Stages:** 001, 002

## Architectural Evolution
Stage 001 established the project's foundational research: what signals
can identify an LLM-driven caller, how a redirect message could reach it,
and where in an R session that message should fire. Stage 002 turned the
portable parts of that research into a real, versioned artifact
(`agent-detect-spec/`), while narrowing its own scope mid-stage once it
became clear that re-deriving a detection schema already covered by
`vercel/detect-agent` would be pure duplication. The project now has a
complete, self-contained, language-agnostic contract, but still no R
implementation code — that is the next stage's expected work, consuming
`agent-detect-spec/manifest.json`, `confidence-model.md`, and
`intervention-model.md` to build `pkghooks_init()`, `flag_capability_gap()`,
and the R condition-class delivery mechanism.

## Important Roads Not Taken
**Detection:**
- Call-stack/frame introspection — no usable signal exists at the R
  language level; identical shape for human and agent callers.
- `interactive()` as a standalone detector — true for both a human console
  session and an agent driving a persistent interactive session.
- TTY attachment or `commandArgs()` as standalone detectors — both
  false-positive on ordinary non-interactive human automation (CI,
  scripted runs).
- An independent, `pkghooks`-specific detection schema — designed
  initially in stage 002, then reversed mid-stage in favor of vendoring
  `vercel/detect-agent`'s data directly, once duplication with no coverage
  benefit was identified.

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
  portable internals — still deferred as premature; only the contract
  (`agent-detect-spec/`) is language-agnostic so far, not any actual code.
- Standing up a separate repo for the portable contract immediately —
  deferred until a second, independent language implementation exists.
