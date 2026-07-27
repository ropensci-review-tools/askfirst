---
created: 2026-07-27T12:32:25Z
agent: claude-sonnet-5
git_hash: c1e68f9ef70c2c83ec853714377cbe6a543226c3
---

# Design Decisions: askfirst

## Current Architecture
`askfirst` is an R package (rooted at `bindings/r/` in this monorepo) that lets R
package maintainers detect when their functions are being called from an
LLM/AI coding agent rather than a human, and issue a structured signal
(`askfirst::<language>::<pkg>::<type>`) that AI assistants can recognise as
legitimate package metadata rather than a prompt injection. The signal
redirects the agent to tell the human user to contact the maintainer
directly — instead of the agent silently working around a bug or missing
capability. Eight design stages are complete. Stage 009 made
`askfirst_check_scenarios()` self-initializing by auto-loading the target
package's namespace when no `askfirst_init()` registration exists, so the
function works from any R session without an explicit `init()` call first.
The development vignette (`askfirst-development.Rmd`) now carries a
concrete, realistic demo with a working `tokenpkg_parse_version()` function
and version-parsing scenarios, replacing the abstract placeholder content
from earlier stages. Stage 001 produced
research-only findings (no code). Stage 002 produced `agent-detect-spec/`,
a vendored, upstream-synced copy of `vercel/detect-agent`'s detection data,
plus a confidence-tiering/intervention-point design that was ultimately
folded into stage 002's own `design.md`/`design-decisions.md` as documented
rationale rather than shipped as standalone files. Stage 003 built the
actual `askfirst` R package: `askfirst_init()` (session-cached detection,
load-time notice, error-time wrapping) and `askfirst_capability_gap()`
(capability-gap-time), backed by a `testthat` suite and a clean
`R CMD check`, with a synced copy of the vendored data at
`bindings/r/inst/agent-detect-spec/`. Stage 004 added
`askfirst_check_scenarios()`, an *agent-invoked* mechanism (the LLM calls
it on its own initiative, rather than `askfirst` triggering it) for gaps
the author hasn't anticipated well enough to instrument via
`askfirst_capability_gap()`. Stage 005 renamed the project from
`pkghooks` to `askfirst` throughout the repo's current contents (package,
functions, condition classes, docs, CI) — the R package itself is
otherwise unchanged by that stage. Stage 006 replaced the manual QA
checklist (`bindings/r/MANUAL_TESTING.md`) with two real R vignettes —
one walking `askfirst` maintainers through building a token test package
and verifying all four intervention points against real Claude Code and
opencode sessions, one giving adopting-package maintainers a procedural
guide to the exported API — introducing the project's first vignette
infrastructure (`knitr`/`rmarkdown`), and, as an in-scope side fix, a
long-broken `working-directory: r` path in the CI check job that predated
the `bindings/r/` relocation. Stage 007 revised the messaging system to
replace the prompt-injection-vulnerable second-person condition format with
a structured `askfirst::<language>::<pkg>::<type>` prefix, introduced
pre-configured agent-tool hooks (SessionStart and PostToolUse) at a shared
`agent-hooks/` directory, and created a binding-agnostic installation script
at `tools/install-agent-hooks.sh`.

## Key Decisions

### Detection: vendor upstream data directly, no independent schema
**Outcome:** `agent-detect-spec/vendor/agents.json` and
`agents.schema.json` are unmodified copies of `vercel/detect-agent`'s
files, consumed as-is via a weekly, PR-gated GitHub Action sync. No
`askfirst`-specific detection schema or data file exists.
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
rejected); designing an independent `askfirst`-specific detection schema
(reversed mid-stage 002 in favor of direct vendoring).
**Stages:** 001, 002, 003

### R packaging: vendored data duplicated into bindings/r/inst/, synced automatically
**Outcome:** `bindings/r/inst/agent-detect-spec/` holds a committed, byte-identical
copy of root `agent-detect-spec/vendor/`, kept in sync by extending the
same GitHub Action plus a CI drift-check script.
**Rationale:** R packages must carry their own runtime data under `inst/`
to be installable independently of this monorepo (CRAN, a release tarball,
or a standalone checkout of `bindings/r/`); the repo-root location alone can't serve
that purpose once the package is distributed on its own.
**Roads not taken:** Reading the repo-root path directly at runtime
(breaks once the package is installed outside this exact monorepo
checkout); collapsing to a single `bindings/r/inst/`-only location (would lose the
language-agnostic, R-independent home for the data that future non-R
implementations are meant to consume).
**Stages:** 003

### Confidence: a closed, language-neutral tier enum, documented as design rationale
**Outcome:** A closed `high`/`medium`/`low`/`cooperative` enum, with
mapping rules from a raw detection outcome (vendored-data match, plus
optional TTY/process-ancestry corroboration) onto a tier. `cooperative` is
reserved for a future tool-initiated signal, currently unused. Documented
in `specs/002-design-agnostic-spec/design.md` (T002-4) and
`design-decisions.md`, not as a standalone file in `agent-detect-spec/`.
**Rationale:** Vendored detection data carries no confidence concept of
its own; this layer is `askfirst`'s own contribution on top of it. A
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
**Stages:** 001, 002, 003

### Attribution: global detection cache, explicit per-package naming in every hook
**Outcome:** `askfirst_init()` computes the session's confidence/detection
result once, cached and shared across every adopting package. Every hook
(the load-time notice, `on_error` wrapping, and
`askfirst_capability_gap(pkg, message)`) explicitly takes a `pkg` argument,
attached as a real field on the signalled condition — not just interpolated
into message text.
**Rationale:** Avoids redundant re-detection while still producing
attributable messages when multiple packages have adopted `askfirst` in
one session.
**Roads not taken:** Auto-detecting the calling package via call-stack
introspection instead of requiring an explicit `pkg` argument — rejected in
favor of explicitness; `askfirst_capability_gap()`'s stage-001 sketch (no `pkg`
argument) was revised accordingly.
**Stages:** 003, 004

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
**Stages:** 001, 002, 003

### Scenario-check: a fourth, agent-invoked intervention point, with namespace auto-init
**Outcome:** `askfirst_check_scenarios(pkg)`, a new exported function, is
called by the LLM itself at any point in a session — not triggered by
`askfirst` detecting anything. It signals a non-fatal
`askfirst_scenario_check` condition (at `"high"`/`"medium"` confidence)
carrying author-supplied "plausible extension scenario" descriptions
(registered via a new `askfirst_init(..., scenarios = ...)` parameter)
plus a reminder to ask the human before implementing a workaround. At
`"low"` confidence it returns the scenario list plainly, with no nudge.
The existing load-time notice always folds in a generic instruction to
call this function, regardless of whether any scenarios were registered.
In stage 009, the function was made self-initializing: if the target
package hasn't called `askfirst_init()` in the current session, its
namespace is automatically loaded via `requireNamespace()` to trigger the
init call from the package's `.onLoad()`. If the package does not adopt
askfirst, an informative error is raised.
**Rationale:** Targets capability gaps the author hasn't anticipated well
enough to instrument inline via `askfirst_capability_gap()` — cases where the
LLM writes new code entirely outside the package to achieve a result, with
nothing ever erroring and no execution-time event `askfirst` could hook
into. Mechanical detection of this (monkey-patching/namespace-manipulation
calls) was investigated and rejected as both rare and, in the common
case, invisible to the package at runtime. With no mechanical trigger
available, an agent-invoked tool — discoverable via the load-time notice —
is the only viable delivery path. The namespace auto-init (stage 009)
removes the need for an explicit `init()` call in each fresh process.
**Roads not taken:** Mechanical detection of in-progress workaround
behavior (`assignInNamespace()`, `trace()`, etc.) — rejected outright, not
merely deprioritized. Broadening the existing error-time message instead
of adding a new mechanism — rejected, since the target case is
error-free by definition. Halting severity (like `capability_gap_time`) —
rejected in favor of non-fatal, given the heuristic/self-assessed nature
of this check. Empty-scenario fallback instead of namespace loading
(rejected in stage 009 — the real author-supplied scenarios must be used,
not empty defaults).
**Stages:** 004, 009

### Error-time mechanism: options(error = ...), not globalCallingHandlers()
**Outcome:** `askfirst_init(..., on_error = TRUE)` installs error-time
wrapping via `options(error = ...)` (preserving and chaining to any
pre-existing value), not `globalCallingHandlers()`.
**Rationale:** Discovered via an actual `R CMD INSTALL` failure:
`globalCallingHandlers()` cannot be called from inside `.onLoad()`/
`.onAttach()`, because R's own `loadNamespace()`/`attachNamespace()` wrap
those hooks in a handler context of their own, and `globalCallingHandlers()`
refuses to install from within any active handler context.
`options(error = ...)` has no such restriction. Both mechanisms share the
same delivery limitation (only fire for errors that propagate uncaught to
the top level), so switching cost nothing.
**Roads not taken:** `globalCallingHandlers()` — planned initially,
rejected only after empirical failure during implementation, not by
up-front reasoning.
**Stages:** 003

### Scope: R-only package, vendored data kept separate, design rationale kept in specs/
**Outcome:** `askfirst` ships and is branded as an R-only package.
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
structuring choice for `askfirst`'s internals, not a commitment to
building beyond R now. A standalone repo for `agent-detect-spec/` from day
one — deferred until a second, genuinely independent language
implementation actually exists. Treating the confidence/intervention
models as part of that same portable-directory contract — reversed
post-retrospective, once it was recognized they lacked any enforcement
mechanism `vendor/agents.json` actually has.
**Stages:** 001, 002, 003

### Naming: askfirst, accepting an npm conflict
**Outcome:** The project, R package, and every `pkghooks_*`-prefixed
symbol were renamed to `askfirst`/`askfirst_*`. Historical stage documents
(`specs/001-004`) keep referring to `pkghooks`, unchanged; only the root
`specs/design-decisions.md` (continuously revised "Current Architecture")
and the R package's own current-state content were updated.
**Rationale:** `askahuman` (the initially obvious choice) was ruled out
due to an existing, unrelated `github.com/askahuman` project. `askfirst`
was confirmed unclaimed on GitHub/CRAN/PyPI but already taken on npm;
proceeding anyway was a deliberate choice, since npm has heavy
name-squatting for short, generic-sounding words and a scoped/suffixed
variant is normal practice once a JS binding actually exists.
**Roads not taken:** Searching further for a name simultaneously
available across every registry — rejected as a much harder bar to clear
than the actual near-term need; also renaming the external GitHub
repository and local working directory in the same stage — deferred to
the user as a separate, later step.
**Stages:** 005

### Documentation: real vignettes over plain markdown, CI fixed opportunistically
**Outcome:** `bindings/r/MANUAL_TESTING.md` was replaced by two standard R
vignettes (`bindings/r/vignettes/askfirst-development.Rmd` and
`using-askfirst.Rmd`), requiring `knitr`/`rmarkdown` in `Suggests` and
`VignetteBuilder: knitr`. `.github/workflows/r-cmd-check.yml`'s
`r-cmd-check` job — found still using `working-directory: r`, a path left
over from before the package's move to `bindings/r` in an earlier stage —
was regenerated from `usethis::use_github_action("check-standard")`'s
current template and corrected to `working-directory: bindings/r`
throughout, alongside the vignette changes.
**Rationale:** Vignettes are discoverable via
`vignette(package = "askfirst")` and any future pkgdown site, unlike a
plain markdown file only visible by browsing the repo. Fixing the CI path
in the same stage — rather than deferring it — avoided adding new
vignette-build coverage on top of a check job that was already pointed at
the wrong directory.
**Roads not taken:** Keeping the replacement documents as plain markdown
(rejected in favor of discoverability); deferring the CI path fix to a
separate stage (rejected, since it would have left the new vignette
infrastructure unverified in CI in the interim).
**Stages:** 006

### Messaging format: structured prefix over second-person embedded instructions
**Outcome:** All askfirst condition signals now carry a
`askfirst::<language>::<pkg>::<type>` prefix line (language, adopting package
name, signal type) followed by the message body and a `See: <url>` line.
Agent hooks (SessionStart and PostToolUse) pre-load context about this
format so AI assistants recognise it as legitimate metadata.
`tools/install-agent-hooks.sh` is a shared shell script for installing the
hooks; the R function `askfirst_install_agent_hooks()` is a thin wrapper
around it.
**Rationale:** The previous second-person format ("If you are an AI coding
agent...") was interpreted as a prompt injection by AI assistants, causing
outright refusal. The structured prefix lets the tool's system context
identify it as a known, safe signal, and the shared shell script avoids
duplicating installation logic across future language bindings.
**Roads not taken:** Keeping the second-person embedded-instruction format
(actively counterproductive — triggers prompt-injection guardrails);
implementing hook installation as R-only logic (rejected mid-stage in favor
of a shared shell script callable from any binding).
**Stages:** 007

### Demo content: vignette-scoped, realistic function replacing abstract placeholders
**Outcome:** The `askfirst-development.Rmd` vignette's tokenpkg demo was
updated with a concrete `tokenpkg_parse_version()` function (parsing
dot-separated version strings), version-parsing capability-gap scenarios,
a real input-validation error instead of a synthetic `stop()`, and
updated verification descriptions — all confined to the vignette file
itself.
**Rationale:** The previous abstract placeholder scenarios and messages
tested only whether text appeared, not whether askfirst's signals guide
an agent toward appropriate behaviour. The concrete version-parsing
function and its plausible limitation (no pre-release suffix support)
give the agent meaningful context to act on. Keeping all changes within
the vignette avoids coupling the demo fixture to the real package source
code.
**Roads not taken:** Modifying the real `bindings/r/R/tokenpkg.R` source file
instead of keeping changes vignette-only — rejected to avoid a
maintenance dependency between the demo fixture and the production code
it is meant to test against.
**Stages:** 008

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
contract, and folded back into the stage's own design documents. Stage 003
built the actual `askfirst` R package at `bindings/r/`, consuming
`agent-detect-spec/manifest.json` (via a synced copy at `bindings/r/inst/`) for
detection data and stage 002's `design.md`/`design-decisions.md` for the
confidence and messaging reasoning. Implementation surfaced one real
correction to the plan: `globalCallingHandlers()`, the originally-planned
error-time mechanism, turned out to be unusable from a package's own load
hooks, and was replaced with `options(error = ...)` — a discovery made by
testing against a real package install, not by up-front design review. Stage 004 added a fourth intervention point, `askfirst_check_scenarios()`,
conceptually different from the first three: it is *agent-invoked* rather
than *system-triggered*, since investigation this stage confirmed there is
no reliable execution-time signal for "the LLM is about to write code that
duplicates or extends the package externally" — that code typically never
touches the package at all. The project now has a working, tested R
implementation covering four intervention points across two trigger
categories; process-ancestry corroboration, the `cooperative` confidence
tier, `btw` integration, and formalizing the agent-invoked category in
stage 002's language-neutral model remain deliberately unbuilt/undecided
extension points, and no non-R implementation exists yet. Stage 005
renamed the project to `askfirst`, confirming — by touching every file in
`bindings/r/` at once — that the package structure established across
stages 003–004 tolerates a full rename cleanly (53 tests and a clean
`R CMD check` both still pass unchanged in substance, only in name). Stage
006 shifted focus from the package's runtime behavior to its
documentation and CI: the ad hoc `MANUAL_TESTING.md` checklist became two
real vignettes, giving the project its first vignette-build
infrastructure, and implementation surfaced two corrections along the way
— the task breakdown's assumption that `askfirst_install_error_handler()`
is a directly-callable integration point turned out to be wrong (it is
internal, invoked automatically by `askfirst_init()`'s `on_error`
argument), and the CI check job's `working-directory` still pointed at
the pre-`bindings/r/`-relocation path from before stage 003/005, both
found and fixed by reading the actual source and workflow file rather
than by relying on the stage's own plan. Stage 007 addressed a fundamental
problem surfaced by `transcript.md`: AI assistants interpreted askfirst's
second-person embedded instructions as prompt injection and refused to
engage. The fix had two parts: (a) a structured
`askfirst::<language>::<pkg>::<type>` prefix on every condition signal that
AI assistants can be taught to recognise as legitimate metadata, and (b)
agent-tool hooks (SessionStart and PostToolUse for Claude Code and
opencode) that pre-load context about the format, installed via a shared
shell script at `tools/install-agent-hooks.sh` with a thin R wrapper.
The hook scripts live at a root-level `agent-hooks/` directory, shared
across all language bindings via symlinks, following the same
root-level-plus-symlink pattern established for the vendored detection data
in stage 003. Stage 008 turned the vignette's tokenpkg demo from an
abstract placeholder with no useful function into a concrete, realistic
development exercise: a working `tokenpkg_parse_version()` function, a
plausible capability gap (no pre-release suffix support), a real
input-validation error, and updated verification descriptions — all
confined to the vignette file rather than touching real package sources,
consistent with the demo-as-fixture pattern established in stage 006. The
stage had no design-level uncertainties, no open questions, and no
deferred items; it was a pure enhancement of demo content only.
Stage 009 addressed a practical limitation of the agent-invoked scenario check
introduced in stage 004: `askfirst_check_scenarios()` failed when called from a
fresh `Rscript` process where `askfirst_init()` hadn't been called yet. The fix
auto-loaded the target package's namespace (`requireNamespace()`) when no
registration was found, triggering the package's `.onLoad()` — where
`askfirst_init()` is normally called — to register scenarios naturally. An
internal helper (`askfirst_try_load_namespace()`) was introduced for testability
(since base functions cannot be mocked by testthat), and a pre-existing
environment-dependent test fragility in `test-init.R` (the medium-confidence test
relied on the CI runner lacking a TTY) was fixed by setting confidence explicitly.

## Important Roads Not Taken
**Detection:**
- Call-stack/frame introspection — no usable signal exists at the R
  language level; identical shape for human and agent callers.
- `interactive()` as a standalone detector — true for both a human console
  session and an agent driving a persistent interactive session.
- TTY attachment or `commandArgs()` as standalone detectors — both
  false-positive on ordinary non-interactive human automation (CI,
  scripted runs).
- An independent, `askfirst`-specific detection schema — designed
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
- `globalCallingHandlers()` for error-time wrapping — planned, then
  rejected after an actual `R CMD INSTALL` failure showed it cannot be
  called from within `.onLoad()`/`.onAttach()`; replaced with
  `options(error = ...)`, which shares the same delivery limitation
  without the installation restriction.
- Auto-detecting the calling package via call-stack introspection instead
  of an explicit `pkg` argument on every hook — rejected in favor of
  explicit attribution, so messages remain correct when multiple packages
  adopt `askfirst` in one session.
- Mechanical detection of in-progress workaround behavior (monkey-patching,
  namespace manipulation targeting an adopting package) as a trigger for a
  new capability-gap-style mechanism — rejected outright (stage 004): such
  calls are rare, and the code an LLM writes to extend a package's
  functionality typically never touches the package at all, so no
  execution-time signal exists to detect.
- Halting severity for the new agent-invoked scenario-check mechanism —
  rejected in favor of non-fatal, since heuristic/self-assessed triggers
  carry more false-positive risk than an author-confirmed capability gap.

**Scope:**
- Building a language-agnostic implementation now, rather than R-only with
  portable internals — still deferred as premature; only the vendored
  detection data is language-agnostic so far, not any actual code.
- Shipping the confidence-tiering and intervention-point models as
  standalone files under `agent-detect-spec/` — reversed post-retrospective
  once it was recognized that, unlike the vendored data, nothing in the
  repo actually reads or enforces them; folded back into `specs/`'s design
  documents instead.
- Reading `agent-detect-spec/vendor/` directly from R at its repo-root
  location, rather than vendoring a copy into `bindings/r/inst/` — would break once
  the R package is installed or distributed independently of this
  monorepo.

**Messaging format:**
- Second-person embedded-instruction format ("If you are an AI coding
  agent...") — retained through stages 001–006, then replaced in stage 007
  after real-world testing showed AI assistants interpret it as prompt
  injection and refuse to follow it. The structured prefix and pre-loaded
  hook context approach was adopted as the replacement.

**Scenario check:**
- Empty-scenario fallback for unregistered packages — rejected in stage 009
  in favor of namespace auto-loading, so the real author-supplied scenarios
  are always used rather than silently returning empty data.
