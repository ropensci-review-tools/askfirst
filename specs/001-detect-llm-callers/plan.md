---
created: 2026-07-24T11:11:18Z
agent: claude-sonnet-5
git_hash: 69af0c47a3f6fdd2820e3049062d8151bb9fc1ef
---

# Plan: detect-llm-callers

## Overview
Research and design approaches for detecting when software is being driven by an LLM (vs. a human caller), and for issuing a redirect message that prompts the LLM to tell the user to contact the maintainer rather than auto-resolving bugs or missing features itself. R is the primary focus and concrete starting point — including `pkghooks` as a reusable R package other maintainers can adopt — but this stage should not assume R-only scope is correct without examining it; `.onLoad()`/`.onAttach()` are a strong candidate implementation mechanism for R specifically regardless of how that broader scope question resolves.

## Context
This is the project's first design stage — no prior stages exist, and the
000-design-history retrospective on the (currently empty) git history was
deliberately skipped for now at the user's request, since there is no
meaningful development history yet to mine. The starting point is the
motivating idea captured in `idea.md`:

> A software developer wants their R package(s) to recognize when they are
> being driven by an LLM (e.g. an AI coding agent) rather than a human, so
> that when the LLM hits a bug or a missing feature, the package can push
> the LLM to tell the human user to contact the maintainer directly —
> instead of letting the LLM silently work around, monkey-patch, or paper
> over the problem itself.

One concrete lead already identified: Posit's `btw` R package, which
controls context supplied to LLM interfaces, might be extendable or
locally tweakable to help identify LLM-driven calling environments.

## Design Goals
- Survey and enumerate concrete, technically feasible signals an R
  function could use to infer that its caller is an LLM/AI-agent rather
  than a human running R interactively or via a script.
- Explicitly evaluate the `btw` package as an integration point: what
  context/hooks it exposes today, and whether/how it could be extended
  or locally patched to expose "this call originated from an LLM tool"
  information to arbitrary R packages.
- Compare candidate detection signals against this stage's constraints
  (see below) and narrow to the most promising 1-3 approaches, with
  documented trade-offs for each.
- Sketch, at a design level only, what a `pkghooks`-provided API would
  look like for a package author who wants to opt in to this behavior
  (e.g. a single wrapping function/hook they add around package
  functions) — without committing to implementation yet.
- Leave the actual "how the redirect message reaches the LLM/user"
  mechanism (condition system, return-value annotation, or something
  else) as an open question to be resolved either later in this stage's
  discussion or explicitly deferred to a future stage.
- Produce a decision-ready design document that a follow-up stage can
  turn directly into a `pkghooks` implementation plan.
- Explicitly question whether R-only, package-level scope is the right
  final boundary for this idea, versus a language-agnostic
  detection/messaging pattern for which an R package is just the first
  concrete implementation. Regardless of how that resolves, evaluate
  `.onLoad()`/`.onAttach()` as a strong R-specific mechanism, since they
  offer a natural, once-per-session, low-overhead point to run
  detection/messaging logic.
- Enumerate and evaluate the points during a calling session at which a
  redirect message could most usefully be issued (e.g. package load,
  first function call, every function call, error/failure time, help or
  documentation access), and identify which are practicable versus
  merely theoretical, rather than assuming a single obvious answer.

## Proposed Approach
- Treat this stage as research-and-design only: no package code is
  written yet. Output is a design document (this plan, refined through
  conversation, plus the stage's design-decisions.md at retrospective
  time) that catalogs and evaluates detection strategies.
- `pkghooks` is scoped as a general-purpose, reusable R package: other R
  package maintainers will add it as a dependency and call into it (or
  wrap their functions with it) to gain LLM-detection + redirect-message
  behavior for their own packages, rather than each maintainer having to
  reimplement detection logic themselves.
- Candidate detection signal categories to investigate and document
  (non-exhaustive starting list to expand during research):
  - Environment variables set by known AI coding tools/agents (e.g.
    Claude Code, Cursor, GitHub Copilot CLI, other MCP-based tools) when
    they spawn R subprocesses or R sessions.
  - Process/session introspection: parent process name, `Sys.getenv()`
    entries, `commandArgs()`, whether stdin/stdout are attached to a TTY
    vs. piped (interactive() alone is insufficient since agents may run
    R interactively-style).
  - Call-stack / caller-frame characteristics that might differ for
    programmatic/agentic invocation vs. a human typing at a console or
    sourcing a script.
  - Cooperative signals: packages or tools (like `btw`) that already
    aim to expose "an LLM is driving this session" context, which could
    be read directly rather than re-derived.
  - Heuristic/statistical signals (e.g. call patterns, timing) as a
    lower-confidence fallback category, to be weighed against the
    false-positive constraint.
- Evaluate every candidate against this stage's constraints:
  - **No false positives for humans** — a normal interactive R user or
    script must never trigger the redirect message; err toward
    under-detection over over-detection.
  - **Works without tool cooperation** — prefer signals detectable
    even when the calling AI tool wasn't built to announce itself,
    since not all current or future tools will integrate with `btw` or
    similar.
  - **Low performance overhead** — detection must be cheap enough to
    run on every hooked function call (favor one-time session-level
    checks, cached where possible, over per-call heavy introspection).
- Where `btw` cooperation is available, treat it as a high-confidence
  *complementary* signal layered on top of non-cooperative detection,
  not a replacement for it — since relying solely on tool cooperation
  would fail the "works without cooperation" constraint.
- Do not lock in R-package scope as a given. Investigate whether the
  core detection + messaging logic is better framed as a
  language-agnostic pattern (with R as the reference implementation)
  before committing `pkghooks` to being permanently R-specific. Note
  that this question is somewhat orthogonal to mechanism: `.onLoad()`/
  `.onAttach()` remain worth evaluating as *the* practical R hook point
  even if the broader design turns out to be language-agnostic, since
  R packages will need some concrete integration point regardless.
- Enumerate candidate session-level intervention points for issuing the
  redirect message, and evaluate each against the constraints above:
  - **Package load** (`.onLoad()`/`.onAttach()`) — runs once per
    session, cheap, guaranteed to fire before any use of the package;
    likely the most practicable baseline since it sidesteps the
    per-call overhead problem entirely. Best suited to a general,
    one-time "notice" rather than a bug-specific message, since at
    load time nothing is yet known about what the LLM will actually
    try to do.
  - **First function call** (lazy, on-first-use) — more targeted than
    load-time (only fires if the package is actually used) but adds
    per-function bookkeeping to avoid re-firing on every subsequent
    call; worth exploring as a refinement, not a starting point.
  - **Every function call** — highest coverage but likely violates the
    low-overhead constraint and would produce redundant/noisy
    repeated messages; treat as a candidate to explicitly rule out
    with reasoning, rather than skip silently.
  - **Error/failure time** — an actual R condition (error, or possibly
    warning) is raised, and the redirect message rides along with it.
    This matches half of idea.md's original framing ("if an LLM finds
    a bug") and is comparatively easy to hook into, since R's condition
    system already provides a natural interception point.
  - **Capability-gap time (no error thrown)** — a distinct and likely
    *more* important point than error/failure time: cases where a
    function or package simply doesn't do what's needed, but nothing
    actually errors — the call "succeeds" while under- or
    mis-delivering, or the required capability just doesn't exist yet.
    This matches the other half of idea.md's framing ("something my
    software can't do") and is the scenario where an LLM is most likely
    to silently work around the gap itself (e.g. hand-rolling a
    replacement, monkey-patching, reimplementing functionality) rather
    than surfacing it to the user — precisely the behavior this project
    wants to prevent. It is also the hardest to detect mechanically,
    since there is no condition to hook into; detecting it likely
    requires the package author to deliberately mark known limitations
    or unimplemented-but-requested capabilities, rather than relying on
    generic introspection. Error/failure time and capability-gap time
    should be treated as two independent intervention points, not
    variants of the same one.
  - **Help/documentation access** (e.g. `?fun`, `help()`) — a plausible
    additional touchpoint, since LLMs often probe documentation when
    exploring a package's capabilities; worth at least noting as a
    candidate even if not pursued further.
  - Working hypothesis to validate, not assume: this is likely not a
    two-point design (load-time vs. one "problem" point) but at least a
    three-point one — a load-time notice (via `.onLoad()`/
    `.onAttach()`) handling the general "you're talking to an LLM,
    here's how to redirect the user" disclaimer, plus two independent
    problem-time points: error/failure messaging (easy to hook via
    conditions) and capability-gap messaging (harder to detect, but
    likely the more important of the two given how directly it matches
    the original motivation of stopping LLMs from silently working
    around missing functionality).

## Open Questions
- What mechanism should `pkghooks` use to actually deliver the redirect
  message once LLM usage is detected (R condition/message/warning
  system, an annotated return value, a custom condition class the LLM
  is likely to surface verbatim, or something else)? Deliberately left
  open for this stage's research to inform.
- What does `btw` currently expose (if anything) that indicates its
  context is being read by an LLM tool, and is extending/patching it
  realistic without maintaining a fork long-term?
- How should `pkghooks` be integrated by adopting package authors —
  as an explicit wrapper function per hooked call, a package-level
  `onLoad` hook, an R6/S4 class, or another pattern — and how much of
  that design should be finalized in this stage vs. deferred to an
  implementation-focused follow-up stage?
- Should detection confidence be exposed as a spectrum (e.g.
  low/medium/high confidence signals) rather than a binary
  LLM-or-not classification, given the "no false positives for humans"
  constraint likely requires conservative, multi-signal corroboration?
- Are there existing prior art / R packages / cross-language precedents
  for LLM-vs-human caller detection worth reviewing before designing
  from scratch?
- Is R-only, package-level scope actually the right final boundary for
  `pkghooks`, or should this stage's output instead describe a
  language-agnostic pattern with R as merely the first implementation?
- Given load-time, error-time, and capability-gap-time likely form
  (at least) three distinct message points, should all three be in
  scope for the initial `pkghooks` design, or should this stage
  recommend shipping load-time and error-time messaging first (both
  mechanically straightforward) and treating capability-gap messaging
  as a later enhancement given its harder detection problem?
- How can capability-gap situations (function/package "succeeds" but
  doesn't meet the actual requirement, with no error raised) be
  identified at all? Is this necessarily something the package author
  must annotate/opt into on a per-function or per-feature basis (e.g.
  marking known limitations or requestable-but-unimplemented
  capabilities), or is there any mechanical/heuristic way to infer it?
- Beyond package load, first-call, every-call, error time,
  capability-gap time, and help/documentation access, are there other
  session touchpoints worth evaluating (e.g. session startup via
  `.Rprofile`, package installation time)?
