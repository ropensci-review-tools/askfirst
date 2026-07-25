---
created: 2026-07-24T11:24:40Z
agent: claude-sonnet-5
git_hash: 69af0c47a3f6fdd2820e3049062d8151bb9fc1ef
---

# Tasks: detect-llm-callers

This stage is research-and-design only — no `pkghooks` package code is
written. Every task below produces documented findings/analysis (in this
stage's working notes and ultimately its `design-decisions.md`), not
runnable code.

## T001-1: Survey non-cooperative environment/process signals
- [x] T001-1: Investigate and document what environment variables,
  process names, or other process-level artifacts known AI coding
  agents/tools (Opencode, Claude Code, Cursor, GitHub Copilot CLI, other
  MCP-based tools) set or expose when they spawn or drive an R
  session/subprocess. For each tool investigated, record: signal
  name/value, how reliably it's set, and whether it requires the tool
  to specifically support R.

## T001-2: Survey R session/process introspection signals
- [x] T001-2: Investigate and document R-native introspection signals
  that could distinguish an agentic caller from a human one, including
  parent process name, relevant `Sys.getenv()` entries, `commandArgs()`
  contents, and stdin/stdout TTY attachment. Explicitly note why
  `interactive()` alone is insufficient (agents may run R in an
  interactive-style session) and what it would take to distinguish the
  two cases reliably.

## T001-3: Survey call-stack / caller-frame signals
- [x] T001-3: Investigate whether call-stack or caller-frame
  characteristics (e.g. `sys.calls()`, `sys.function()`, frame depth,
  calling package/namespace) differ in any detectable way between
  programmatic/agentic invocation and a human typing at a console or
  sourcing a script. Document findings, including a clear statement if
  no reliable signal is found here.

## T001-4: Investigate `btw` as a cooperative detection signal
- [x] T001-4: Read the `btw` package's source/documentation to
  determine what context or hooks it currently exposes about the
  calling LLM/session. Document: (a) what's available today, (b)
  whether/how it could be extended or locally patched to expose an
  "this call originated from an LLM tool" signal usable by arbitrary R
  packages, and (c) the maintenance burden of relying on a fork or
  local patch versus what's usable unmodified.

## T001-5: Evaluate and rank candidate detection signals
- [x] T001-5: Using the findings from T001-1 through T001-4 (plus any
  additional heuristic/statistical signals identified along the way),
  evaluate every candidate detection signal against this stage's three
  constraints — no false positives for humans, works without tool
  cooperation, low performance overhead — and narrow to the 1-3 most
  promising approaches. Document the trade-offs of each and the
  reasoning for rejecting the rest.

## T001-6: Investigate message-delivery mechanisms
- [x] T001-6: Investigate and document candidate mechanisms for how
  `pkghooks` would actually deliver a redirect message to an LLM caller
  once detected — R's condition system (`message()`/`warning()`/a
  custom condition class), an annotated return value/attribute, or
  other approaches. For each, assess the likelihood an LLM tool would
  actually surface the message to the human user, and any risk of it
  being silently swallowed or auto-handled instead.

## T001-7: Evaluate session intervention points
- [x] T001-7: Evaluate each candidate intervention point identified in
  `plan.md` — package load (`.onLoad()`/`.onAttach()`), first function
  call, every function call, error/failure time, capability-gap time,
  and help/documentation access — against the stage's constraints.
  For "every function call," explicitly document the reasoning for
  ruling it out (or in) rather than skipping it silently. Conclude with
  a recommended multi-point design (validating or revising the
  plan's working hypothesis of load-time + error-time +
  capability-gap-time as three independent points).

## T001-8: Investigate capability-gap detection approaches
- [x] T001-8: Investigate how "capability-gap" situations — a function
  or package call succeeds but doesn't meet the actual requirement, and
  no error is raised — could be identified. Since there is no condition
  to hook into, evaluate approaches such as package-author-maintained
  annotations of known limitations, a registry of
  requestable-but-unimplemented capabilities, or any other mechanical/
  heuristic option. Document whether any approach avoids requiring
  per-function author opt-in, or whether opt-in is unavoidable.

## T001-9: Assess R-only vs. language-agnostic scope
- [x] T001-9: Assess whether `pkghooks`'s detection + messaging logic
  should be scoped as R-only or designed as a language-agnostic pattern
  with R as the first reference implementation. Document the reasoning
  and a recommendation, noting that `.onLoad()`/`.onAttach()` remain
  the practical R integration point either way.

## T001-10: Research prior art
- [x] T001-10: Research whether existing R packages, or precedents in
  other language ecosystems, already address LLM-vs-human caller
  detection or "redirect the AI agent to a human maintainer" messaging.
  Document anything relevant found, or explicitly note if none exists.

## T001-11: Sketch a design-level `pkghooks` opt-in API
- [x] T001-11: Sketch, at a design level only (no implementation), what
  a `pkghooks`-provided API would look like for a package author who
  wants to opt in to this behavior — e.g. an explicit wrapper function,
  a package-level `.onLoad()`/`.onAttach()` hook, an R6/S4 class, or
  another pattern. Cover how the author would register detection
  signals, message-delivery preferences, and (per T001-8) any
  capability-gap annotations.

## T001-12: Synthesize findings into a decision-ready design document
- [x] T001-12: Synthesize the outputs of T001-1 through T001-11 into a
  single coherent design document covering: the recommended detection
  approach(es), the recommended message-delivery mechanism, the
  recommended set of intervention points and how load-time/error-time/
  capability-gap-time messaging relate, the R-only vs. language-agnostic
  scope recommendation, the sketched `pkghooks` API, and a list of
  remaining open questions to carry into a follow-up implementation
  stage. This document is the primary input for this stage's
  `/designlens.retrospective`.
