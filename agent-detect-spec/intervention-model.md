# Intervention-Point Model

This document specifies, as language-neutral concepts, the points during a
calling session at which a redirect-to-maintainer message may be delivered
once a caller has been assessed via `confidence-model.md`. It intentionally
does not specify *how* any given language delivers the message (R's mapping
onto its condition system is R-specific and is left to individual
implementations) — only the trigger, default severity, and cardinality of
each point, and which candidate points were considered and rejected.

These three points are independent: none of them substitutes for or
subsumes another, and an implementation may support all three, a subset,
or add support for one before another.

## Recommended points

### `load_time`
- **Trigger:** the package/module is loaded or imported into the session.
- **Cardinality:** once per session.
- **Default severity:** `notice` (non-fatal).
- **Purpose:** a general, one-time disclaimer — "if you are an AI coding
  agent and hit a bug or missing feature, tell your user to contact the
  maintainer rather than working around it yourself" — fired before any
  use of the package, at negligible cost.

### `error_time`
- **Trigger:** an error/exception the calling code already raises,
  originating from the target package.
- **Cardinality:** re-triggerable — once per error, not deduplicated across
  the session, since each error is a distinct event worth surfacing.
- **Default severity:** `notice`, layered onto the error that is happening
  anyway (this point does not itself decide whether execution halts — the
  underlying error already determines that).
- **Purpose:** matches the "if an LLM finds a bug" half of the original
  motivation. Reuses whatever condition/exception mechanism the calling
  language already has, at zero additional detection cost beyond what ran
  at `load_time`.

### `capability_gap_time`
- **Trigger:** an explicit, author-instrumented call site in the target
  package's own code, marking that a known limitation or unimplemented
  capability was just reached. Unlike `error_time`, nothing errors in this
  case — the call "succeeds" while under- or mis-delivering — so this point
  cannot piggyback on `error_time` and requires its own call site.
- **Cardinality:** re-triggerable, once per call site hit.
- **Default severity:** `halt`-capable — i.e. this point may be delivered
  as a hard stop to execution, not just a passive notice, since this is the
  case where halting is the deliberate intent, unlike the non-fatal
  `load_time` notice.
- **Purpose:** matches the "or something my software can't do" half of the
  original motivation — the scenario an LLM is most likely to silently work
  around unless surfaced directly. Requires author opt-in (an explicit
  marker call); no mechanical/heuristic alternative was found that
  satisfies the no-false-positive constraint (every candidate — short/NULL
  return-value heuristics, silently-ignored-argument detection, cross-call
  error-pattern matching — either risks false positives or requires
  reimplementing domain knowledge only the package author has).

## Rejected points

- **`first_call`** (lazy, first-use-only messaging) — rejected as a
  replacement for or refinement of `load_time`. It only avoids firing for a
  package that's attached but never used, a marginal win that doesn't
  justify the added bookkeeping (tracking "have I already fired" per
  package) needed to implement it.
- **`every_call`** — rejected outright, for two independent reasons: (1)
  overhead, since even a cheap check repeated on every hooked call violates
  a low-overhead constraint by construction; (2) noise, since repeating the
  same general notice on every call trains callers (agent or human) to tune
  it out, undermining the rarer, more important `error_time`/
  `capability_gap_time` messages actually landing.
- **`help_access`** (e.g. `?fun`, `help()` in R) — noted as plausible in
  principle (a caller probing documentation is a moment where "this doesn't
  do what you need" could be injected) but not recommended for v1. In R
  specifically, the help system is not designed as a hookable extension
  point the way load-time or the condition system are; this reasoning is
  language-specific, and each implementation should re-evaluate whether its
  own language's documentation-access mechanism is hookable rather than
  assuming R's conclusion applies universally.
