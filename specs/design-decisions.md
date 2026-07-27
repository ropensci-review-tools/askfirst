---
created: 2026-07-25T15:08:44Z
agent: claude-sonnet-5
git_hash: 660b6a49e4375626d2780a2d04dcded25e108bfb
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
vendored, upstream-synced copy of `vercel/detect-agent`'s detection data
(`vendor/agents.json`), with a versioned manifest and an automated GitHub
Action that keeps it synced with upstream. The confidence-tiering and
intervention-point models designed alongside it were initially shipped as
standalone files in that directory, then — after the retrospective —
removed and folded back into `specs/002-design-agnostic-spec/design.md`
and `design-decisions.md` as documented design rationale, since they were
unenforced prose rather than machine-read data. No R-specific
implementation code exists yet; that is the next stage's work, and it will
need to consult stage 002's design documents (not `agent-detect-spec/`
itself) for the confidence and messaging reasoning.

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

### Confidence: a closed, language-neutral tier enum, documented as design rationale
**Outcome:** A closed `high`/`medium`/`low`/`cooperative` enum, with
mapping rules from a raw detection outcome (vendored-data match, plus
optional TTY/process-ancestry corroboration) onto a tier. `cooperative` is
reserved for a future tool-initiated signal, currently unused. Documented
in `specs/002-design-agnostic-spec/design.md` (T002-4) and
`design-decisions.md`, not as a standalone file in `agent-detect-spec/`.
**Rationale:** Vendored detection data carries no confidence concept of
its own; this layer is `pkghooks`'s own contribution on top of it. A
closed enum is simpler for every consuming implementation to reason about,
and extending it later is additive rather than breaking. Originally
shipped as `agent-detect-spec/confidence-model.md`; moved to the stage's
own design documents once it was recognized that unenforced prose in a
"spec" directory implied a guarantee (consistency across implementations)
it couldn't actually provide.
**Roads not taken:** An open/extensible tier set (deferred as unnecessary
complexity for v1); keeping it as a standalone file under
`agent-detect-spec/` (reversed post-retrospective — see Scope decision
below).
**Stages:** 001, 002

### Messaging: three independent intervention points, layered delivery, documented as design rationale
**Outcome:** Redirect messages fire at three independent points —
package-load (a general one-time notice), error-time (layered onto errors
the package already raises), and capability-gap-time (a distinct point
requiring explicit author instrumentation). These are specified as
language-neutral concepts (trigger, default severity, cardinality),
independent of any language's native delivery mechanism, in
`specs/002-design-agnostic-spec/design.md` (T002-5) and
`design-decisions.md` — not as a standalone file in `agent-detect-spec/`.
R's own delivery mechanism (a custom condition class, non-fatal at load
time, reserving halting errors for capability-gap/error-time) remains a
stage-001 finding not yet re-specified at the language-neutral layer,
since it is R-specific by nature.
**Rationale:** Load-time is the cheapest, most reliable point and
sidesteps per-call overhead entirely. Error-time reuses the existing
error/condition system at no extra detection cost. Capability-gap-time
cannot piggyback on error-time because no condition is raised; only
author-driven annotation satisfies the no-false-positive constraint.
Extracting the abstract model (stage 002) lets future non-R
implementations reuse the same three points without re-deriving them.
Originally shipped as `agent-detect-spec/intervention-model.md`; moved to
the stage's own design documents for the same reason as the Confidence
decision above.
**Roads not taken:** First-call and every-call intervention points (ruled
out for overhead and message-fatigue reasons); help/documentation-access
hooking (not readily hookable in R, deferred; future implementations
should re-evaluate for their own language); a registry-style
capability-gap declaration (adds a rules-engine problem without clear v1
payoff over inline marking); return-value attribute annotation as a
primary channel (too easily dropped/ignored to serve as more than a
secondary, structured channel); keeping it as a standalone file under
`agent-detect-spec/` (reversed post-retrospective).
**Stages:** 001, 002

### Scope: R-only package, vendored data kept separate, design rationale kept in specs/
**Outcome:** `pkghooks` ships and is branded as an R-only package.
`agent-detect-spec/` holds only the vendored, machine-read detection data
(`vendor/agents.json`) plus its manifest and sync tooling — independent of
the R package's own `R/`, `man/`, `tests/` structure. The confidence and
messaging design reasoning that accompanies it lives in `specs/`'s stage
documents instead of alongside the vendored data, since it is unenforced
prose rather than something any code reads. `.onLoad()`/`.onAttach()`
remain the concrete R integration point, not yet implemented.
**Rationale:** Keeping *machine-read data* in a separate, self-contained
directory (rather than entangled with R package internals, and rather than
standing up a separate repo pre-emptively) eases both future non-R reuse
and current R implementation, following a comparable project's precedent
of splitting into independently-shippable units only once genuinely
independent consumers exist. Design *reasoning* that has no machine
consumer, however, was found to not need — and to overstate its own
weight by pretending to be — a standalone "contract" file; it belongs in
the project's own design record instead, to be consulted rather than
enforced.
**Roads not taken:** A fully language-agnostic multi-language project in
this stage — still explicitly out of scope; the recommendation is a
structuring choice for `pkghooks`'s internals, not a commitment to
building beyond R now. A standalone repo for `agent-detect-spec/` from day
one — deferred until a second, genuinely independent language
implementation actually exists. Treating the confidence/intervention
models as part of that same portable-directory contract — reversed
post-retrospective, once it was recognized they lacked any enforcement
mechanism `vendor/agents.json` actually has.
**Stages:** 001, 002

## Architectural Evolution
Stage 001 established the project's foundational research: what signals
can identify an LLM-driven caller, how a redirect message could reach it,
and where in an R session that message should fire. Stage 002 turned the
portable, machine-read part of that research into a real, versioned
artifact (`agent-detect-spec/`), narrowing its own scope twice: mid-stage,
once it became clear that re-deriving a detection schema already covered
by `vercel/detect-agent` would be pure duplication; and again
post-retrospective, once the confidence-tiering and intervention-point
models — shipped initially as standalone files alongside the vendored
data — were recognized as unenforced design prose rather than a real
contract, and folded back into the stage's own design documents. The
project now has a narrow, honest `agent-detect-spec/` (vendored data only)
plus a documented design rationale in `specs/002-design-agnostic-spec/`,
but still no R implementation code — that is the next stage's expected
work, consuming `agent-detect-spec/manifest.json` for the vendored data
and stage 002's `design.md`/`design-decisions.md` for the confidence and
messaging reasoning, to build `pkghooks_init()`, `flag_capability_gap()`,
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
  portable internals — still deferred as premature; only the vendored
  detection data is language-agnostic so far, not any actual code.
- Standing up a separate repo for the vendored data immediately — deferred
  until a second, independent language implementation exists.
- Shipping the confidence-tiering and intervention-point models as
  standalone files under `agent-detect-spec/` — reversed post-retrospective
  once it was recognized that, unlike the vendored data, nothing in the
  repo actually reads or enforces them; folded back into `specs/`'s design
  documents instead.
