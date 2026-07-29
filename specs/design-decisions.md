---
created: 2026-07-28T09:26:31Z
agent: claude-sonnet-5
git_hash: e87e2de04bde998dea889cbf8cfdb729ba9970d3
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
capability. Twenty design stages are complete. Stage 018 removed three
pieces of content that stage 017 had hand-duplicated across bash and JS —
the `<askfirst-context>` prose, the escalation-reminder wording, and the
`askfirst_state_dir()` mangling function (the latter also duplicated
within Claude Code's own `post_tool_use.sh`/`user_prompt_submit.sh`) —
by introducing three canonical source files under `agent-hooks/`
(`askfirst-context.txt`, `askfirst-reminder-messages.txt` with neutral
`{{PKG}}`/`{{COUNT}}` placeholders, `askfirst-state-dir.sh`), spliced into
the per-tool canonical files by a new earlier pass in
`agent-hooks/generate-install-hooks.sh`, ahead of its existing per-tool-
file-into-installer splicing. Diffing the two existing context-prose
copies before treating either as canonical found real, intentional stage-
017 drift (the JS version had been reworded to match opencode's own
throw-based mechanism); reconciled with wording accurate for both tools'
actual mechanisms ("enforcement hook ... stop ... from succeeding" /
"a subsequent failed tool call"). The JS port of the mangling function
stays a manually-maintained translation, not a literal shared source
(bash/JS can't execute the same function body), verified instead against
a shared fixture (`askfirst-state-dir-fixture.txt`) consumed by both the R
and JS test suites. The same stage merged the repo-root `tools/` directory
(which held exactly the installer and generator, both existing solely to
support `agent-hooks/`) into `agent-hooks/` itself, removing a redundant
second top-level symlink from the R package's `inst/` as a direct
consequence. A rename of `agent-hooks/`/the public "hooks" R API to
something mechanism-neutral (given opencode's delivery format is called a
"plugin") was considered and explicitly deferred, not pursued. Stage 017
replaced the
confirmed-dead `agent-hooks/opencode/*.sh` shell scripts (stage 016's finding)
with a real, dependency-free JS plugin (`agent-hooks/opencode/askfirst-plugin.js`)
built against opencode's actual `@opencode-ai/plugin` Hooks API, achieving full
parity with Claude Code's mechanism: `experimental.chat.system.transform` for
context injection, `tool.execute.after` for the notice-log/escalation
annotations, `tool.execute.before` (throwing to abort a call) for the blocking
stop-and-ask gate, and `"chat.message"` for clearing the pending sentinel on a
new turn. Every hook point was verified against a real, authenticated opencode
session rather than assumed from documentation: the model correctly recited
the injected context verbatim; a real `edit` tool call correctly triggered the
escalation counter; a `pending/` sentinel injected mid-turn genuinely rejected
the next tool call via the thrown error, resolving in the affirmative whether
`tool.execute.before`'s abort covers every tool call unconditionally; and
`"chat.message"` was confirmed to fire exactly once per new user turn, before
any tool calls. The plugin is installed via `.opencode/plugins/` (auto-discovered,
no `opencode.json` registration needed), replacing the prior
`register_hooks_opencode()`/`.opencode/settings.json` write entirely. The
legacy shell scripts were deleted outright once the plugin was verified, per
explicit no-fallback-kept decision. `agent-hooks/generate-install-hooks.sh` gained a
fourth spliced source (the plugin file, alongside the three Claude Code shell
scripts, no longer byte-identical to opencode's file by design), and the
hook-version marker convention was extended to recognize a `// askfirst-hook-version:
<N>` JS-comment form alongside the `#`-style shell-comment form, with a new
per-tool `marker_file` field replacing a hardcoded `session_start.sh` filename
assumption. `hook_version` moved to 4 across all tools' marker files (Claude
Code's markers were bumped too, despite no content change, since the version
number is one shared counter). Stage 016 was triggered by a
field trial (run via a sibling test harness, not this repo) showing that the
hard `stop-and-ask` gate for capability gaps the package author hasn't
anticipated is only reachable if the agent voluntarily calls
`askfirst_check_scenarios()` — an agent that never makes that call gets no
reinforcement past the existing one-shot notice log. A new, non-blocking
`PostToolUse` escalation now tracks, per package, whether a `notice` fired
without a following scenario-check call, and appends an escalating reminder
(single-line, then a firmer "REPEATED" wording after three occurrences) to
every subsequent file-editing tool call until the check happens or the
session ends — deliberately untargeted (fires on any edit, not scoped to
files referencing the flagged package) and never blocking. The same stage
relocated all askfirst runtime state — the `log`/`pending/` files from stage
015, and the new escalation marker — out of the project's working tree
entirely, into a session-scoped path under a fixed tmp root
(`${TMPDIR:-/tmp}/askfirst/<mangled-project-path>/`), computed identically
and independently by the R process (from `getwd()`) and each hook script
(from its payload's `cwd` field); this supersedes stage 015's deferred
`.gitignore` item rather than completing it. Investigating opencode's real
plugin SDK for this stage's opencode-side work found its actual mechanism is
a JS/TS module registered via `opencode.json`'s `plugin` array, executed
in-process — not a shell-script/stdin-JSON convention at all — meaning the
existing `agent-hooks/opencode/*.sh` scripts (since stages 014/015) are very
likely never invoked by real opencode; this was documented precisely rather
than fixed, since building a real plugin is a substantially larger,
separate undertaking flagged for a future stage. `hook_version` moved to 3
to reflect these changes. Stage 015 addressed a second
field report describing signals that reach an agent's output but still get
missed — buried by scrolling/habituation, stripped by the agent's own ad hoc
`grep -v askfirst...` filtering, or acted on too late — combined with the
original scope of stderr being silently discarded outright by
`Rscript ... 2>/dev/null`. The structured prefix now folds directive severity
into its own last segment (`askfirst::<language>::<pkg>::<directive>`, i.e.
`stop-and-ask` or `notice`, as the literal first line), with a `type:` line
carrying the finer-grained signal class immediately after; the prose
delimiter lines from stage 014 are replaced by compact
`<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>` tokens, with the imperative
consequence wording itself unchanged. Every `stop-and-ask` signal now also
writes its full message to stdout (in addition to the existing stderr
delivery) and to a persistent, per-`{pkg}-{type}` sentinel file under
`.askfirst/pending/`; a reworked `post_tool_use.sh` actively blocks every
subsequent tool call (Claude Code's exit-code-2 convention) while any
sentinel remains, and a new `user_prompt_submit.sh` hook clears
`.askfirst/pending/` at the start of each new user turn. `notice` signals
keep a lighter-weight one-shot `.askfirst/log`, and a new
`ASKFIRST_SILENCE_NOTICE` environment variable lets a package or user
suppress notice-level logging (never `stop-and-ask`) without resorting to
output filtering. `hook_version` moved to 2 across `agent-hooks/manifest.json`
and the canonical hook scripts to account for the new third hook file and the
`post_tool_use.sh` behavioral change. Stage 014 reopened stage
007/011's neutral-message-text trust boundary for `directive: stop-and-ask`
signals specifically: `askfirst_signal()` now embeds a fixed, imperative
hard-stop block directly in message text — start/end delimiter lines
bounding a first-person-to-agent consequence statement, the existing
structured prefix/directive line pair, and the package-authored body —
unconditionally, regardless of whether `agent-hooks/` is installed, after a
field report showed even the hooks-reinforced version failed to stop a
workaround. `askfirst_notice` instead gained a short, non-halting
forward-reference sentence. The same stage added `askfirst_hooks_status()`,
a check (backed by a hand-maintained `agent-hooks/manifest.json` and a
`# askfirst-hook-version:` marker in the canonical hook scripts) that
detects missing/stale hooks and prints a one-time, human-directed (not
agent-directed) nudge from `askfirst_init()`, independent of AI-agent
confidence. Stage 013 replaced the
vague "the capability may belong in `{pkg}` itself" framing in the
load-time notice and the scenario-check message with a concrete, attributed
invitation naming `askfirst` explicitly, backed by two new optional
`askfirst_init()` fields — `contribute_how` (free text on how to
contribute) and `contribute_url` (a single URL) — built via one shared
internal helper so the two messages can't drift apart. Every sentence
names its addressee explicitly rather than using an unqualified "you",
since the calling agent (not the human the invitation is for) is the
direct reader of the message text; a misread "you" could otherwise be
taken as inviting the agent itself to go open an upstream PR unsupervised.
`askfirst_capability_gap()` and `error_redirect` are unchanged. Stage 012 hardened this
mechanism further after a field report showed an agent reading the
scenario-check advisory and offering a workaround anyway:
`askfirst_check_scenarios()` now halts at high confidence (matching
`askfirst_capability_gap()`) instead of merely informing, the `directive:`
prefix line differentiates `stop-and-ask` from `notice` by actual severity
rather than one uniform value, `agent-hooks/` SessionStart guidance no
longer frames a workaround as any kind of selectable menu option on a
`stop-and-ask` signal, and a previously silent bug was fixed where the
shipped R-package installer had never received stage 011's hook-text fixes
at all — a dev-time generation script now regenerates the installer's
embedded hook content from the canonical `agent-hooks/` source, with a
regression test guarding against future drift. Stage 009 made
`askfirst_check_scenarios()` self-initializing by auto-loading the target
package's namespace when no `askfirst_init()` registration exists, so the
function works from any R session without an explicit `init()` call first.
Stage 010 restricted all four agent-facing signal points to fire only at
`"high"` confidence (known agent detected), suppressing them during
medium-confidence sessions (CI, testing, package installation) while
preserving the medium detection logic intact for future refinement.
Stage 011 resolved a field-reported failure where an agent under-executed
the "ask before workaround" rule because a task didn't literally match a
registered example scenario: the load-time notice no longer repeats the
scenario bullet list (now shown exactly once, at
`askfirst_check_scenarios()` time, worded as explicitly non-exhaustive),
every signalled message's structured prefix now carries an additional
`directive: ask-before-proceeding` line, and the `agent-hooks/`
SessionStart context was extended to instruct agents to treat scenario
lists as illustrative rather than a matching gate and to present the
ask-the-user option as recommended rather than a neutral, co-equal choice.
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
at `agent-hooks/install-agent-hooks.sh`. Stage 019 added a second,
confidence-gated agent-directed condition (`askfirst_hooks_nudge`) that
fires alongside stage 014's unchanged human-directed console nudge when
hooks are missing or stale, and — anticipating a second language binding —
extracted the fixed condition text `conditions.R` had hardcoded (the hard-
stop marker delimiters, stop-consequence text, notice-prime text, and the
new hooks-nudge text) into a new top-level `agent-content/` directory,
synced into `bindings/r/inst/agent-content/` the same way
`agent-detect-spec/vendor/` already is, and read by `conditions.R` at
runtime via `system.file()`. `agent-hooks/askfirst-context.txt`'s prose,
which separately described the same marker tokens, now derives their
literal values from this same canonical source via
`generate-install-hooks.sh`, closing the one remaining place those values
could drift apart. A new local `.githooks/pre-commit` hook (opt-in via
`git config core.hooksPath .githooks`) and a parallel CI step guard against
committing a drifted `agent-content/` copy. Stage 020 fixed a real
Windows-only `rcmdcheck()` failure in the session-state-directory mangling
scheme (a drive-letter colon survived into a directory-name segment,
illegal on Windows), ported the fix identically to the R, bash, and JS
implementations, and adopted `fs::path()` for path construction throughout
`bindings/r/` in place of `file.path()`. Stage 021 gave `askfirst_hooks_nudge`
its own `TELL-USER`/`END-TELL-USER`-bounded message shape, distinct from
both the hard-stop and plain-notice shapes, and made `askfirst_signal()`
fold a pending nudge into the next same-session `stop-and-ask` halt as one
message, so a must-relay-to-human instruction isn't dropped when it
co-occurs with a higher-severity halt.

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

### Confidence: a closed, language-neutral tier enum, signallers gated on high only
**Outcome:** A closed `high`/`medium`/`low`/`cooperative` enum, with
mapping rules from a raw detection outcome (vendored-data match, plus
optional TTY/process-ancestry corroboration) onto a tier. `cooperative` is
reserved for a future tool-initiated signal, currently unused. All four
agent-facing signal points — load-time notice, error handler, scenario
check, and capability gap — fire only at `"high"` confidence. The
`"medium"` tier (no TTY, no known agent) no longer triggers any signal,
but its detection logic is preserved for future opt-in mechanisms.
Documented in `specs/002-design-agnostic-spec/design.md` (T002-4) and
`design-decisions.md`, not as a standalone file in `agent-detect-spec/`.
**Rationale:** Vendored detection data carries no confidence concept of
its own; this layer is `askfirst`'s own contribution on top of it. A
closed enum is simpler for every consuming implementation to reason about,
and extending it later is additive rather than breaking. Originally
shipped as `agent-detect-spec/confidence-model.md`; moved to the stage's
own design documents once it was recognized that unenforced prose in a
"spec" directory implied a guarantee (consistency across implementations)
it couldn't actually provide. Stage 010 resolved the medium-tier boundary
open question: medium confidence produced false positives in CI, testing,
and package installation, so all signals were restricted to high confidence
while preserving the medium infrastructure.
**Roads not taken:** An open/extensible tier set (deferred as unnecessary
complexity for v1); keeping it as a standalone file under
`agent-detect-spec/` (reversed post-retrospective — see Scope decision
below); medium-confidence signalling (reversed in stage 010 due to false
positives in non-agent non-interactive contexts).
**Stages:** 001, 002, 003, 010

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

### Messaging format: structured prefix over second-person embedded instructions, trust-boundary split preserved and strengthened
**Outcome:** All askfirst condition signals now carry a
`askfirst::<language>::<pkg>::<type>` prefix line (language, adopting package
name, signal type), a `directive:` line, the message body, and a
`See: <url>` line. The `directive:` value differentiates severity
(`stop-and-ask` for `capability_gap`, `scenario_check`, and
`error_redirect`; `notice` only for the load-time notice) as of stage 012,
replacing the single uniform `ask-before-proceeding` value stage 011
introduced for all four signal types. `askfirst_check_scenarios()` now
halts (`call_stop = TRUE`) at high confidence rather than merely informing,
matching `askfirst_capability_gap()`'s existing halting behavior. Agent
hooks (SessionStart and PostToolUse) pre-load context about this format so
AI assistants recognise it as legitimate metadata; stage 011 extended the
SessionStart context with explicit instruction to treat scenario/example
lists as non-exhaustive, and stage 012 replaced stage 011's "mark ask-first
as recommended" mitigation with a stronger rule: on a `stop-and-ask`
signal, no workaround may be presented as an option — recommended or
otherwise — until the user has answered the upstream question.
`agent-hooks/install-agent-hooks.sh` is a shared shell script for installing the
hooks; the R function `askfirst_install_agent_hooks()` is a thin wrapper
around it. Its embedded hook content is now regenerated from the canonical
`agent-hooks/claude/*.sh` source via `agent-hooks/generate-install-hooks.sh`
(stage 012), after investigation found the shipped installer had silently
never received stage 011's fixes at all; a regression test now compares
the two directly. The scenario bullet list previously duplicated (with
inconsistent wording) between the load-time notice and the on-demand
scenario-check message now appears only in the latter, worded as
explicitly non-exhaustive. Stage 013 replaced the load-time notice's and
scenario-check message's vague closing clause ("...the capability may
belong in `{pkg}` itself" / "...should be added to `{pkg}` itself") with a
concrete, attributed invitation built by a shared internal helper
(`askfirst_build_contribute_line()`), always naming `askfirst` by name and
optionally including maintainer-supplied `contribute_how`/`contribute_url`
text (two new optional `askfirst_init()` fields). `askfirst_capability_gap()`
and `error_redirect` are unchanged. Stage 014 reopened the neutral-message-
text side of this trust boundary, but only for `directive: stop-and-ask`
signals: the message body itself now carries a fixed, imperative hard-stop
block — `----- ASKFIRST AGENT STOP: ... -----` / a first-person-to-agent
consequence statement / the existing prefix-and-directive lines / the
package-authored body / `----- ASKFIRST AGENT: RESUME NORMAL PROCESSING
-----` / the `See:` line — emitted unconditionally, whether or not
`agent-hooks/` is installed or current. `askfirst_notice` instead gained a
short, non-halting forward-reference sentence naming the same markers. The
fixed text interpolates `{pkg}` via `sprintf()` inside `askfirst_signal()`
itself rather than glue syntax, since `askfirst_capability_gap()` resolves
glue interpolation against the *adopting function's own frame*, which
generally has no variable named `pkg`. Stage 015 reworked the structured
prefix and delimiter tokens without touching the imperative consequence
wording: the prefix's last segment now carries the directive itself
(`askfirst::<language>::<pkg>::<directive>`), a new `type:` line (replacing
the old `directive:` line's position) carries the finer-grained signal
class, and `<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>` compact tokens
replace the prose `----- ASKFIRST AGENT STOP/RESUME ... -----` delimiter
lines. `stop-and-ask` signals are now also written to stdout,
unconditionally, in addition to the existing stderr condition-system
delivery — `notice` signals are not duplicated this way.
**Rationale:** The previous second-person format ("If you are an AI coding
agent...") was interpreted as a prompt injection by AI assistants, causing
outright refusal. The structured prefix lets the tool's system context
identify it as a known, safe signal, and the shared shell script avoids
duplicating installation logic across future language bindings. Stage 011
found, via field feedback, that message text alone was too easily read as
softly-applicable advice rather than a binding rule once a task didn't
literally match a listed example scenario. Rather than reversing stage
007's neutral-message-text decision, directive strength was routed through
the already-trusted agent-hooks context (pre-loaded before any session
starts, not subject to the same prompt-injection risk as an adopting
package's own signal output), while message text itself gained only a
structural (non-tonal) actionability marker. Stage 012 found, via a further
field report, that stage 011's fixes were only partial: an advisory-only
message is not a gate regardless of wording, and offering a "recommended"
workaround option is still offering a workaround option. Both were
addressed at the mechanism level (halting; no-menu-until-answered) rather
than by further softening message text. Stage 013 found the originally
proposed replacement wording for the vague upstream-fix framing ("You are
invited to contribute...") reintroduced a different problem: the calling
agent, not a human, is the direct reader of message text, so an unqualified
"you" defaults to being read as addressing the agent itself rather than the
human the invitation is meant for — a misreading that could plausibly lead
an agent to conclude it should go open an upstream PR unsupervised. Every
sentence in the new "contribute" text names its addressee explicitly
instead. Stage 014 found, via a further field report, that even the
hooks-reinforced structured format still failed to stop an agent from
offering a workaround, and that many sessions run with no hooks installed
at all (or hooks predating a fix) — hook context alone cannot be relied on
to carry instruction strength. Rather than escalating message strength only
once hooks are confirmed current, the decision was to emit the full
hard-stop shape unconditionally, accepting a residual guardrail-rejection
risk in the no-hooks case as the lesser failure mode versus a workaround
slipping through unchallenged.
**Roads not taken:** Keeping the second-person embedded-instruction format
(actively counterproductive — triggers prompt-injection guardrails);
implementing hook installation as R-only logic (rejected mid-stage in favor
of a shared shell script callable from any binding); reintroducing
imperative/second-person message text directly in stage 011 (rejected —
would have reversed stage 007's trust-boundary decision rather than
extended it); resolving the installer's stale embedded hook text at
runtime via relative filesystem lookup of `agent-hooks/` (stage 012 —
would have reintroduced install-layout coupling that an earlier, deliberate
reversion within stage 007 had specifically removed to keep the shared
`tools/` installer usable by any future language binding); an unqualified
second-person "you" in the new stage-013 contribute-invitation text
(rejected once it was recognized the agent, not the human, is the direct
reader of that text); conditioning stage 014's hard-stop message strength on
detected hook-installation status, escalating only once hooks are confirmed
current (rejected in favor of unconditional emission, to avoid a runtime
dependency between two otherwise-separate mechanisms); prefixing every body
line (not just bounding start/end tokens) with a marker, as a stage 015
field report also suggested — deferred as added complexity against
`cli::format_inline()`'s reflowed output, revisit only if the token pair
proves insufficient.
**Stages:** 007, 011, 012, 013, 014, 015

### Hooks-installation detection: language-agnostic manifest and version marker, human-directed nudge
**Outcome:** A hand-maintained `agent-hooks/manifest.json` records, per known
coding-agent tool, only the fixed `hooks_dir` where
`agent-hooks/install-agent-hooks.sh` places its own hook scripts (no config-file
path is recorded, since only Claude Code's is fixed — see Roads not taken
below), plus a single `hook_version` shared across tools. A matching
`# askfirst-hook-version: <N>` comment line was added to the canonical
`agent-hooks/claude/session_start.sh`/`post_tool_use.sh` scripts (propagated
through `agent-hooks/generate-install-hooks.sh` with no logic change needed, since
it already splices file content verbatim). `askfirst_hooks_status()` (R)
embeds a compiled-in copy of this same manifest data (the installed package
doesn't ship the repo-relative `agent-hooks/` directory) and reports
`"not_installed"`/`"stale"`/`"current"` per session, cached like the
existing confidence-detection result. `askfirst_init()` calls it once per
session, independent of AI-agent confidence, and prints a one-time,
human-directed (not agent-directed, and not routed through
`askfirst_signal()`'s condition machinery) nudge toward
`agent-hooks/install-agent-hooks.sh` when hooks are missing or out of date.
**Rationale:** Complements stage 014's message-text self-sufficiency work by
addressing the root cause on the other side — hooks not being installed in
the first place — while keeping the path/version-marker convention portable
to future non-R bindings without redesign. The nudge is human-directed
because the entire reason to show it is that hook context can't be relied
on to reach an agent at all in the state it's warning about, so gating it on
agent-confidence detection the way agent-facing signals are would be
self-defeating.
**Tradeoffs:** opencode's own config file (`opencode.json`) is discovered
via a precedence order across several possible locations (project root,
global config directory, etc. — see
`https://opencode.ai/docs/config#precedence-order`), not a single fixed
path, so the manifest and `askfirst_hooks_status()` only ever check
`hooks_dir` (askfirst's own fixed script-install location), never a config
path, for opencode. The pre-existing `agent-hooks/install-agent-hooks.sh` installer
had, independently, been auto-detecting opencode by checking for a
`.opencode/settings.json` file that can never actually exist under real
opencode config discovery; that always-false detection branch was removed
from `detect_tools()` during this stage, so opencode must now be selected
explicitly via `--tool opencode` (the underlying config-registration path
for opencode installs, `TARGET_CONFIG=".opencode/settings.json"`, was left
unchanged and remains a known inaccuracy, out of scope for this fix).
Stage 017 finally removed that config-registration path entirely (rather
than fixing it), once opencode's own docs confirmed local plugins are
auto-discovered from `.opencode/plugins/` with no registration needed at
all; the manifest gained a `marker_file` field per tool (`session_start.sh`
for Claude Code, `askfirst-plugin.js` for opencode) since the version-marker
filename could no longer be assumed universal, and the version-marker
regex was extended to recognize a `// askfirst-hook-version: <N>`
JS-comment form alongside the original `#`-style one.
**Proposed by:** joint (config-path and detection-branch corrections: mpadge)
**Relates to:** Stage 007 (Decision 2, `agent-hooks/` as the shared,
language-agnostic source this manifest extends)
**Extended by:** Stage 019 added a second, `askfirst_signal()`-based
agent-directed `askfirst_hooks_nudge` condition, gated on high AI-agent
confidence, signalled alongside (not instead of) the human-directed nudge
described above, which remains unchanged and still fires independent of
confidence. That stage also moved the fixed condition text `conditions.R`
had hardcoded (delimiters, stop-consequence, notice-prime) into a new
binding-agnostic `agent-content/` directory, following the sync-copy
pattern `agent-detect-spec/vendor/` already established, rather than
`agent-hooks/`'s symlink.
**Stages:** 014, 017, 019

### Binding-agnostic fixed text: agent-content/, synced like agent-detect-spec/vendor/
**Outcome:** The fixed, non-package-authored text `askfirst_signal()` emits
(the `<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>` marker delimiters, the
hard-stop consequence text, the notice-prime text, and the hooks-nudge
text) was extracted out of `bindings/r/R/conditions.R`'s string literals
into a new top-level `agent-content/` directory. `bindings/r/inst/agent-content/`
holds a committed, byte-identical copy, kept in sync by dedicated
`sync-agent-content.R`/`check-agent-content-sync.R` scripts, a CI check,
and a new local `.githooks/pre-commit` hook (opt-in via `core.hooksPath`);
`conditions.R` reads the synced copy at runtime via `system.file()`.
`agent-hooks/askfirst-context.txt`'s prose, which separately described the
same marker-delimiter tokens, was updated to reference
`{{HALT_MARKER}}`/`{{RESUME_MARKER}}` placeholders rendered from this same
canonical source by `generate-install-hooks.sh`, so the token values can no
longer drift between what a binding actually emits and what the
hook-context prose describes.
**Rationale:** `bindings/r/` is meant to be one of several future language
bindings; text a binding's own runtime emits is exactly the kind of
content `agent-detect-spec/vendor/`'s sync-copy-and-check pattern already
exists to share safely, as opposed to `agent-hooks/`'s symlink-based
delivery, which is scoped to content a coding-agent tool's own hook/plugin
injects and (per the R-packaging decision above) cannot survive being
packaged into a distributable tarball outside this monorepo.
**Roads not taken:** Dev-time R-codegen (rendering canonical templates into
literal R source at build time) was considered first but rejected once the
closer `agent-detect-spec/vendor/` precedent was found already solving the
same problem in this codebase via sync-copy plus runtime `system.file()`
reads. Folding the new sync/check logic into the existing
`sync-vendor.R`/`check-vendor-sync.R` scripts was also considered and
rejected, to keep the third-party-derived vendor sync separate from
askfirst-authored content.
**Stages:** 019

### Hooks-nudge relay: a dedicated tell-user shape, merged into a following halt
**Outcome:** `agent-content/askfirst-markers.txt` gained a `TELL-USER` /
`END-TELL-USER` marker pair, distinct from `HALT`/`RESUME`.
`askfirst_signal()` gives `askfirst_hooks_nudge` a third message-assembly
shape (header + body bounded by these markers + a `See:` line), rather
than continuing to share the plain notice shape with `askfirst_notice`.
New `.askfirst_state` fields (`hooks_nudge_pending_relay`,
`hooks_nudge_relay_text`) let the hard-stop-shape branch prepend an
earlier-fired nudge's bare `TELL-USER` block (no `See:` line of its own)
before a later same-session `stop-and-ask` halt's own block, clearing the
flag so only the first halt after a fresh nudge absorbs it.
`agent-content/askfirst-hooks-nudge.txt`'s body wording was also revised,
from a script-relative-path instruction to a direct repository URL.
**Rationale:** A field report found a `hooks_nudge` notice and a later
`stop-and-ask` halt in the same session's combined output; the agent read
both correctly and obeyed the halt, but its own summary to the human
dropped the nudge's "tell your human user..." instruction entirely.
Diagnosis: only `stop-and-ask` signals carried a hard, always-relay
delimiter (stage 014); the plain-notice shape has none, so a
must-relay-to-human directive read exactly like ordinary, weighable output
once a higher-severity halt co-occurred with it. Merging the two into one
message removes the opportunity for an agent's own summarization to keep
one and drop the other.
**Tradeoffs:** Scoped to `askfirst_hooks_nudge` only, not a new
general-purpose "must-relay" directive tier in `directive_map` — the only
condition class today that is both non-halting and must-relay-to-a-human
rather than must-act-on-by-the-agent. The merge applies uniformly to every
`stop-and-ask` class (including `askfirst_error_redirect`) via the shared
branch, needing no special-casing, since the nudge fires once at session
outset and any later halt's pending-relay state is either already consumed
or still available by construction.
**Proposed by:** joint
**Relates to:** Stage 014 (the hard-stop delimiter precedent extended here
to a second, non-halting case); Stage 019 (`askfirst_hooks_nudge` and the
`agent-content/` canonical-text mechanism this stage's new marker file and
wording revision both build on)
**Stages:** 021

### Enforcement: persistent pending sentinel with active PostToolUse blocking, plus a non-blocking escalation for the agent-invoked gate
**Outcome:** Every `stop-and-ask` signal writes a per-`{pkg}-{type}` file
under `pending/` (filename doubling as de-duplication — a repeat
signal from the same package/type overwrites rather than accumulates).
`post_tool_use.sh` (both Claude Code and opencode copies) now checks for any
pending file on *every* tool call, not just the triggering one, and returns
a blocking response (Claude Code's exit-code-2/stderr-as-reason convention)
if any exist — the agent cannot proceed on any topic until the sentinel is
cleared. A new `user_prompt_submit.sh` hook clears `pending/` at
the start of each new user turn, the only available proxy for "the human has
had a chance to respond," since askfirst cannot detect an actual answer.
`notice` signals keep the pre-existing, lighter-weight `log` —
annotated non-blockingly by `post_tool_use.sh` and cleared after being read,
unchanged in kind from stage 014's plan. Stage 016 added a third,
non-blocking state category on the same footing as `log`/`pending/`: an
`unresolved-notice/<pkg>.txt` marker written whenever a `notice` fires and
cleared only by an explicit resolution (a scenario-check call, at any
confidence tier, or a stop-and-ask firing for the same package) — unlike
`pending/`, never cleared merely by a new user turn, since it isn't waiting
on a human's answer. While any such marker exists, `post_tool_use.sh`
appends an escalating (but never blocking) reminder to every subsequent
file-editing tool call, growing firmer after repeat occurrences. Stage 016
also broadened Claude Code's registered `PostToolUse` matcher from
`Bash|R|Rscript` to include `Edit|Write|NotebookEdit`, without which none of
`post_tool_use.sh`'s checks — including the pre-existing `log`/`pending/`
ones — ever ran on a file-edit tool call at all.
**Rationale:** Directly answers a field report's "delayed consequence"
failure mode: a stop-and-ask signal fired several tool calls before the
agent actually began implementing a workaround, with no mechanism to
retroactively re-surface it. A passive, one-shot log (as stage 014's
`askfirst_hooks_status()` companion work implied for notices) cannot enforce
anything past the immediately-following tool call; only an actively
blocking check on every subsequent call closes that gap. Stage 016's
escalation addresses a different, earlier failure surfaced by field trial:
the blocking gate above is itself only reachable if the agent voluntarily
calls `askfirst_check_scenarios()`, and an agent that never does so gets no
reinforcement at all; since the package's own code cannot mechanically
detect an about-to-be-written workaround (see the Messaging: three
independent intervention points decision), the coding-tool hook — which
does see the agent's subsequent file edits — is the layer that can narrow
this gap instead. It stays non-blocking and untargeted (any edit, not
scoped to files referencing the package) by explicit choice, trading
detection recall for zero risk of blocking unrelated work on a false
positive.
**Tradeoffs:** opencode has no documented shell-hook config equivalent to
Claude Code's `settings.json` hooks at all — its plugin API is a separate
`tool.execute.before/after` JS/TS interface with no documented
blocking-result semantics as of stage 015. Stage 016 investigated this
further and found opencode's real plugin API is a JS/TS module registered
via `opencode.json`'s `plugin` array, executed in-process — confirming the
existing shell-script hook files are very likely never invoked by real
opencode at all, a stronger finding than stage 015's "unverified fallback"
label. The opencode hook files were extended identically to the Claude Code
side anyway (for consistency, and in case an undocumented path exists), with
this concrete finding documented in both copies' headers rather than acted
on; a real JS/TS plugin was flagged as a future stage rather than built now.
Stage 017 built that plugin: `agent-hooks/opencode/askfirst-plugin.js`
implements all three enforcement halves for opencode via
`experimental.chat.system.transform` (context), `tool.execute.after`
(non-blocking log/escalation), and `tool.execute.before` (blocking gate, via
throwing an `Error` while any `pending/` sentinel exists — opencode's own
documented abort-a-tool-call pattern). Verified live against a real,
authenticated opencode session that this abort mechanism fires
unconditionally on every tool call, not scoped to any tool type, achieving
the same coverage as Claude Code's exit-code-2 convention; the legacy
shell scripts were deleted outright once this was confirmed, per explicit
no-fallback-kept decision.
**Proposed by:** git-user (stage 015); joint (stage 017 verification)
**Relates to:** Stage 014 (Decision 3, the `agent-hooks/manifest.json`/
version-marker scheme extended here to a third hook file, `hook_version`
bumped to 2, then 3 in stage 016, then 4 in stage 017)
**Stages:** 015, 016, 017

### State storage: session-scoped tmp root, out of the project's working tree
**Outcome:** All askfirst runtime state (`log`, `pending/`,
`unresolved-notice/`) lives under
`${TMPDIR:-/tmp}/askfirst/<mangled-abs-project-path>/`, not under a
`.askfirst/` directory in the project's own working tree as originally
shipped in stage 015. The mangled path (leading `/` stripped, remaining `/`
replaced with `_`) is computed independently by the R process (from
`getwd()`) and by each hook script (from its payload's `cwd` field) — the
one value both processes already share, so no new coordination mechanism
was introduced. The mangling is a literal transform, not a hash: a
maintainer can `ls` their way to the right directory from the project path
alone, at the cost of that path being visible as a directory name to other
users on a shared multi-user `/tmp`.
**Rationale:** Reviewing where to put stage 016's new marker surfaced that
stage 015's `log`/`pending/` were already sitting in the project's working
tree with no `.gitignore` entry anywhere in the repo — deferred, not
resolved, in stage 015. Adding a third marker family to that same location
would have compounded the gap. Since all three state categories are
inherently session-scoped and meaningless once the coding session ends, the
resolution was to stop writing any of them under the project tree at all,
which obsoletes the `.gitignore` question rather than answering it. R's own
`tempdir()` could not be used for this, since it is randomized per R session
and has no way to be discovered by the separate hook process that must read
the same files.
**Tradeoffs:** No active pruning of leftover, now-empty tmp directories was
added; relies on the OS's own normal tmp reaping. Neither side resolves
symlinks, matching (not introducing) an existing assumption that the R
process's `getwd()` and the hook payload's `cwd` already refer to the same
directory.
**Proposed by:** joint
**Relates to:** Stage 015 (the `log`/`pending/` mechanism relocated here)
**Extended by:** Stage 020 fixed the mangling transform for Windows-style
drive-letter absolute paths (the literal `strip leading /, replace / with
_` scheme left a drive-letter colon embedded in a directory-name segment,
illegal on Windows filesystems, causing widespread `rcmdcheck()` failures
on `windows-latest`). The R side now uses `fs::path_split()` to decompose
paths correctly regardless of host OS; the bash and JS ports received the
equivalent fix, verified byte-identical against an extended shared
fixture. The `TMPDIR` fallback (R side only) also changed from a
hardcoded `"/tmp"` to `tempdir()`, since `/tmp` does not exist on native
Windows R.
**Stages:** 016, 020

### opencode integration mechanism: Hooks/Plugin, not custom Tools
**Outcome:** `agent-hooks/opencode/askfirst-plugin.js` is built against opencode's
Hooks/Plugin mechanism (intercepts the agent's existing tool calls
automatically), not its separate custom-Tools mechanism (`.opencode/tools/`,
which defines new functions the agent may choose to call).
**Rationale:** Every behavior needed — automatic context injection, an
escalating reminder on the agent's own subsequent edits, and blocking any
subsequent tool call — requires watching tool calls the agent already
makes on its own initiative, not offering it a new one to opt into. A
Tool-based implementation would have reintroduced the exact reachability
gap stage 016 fixed: an agent that never calls the tool gets no benefit
from it at all.
**Roads not taken:** A native `askfirst_check_scenarios()` custom Tool
(nicer discoverability than shelling out to `Rscript`) — a legitimate but
separate, smaller enhancement, deferred to a possible future stage rather
than folded into this one.
**Proposed by:** agent, confirmed by git-user
**Stages:** 017

### Plugin distribution: single dependency-free file, named ES export required
**Outcome:** `askfirst-plugin.js` uses only Node/Bun builtins (`fs`, `path`
via `require()`) and exports exactly one binding:
`export const AskfirstPlugin = async ({directory}) => {...}` — a named ES
export, not `export default` and not CommonJS `module.exports`.
**Rationale:** Live testing against a real opencode session found its
plugin loader tries to invoke *every* exported binding in a plugin file as
if it were a `Plugin` function. An initial implementation attempt used
`module.exports`, which the loader did not recognize at all; a later
attempt at exporting an internal helper function alongside the real
plugin (to make it directly unit-testable) caused plugin loading to hang
entirely, since the loader tried invoking that mismatched export too.
**Tradeoffs:** Internal helpers (state-dir path mangling) cannot be unit
tested by direct import; tests instead exercise them indirectly through
the one real exported plugin function, invoked exactly as opencode itself
invokes it.
**Proposed by:** agent (discovered via live testing, not documented anywhere)
**Stages:** 017

### Repo hygiene: canonical shared sources for hook/plugin content, tools/ merged into agent-hooks/
**Outcome:** Three pieces of content stage 017 hand-duplicated across bash
and JS now have one canonical source each under `agent-hooks/`:
`askfirst-context.txt` (the `<askfirst-context>` prose),
`askfirst-reminder-messages.txt` (escalation wording, `{{PKG}}`/`{{COUNT}}`
placeholders), and `askfirst-state-dir.sh` (the mangling function, also
closing a same-language duplication within Claude Code's own
`post_tool_use.sh`/`user_prompt_submit.sh`). `agent-hooks/generate-install-hooks.sh`
gained an earlier splicing pass, translating each canonical source into
every target's native syntax, ahead of its existing per-tool-file-into-
installer pass. The JS port of the mangling function is not
code-generated from the bash source (bash/JS can't execute the same
function body); it stays a manually-maintained translation, verified
against a shared fixture (`askfirst-state-dir-fixture.txt`) consumed by
both the R and JS test suites instead. Separately, the repo-root `tools/`
directory (exactly two files, both existing solely to support
`agent-hooks/`) was merged into `agent-hooks/` itself, letting a redundant
second symlink in the R package's `bindings/r/inst/` be removed entirely
(one whole-directory symlink now covers everything previously split
across two).
**Rationale:** Diffing the two existing context-prose copies before
assuming either was canonical found real, intentional drift: stage 017's
JS version had been reworded ("PostToolUse hook"/"block" → "tool-
execution hook"/"reject") to match opencode's own mechanism. A single
canonical source can't preserve either tool's own specific terminology, so
the canonical text now uses wording accurate for both ("enforcement hook
... stop ... from succeeding" / "a subsequent failed tool call"). `tools/`
as a directory had no purpose beyond hosting these two files; folding it
into `agent-hooks/` removed a directory whose separateness had become
accidental rather than meaningful.
**Tradeoffs:** Reminder-wording source is reformatted (single-line
generated `printf`/template calls vs. the original hand-written multi-
line form) — held to identical *rendered* output, not source-level byte-
identity. A real bug was found while building the JS fixture test: the
`/` → `""` mangling edge case collapses to the shared tmp state-root
itself, so naively deleting it in test cleanup would have been
destructive to shared test infrastructure — excluded from the JS test
(still covered safely by the R-side test). A broader rename of
`agent-hooks/`/the "hooks" R API terminology to something mechanism-
neutral was raised and explicitly deferred, not pursued — "hooks" isn't
inaccurate for what either Claude Code or opencode's plugin actually
implement today (opencode's own SDK types the object every plugin returns
as `Hooks`), and the blast radius of a rename (the whole public API, not
just a directory name) warrants its own future stage if a genuinely non-
hook-shaped tool integration ever changes that.
**Proposed by:** git-user (scope and directory merge), agent (content
drift discovery and generation mechanism)
**Relates to:** Stage 007 (the `agent-hooks/` root-level-plus-symlink
pattern this extends); Stage 012 (the dev-time generation pattern this
extends one layer earlier); Stage 017 (the content divergence this
reconciles)
**Stages:** 018

### Notice suppression: opt-in ASKFIRST_SILENCE_NOTICE, replacing ad hoc filtering
**Outcome:** A comma-separated `ASKFIRST_SILENCE_NOTICE` environment
variable (package names, or the literal `all`) suppresses `notice`-level
logging to `.askfirst/log` only, checked inside `askfirst_signal()`.
`stop-and-ask` signals never consult it — there is no way to silence them.
**Rationale:** A field report's agent resorted to `grep -v
"askfirst|notice|directive|..."` specifically because no sanctioned way
existed to reduce repeated-notice noise across many tool calls — that ad hoc
filtering is what stripped its own stop-and-ask signal along with the
noise it was trying to remove. A supported, explicit, notice-only
suppression mechanism removes the reason to ever pipe askfirst output
through a content filter.
**Roads not taken:** Extending suppression to `stop-and-ask` signals —
rejected outright; a halting, rare signal should never be silenceable by
either a package or a session-level environment variable.
**Proposed by:** joint
**Stages:** 015

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
shell script at `agent-hooks/install-agent-hooks.sh` with a thin R wrapper.
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
Stage 010 addressed the medium-tier boundary open question carried since
stage 002: medium-confidence sessions (no TTY, no known agent) were
producing false-positive signals during CI, testing, and package
installation. All four signal points — `askfirst_init()` load-time notice,
`askfirst_error_handler()` error-redirect, `askfirst_check_scenarios()`
scenario-check, and `askfirst_capability_gap()` — were restricted to fire
only at `"high"` confidence. The medium detection logic in `confidence.R`
was left intact, preserving the enum for future selective opt-in. The
change was purely mechanical: four condition-line edits across three
files, plus corresponding test updates, with 57 tests passing. Stage 011
was triggered by field feedback describing a concrete failure: an agent,
having received both the load-time notice and an explicit
`askfirst_check_scenarios()` result, treated the general "ask before
implementing a workaround" rule as merely advisory once the actual task
didn't literally match one of the three registered example scenarios, and
offered the workaround as a co-equal option in a neutral menu. Reviewing
git history showed the agent-hooks infrastructure and the neutral,
non-imperative message-text decision (stage 007, Decision 4) shipped in
the same commit — the softened message text was a deliberate trust-boundary
choice (message text originates from a potentially untrusted, spoofable
package call; hook context is pre-loaded and trusted), not a stopgap
awaiting hooks. The fix therefore left that boundary intact and
strengthened each side of it: agent-hooks context gained explicit
instruction to treat scenario lists as non-exhaustive and to present the
ask-the-user choice as recommended (not neutral); message text gained a
structural `directive:` marker rather than imperative prose, since hooks
remain opt-in infrastructure and message text is the only channel
guaranteed to reach every agent. The redundant, inconsistently-worded
scenario bullets previously repeated between the load-time notice and the
on-demand scenario-check message were consolidated to the latter alone.
Stage 012 was triggered by a further field report on the same underlying
rule: an agent read the scenario-check advisory message, then offered a
workaround as one of two menu options anyway. Re-examining stage 011's
fixes against this report showed both were partial — the uniform
`directive: ask-before-proceeding` line didn't distinguish signals that
actually halted execution from ones that merely printed advice, and the
"mark ask-first as recommended" hook instruction still treated the
workaround as a selectable option rather than removing it from the choice
set. The fix made `askfirst_check_scenarios()` halt like
`askfirst_capability_gap()` already did, differentiated the `directive:`
value by real severity (including `error_redirect`, which — though itself
non-fatal — always accompanies an already-halting error from the adopting
package's own code), and rewrote hook guidance so a `stop-and-ask` signal
permits no workaround-as-option framing at all until the user has
answered. Investigation during this stage also surfaced an unrelated,
previously silent bug: the shipped R-package installer
(`agent-hooks/install-agent-hooks.sh`) embedded an independent, hand-maintained
copy of the hook text that had never received stage 011's fixes — real
installs had been stale since the moment those fixes shipped. The initial
fix considered was restoring stage 007's original runtime relative-path
resolution of `agent-hooks/`, but this was corrected once it was
recognized that stage 007's later move to inline embedding had been a
deliberate language-agnosticism decision (avoiding runtime install-layout
coupling for a script shared across all future bindings), not an
oversight; the actual fix used a dev-time generation script plus a
regression test instead, preserving that property while still eliminating
the drift. Stage 013 addressed a narrower complaint about message
*content* rather than delivery mechanism: the load-time notice and
scenario-check message both ended on a vague, unattributed note ("...the
capability may belong in `{pkg}` itself") that neither named `askfirst`
nor gave a human any concrete next step. Two new optional `askfirst_init()`
fields (`contribute_how`, `contribute_url`) let a maintainer supply
concrete contribution guidance, built into both messages via one shared
helper so wording can't independently drift the way stage 011 found the
scenario bullets had. The plan's first draft used the literally-requested
"You are invited to contribute..." phrasing; this was corrected during
plan review once it was recognized that the calling agent, not a human, is
the direct reader of the resulting message text, so an unqualified "you"
would default to being read as addressing the agent itself — a misreading
that could plausibly lead an agent to conclude it should go open an
upstream PR unsupervised, precisely the kind of unsupervised action
askfirst exists to route through the human first. Every sentence in the
final wording names its addressee explicitly instead.
`askfirst_capability_gap()` and `error_redirect` were left unchanged,
staying consistent with each function's own established design (fully
author-supplied message; deliberate verbatim-notice reuse, respectively).
Stage 014 was triggered by a further field report describing the same
underlying failure at a more fundamental level: an agent read a
`stop-and-ask` signal that already carried stage 011/012's full structured
prefix and directive line, and offered a workaround as a menu option
anyway, diagnosing the problem as its own message text reading like
ordinary error/package output rather than an unmistakable instruction.
Reviewing this against stage 007/011's deliberate trust-boundary decision
(message text is untrusted/spoofable; instruction strength belongs in
pre-loaded, trusted `agent-hooks/` context) surfaced a real tension: many
sessions never have hooks installed at all, or run with hooks predating
whatever fix ships, so a boundary that routes all instruction strength
through hooks cannot, by construction, reach those sessions. The decision
was to reopen the boundary specifically for `directive: stop-and-ask`
signals — message text now carries a fixed, imperative hard-stop block
directly and unconditionally — while leaving the boundary's other half
intact: the package-authored body still cannot inject or override the
fixed structural text around it, and `agent-hooks/` context was updated to
describe and reinforce the new markers rather than being the sole carrier
of instruction strength. A companion mechanism, `askfirst_hooks_status()`,
was added in the same stage to detect missing/stale hooks and nudge the
human toward installing them, addressing the root cause the reopened
message-text boundary works around rather than fixes. Implementation
surfaced two corrections along the way: the fixed hard-stop text
interpolates `pkg` via `sprintf()` rather than glue `{pkg}` syntax, since
`askfirst_capability_gap()`'s glue interpolation resolves against the
calling package's own frame, which usually has no variable named `pkg`; and
the imperative consequence text's first draft asked the human to judge
whether a capability belonged upstream, corrected to direct the human to
ask the package's own developers instead, since they — not the human user —
are the ones positioned to know. A related, pre-existing inaccuracy was
also corrected: `agent-hooks/install-agent-hooks.sh` had been auto-detecting
opencode via a `.opencode/settings.json` check that can never succeed under
opencode's real, precedence-based config discovery; that dead detection
branch was removed, leaving opencode selectable only via explicit `--tool
opencode`.
Stage 015 was triggered by a second field report describing a different
shape of the same underlying problem: signals that were not discarded but
still missed, because they were buried by scrolling/habituation, stripped by
the agent's own `grep -v askfirst...` filtering, or acted on several tool
calls after they fired. Reconciling this against the original,
narrower-scoped stage goal (recovering signals lost to `2>/dev/null`) found
both failure modes end the same way — the signal never reaching the agent —
so the two were combined into one stage rather than deferred to separate
ones. The fix layered four independent mechanisms rather than picking one:
unconditional stdout duplication for `stop-and-ask` (defeating outright
stderr discarding), a severity-first prefix with compact halt/resume tokens
(defeating visual habituation and slow marker recognition), a persistent
`.askfirst/pending/` sentinel with active `PostToolUse` blocking cleared
only on the next user turn (defeating delayed-consequence loss), and an
opt-in `ASKFIRST_SILENCE_NOTICE` variable (removing the motivation for
self-filtering that stripped a real signal in the field report). Checking
opencode's own hook/plugin documentation — an open question carried into
implementation — found no shell-hook config equivalent to Claude Code's
`settings.json` hooks at all; the opencode hook files fall back to the
Claude Code blocking convention with an explicit unverified-fallback
comment rather than treating the documentation gap as a blocker. A
test-hygiene consequence followed directly from the new filesystem side
effects: `askfirst_signal()` now writes real files under `.askfirst/` for
both notice and stop-and-ask paths at high confidence, so the shared test
helper `local_reset_askfirst_state()` was extended to sandbox every test's
working directory into a fresh tempdir, rather than adding per-test
sandboxing calls across the three test files that use it.
Stage 016 was triggered by a field trial from a sibling test harness
(`askfirst-tests`, not part of this repo) showing a concrete instance of a
gap none of stages 004–015 had directly addressed: the hard `stop-and-ask`
gate for author-unanticipated capability gaps is only reachable through the
agent's own voluntary call to `askfirst_check_scenarios()`, and an agent
that never makes that call — as observed in the trial — gets no
reinforcement past the one-shot notice log, regardless of how strong that
log's wording is. Because the package's own code cannot mechanically detect
an about-to-be-written workaround (the same reasoning stage 004 already
established for why this is an agent-invoked mechanism in the first place),
the fix targets a different layer entirely: the coding-tool hook, which
does see the agent's subsequent file-editing tool calls. A new, explicitly
non-blocking escalation fires an increasingly firm reminder on any such call
following an unresolved notice, deliberately untargeted (not scoped to
files referencing the flagged package) to keep any false-positive cost at
"an extra line of text" rather than a blocked edit. Mid-design, deciding
where this new marker should live surfaced that stage 015's `log`/
`pending/` files were already sitting, ungitignored, in the project's
working tree — a gap that stage's own retrospective had explicitly deferred
rather than resolved. Rather than adding a third marker to the same
location, all three state categories were relocated to a session-scoped
path under a fixed tmp root, computed identically and independently by the
R process and each hook script from the one value they already share (the
project's working directory) — obsoleting the deferred `.gitignore`
question rather than answering it. Implementing the opencode side of the
new escalation required investigating opencode's actual plugin API for the
first time in this project's history (prior stages had only noted its
shell-hook support as "undocumented"); this found opencode's real mechanism
is a JS/TS module registered via config and executed in-process, not a
shell script reading JSON from stdin at all — meaning the opencode hook
files shipped since stage 014 are very likely never invoked by real
opencode. Rather than building a real plugin in this stage (a substantially
larger, separate undertaking), the finding was documented precisely in both
hook file copies, consistent with this project's established practice of
shipping an explicitly-flagged unverified mechanism rather than blocking on
a much larger fix. One task originally scoped for this stage — reconciling
this repo's own local dev hook installation — was found mid-implementation
to rest on a wrong premise (this repo's local hooks belong to an unrelated
tool, not any prior askfirst installation) and was skipped rather than
forced through.
Stage 017 built the real opencode plugin that stage 016 had flagged but not
attempted, closing both that stage's own deferred item and the entangled
harness-side question from `askfirst-tests/recommendations.md` (whether
opencode hook delivery could be trusted at all). Investigation and
implementation proceeded largely through direct empirical testing against a
real, authenticated opencode session (a free-tier model,
`opencode/deepseek-v4-flash-free`) rather than documentation or type
inspection alone — this is the first stage in the project's history to
verify a mechanism this way rather than relying on transcripts, unit tests,
or a coding-tool's published docs. That live testing surfaced findings
neither opencode's docs nor its vendored type definitions stated: opencode's
plugin loader tries to invoke every exported binding in a plugin file as if
it were the plugin function itself (discovered when an unrelated second
export hung plugin loading entirely, and again when the first
`module.exports`-based implementation attempt was silently never invoked at
all); and the precise firing order within a turn (`"chat.message"` fires
once, before any tool calls; `experimental.chat.system.transform` fires
repeatedly, once per inference step, not once per session as Claude Code's
SessionStart does). A version mismatch in this repo's own local dev
environment — the vendored `@opencode-ai/plugin` dependency pinned to
`1.1.23` while the actually-installed `opencode` CLI was `1.18.8`, due to a
stale, unrelated `/usr/bin/opencode` earlier in `$PATH` than the correctly-
updated `~/.opencode/bin/opencode` — was found and fixed during planning,
resolving what had initially looked like a genuine gap between opencode's
published docs and its SDK's type definitions, when it was actually just a
stale local install. The resulting plugin achieves confirmed, not assumed,
parity with Claude Code's three-hook mechanism, and the legacy
`agent-hooks/opencode/*.sh` shell scripts — already known-dead since stage
016 — were deleted outright once that parity was verified, consistent with
the project's practice of not keeping known-dead fallback code once a real
fix supersedes it.
Stage 018 was a repo-hygiene follow-up, triggered directly by stage 017's
own artifact: writing a JS port of Claude Code's hook content by hand had
introduced exactly the kind of duplication earlier stages' generation
tooling (stage 012) already existed to prevent, just not yet extended to
this new case. Reviewing the duplication surfaced it was three separate
pieces of content, not one, and — while diffing the two existing copies of
the largest (the context prose) before assuming either was safe to treat
as canonical — found the two had genuinely, intentionally diverged during
stage 017 (the JS version's mechanism-describing wording was reworded to
match opencode's throw-based blocking, not just copy-pasted). This
reframed the task from "pick one existing copy as canonical" to
"reconcile the two into wording accurate for both," which the stage did
before writing the shared source file, rather than freezing an
already-inconsistent state into the new canonical source. A second,
unplanned expansion happened mid-planning: reviewing why `agent-hooks/`
and a separate top-level `tools/` directory existed as siblings found
`tools/` held exactly two files, both existing only to support
`agent-hooks/`; the merge was folded into the same stage since it touched
the same files the text-consolidation work was already touching, rather
than deferred to a separate pass over the same file set. A related
naming question — whether `agent-hooks/`'s "hooks" terminology remains
accurate now that opencode's own delivery format is called a "plugin" —
was raised, discussed, and explicitly deferred rather than acted on,
once it was recognized the rename's blast radius (the whole public R API)
was disproportionate to fold into a stage about internal deduplication.
Implementation surfaced two further, unplanned findings: a genuine bug in
the extended generator script itself (`set -e` combined with `[[ condition
]] && command` aborting the whole script whenever the condition was
false, not just when the command failed), and — while building a
fixture-driven test for the JS mangling port — a destructive-cleanup risk
in the test itself (the `/` → `""` mangling edge case collapses to the
shared tmp state-root, so naive cleanup would have deleted shared test
infrastructure), both found and fixed before the stage was considered
complete.
Stages 019 and 020 (see Key Decisions and Current Architecture above)
added a second, confidence-gated agent-directed hooks-installation nudge
and fixed a Windows-only path-mangling failure, respectively. Stage 021
was triggered by a single-session field report describing a failure mode
distinct from any the project had previously named: a `hooks_nudge`
notice and a later `stop-and-ask` halt appeared in the same session's
output, the agent obeyed the halt, but its own summary to the human
dropped the nudge's relay instruction entirely — not because the signal
was misread or offered as optional (the patterns behind stages 007–014),
but because an agent's own summarization, when two must-relay signals of
different severity co-occur, collapses toward the more consequential one.
Reviewing this against stage 014's precedent (a dedicated hard delimiter
is what made `stop-and-ask` signals self-sufficient regardless of hook
context) suggested the same treatment for the nudge: a `TELL-USER` shape
distinct from the plain notice shape it had shared with `askfirst_notice`
since stage 019, plus a merge of a pending nudge into the next same-session
halt so the two reach the agent as one message rather than two
independently-summarizable ones. Scoping questions raised while drafting
the plan — whether `askfirst_error_redirect` needed special-casing for the
merge, and whether to track re-running the sibling `askfirst-tests`
harness as part of this stage's own process — were both resolved before
implementation began, the former by recognizing the merge already applies
uniformly by construction, the latter by treating that harness as entirely
out of scope for this repo's own workflow. The stage also revised the
nudge's own body wording to point at a direct repository URL rather than a
script-relative path.

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

**Messaging (stage 011):**
- Reintroducing imperative/second-person prose directly into message text
  to make the workaround-vs-ask directive more forceful — rejected once git
  history showed this would reverse stage 007's deliberate trust-boundary
  decision (message text is potentially untrusted, hook context is not)
  rather than extend it; directive strength was routed through agent-hooks
  context instead.
- Keeping scenario bullets in both the load-time notice and the on-demand
  scenario-check message with unified wording — considered as an
  alternative to dropping them from the notice entirely, rejected in favor
  of a single location so there is nothing left to reconcile between the
  two.

**Messaging (stage 012):**
- Keeping `askfirst_check_scenarios()` non-fatal and relying solely on
  message/hook wording to make the ask-first rule stick — rejected once a
  field report showed advisory-only delivery is read-and-continued-past
  regardless of how the wording is strengthened; halting was adopted
  instead.
- Keeping stage 011's "mark ask-first as recommended" menu framing —
  rejected as still offering the workaround as a selectable option, which
  the field report identified as the anti-pattern itself, independent of
  which option carries a recommendation label.
- Resolving the installer's stale embedded hook text via runtime relative-
  path resolution of `agent-hooks/` — an initial plan, corrected once it
  was recognized that stage 007's earlier move away from that approach was
  a deliberate language-agnosticism decision (avoiding runtime
  install-layout coupling in a script shared across all future bindings),
  not an oversight; a dev-time generation script was used instead.

**Messaging (stage 013):**
- "You are invited to contribute..." phrasing for the new upstream-fix
  invitation — the literal wording from the initial request, rejected
  during plan review once it was recognized the calling agent, not a
  human, is the direct reader of message text; an unqualified "you" would
  default to being read as addressing the agent itself. Every sentence in
  the final wording names its addressee explicitly instead.
- Extending the new contribute-invitation text to `askfirst_capability_gap()`
  or `error_redirect` — out of scope this stage; the former has no
  askfirst-added boilerplate to replace today, and the latter has a
  deliberate, established reason (stage 003) to reuse `notice` text
  verbatim rather than gain new content.
- Per-call `contribute_how`/`contribute_url` overrides on
  `askfirst_capability_gap()` — deferred as unnecessary, since that
  function doesn't consume these fields at all this stage.

**Messaging (stage 014):**
- Conditioning the new hard-stop message shape's strength on detected
  hook-installation status — considered (softer wording when hooks are
  missing/stale, full hard-stop only once confirmed current), rejected in
  favor of unconditional emission, accepting residual guardrail-rejection
  risk in the no-hooks case as the lesser failure mode versus an
  unchallenged workaround, and avoiding a runtime dependency between two
  otherwise-separate mechanisms.
- Asking the human user to judge whether a capability belongs in `{pkg}`
  itself — the first draft of the fixed consequence text; corrected once it
  was pointed out the human typically has no basis for that judgment, only
  the package's own developers do.
- `{pkg}` glue interpolation for the new fixed hard-stop text — considered,
  then replaced with direct `sprintf()` interpolation inside
  `askfirst_signal()` once it was recognized that `askfirst_capability_gap()`
  resolves glue interpolation against the adopting function's own frame,
  which generally has no variable literally named `pkg`.
- A precedence-aware `opencode.json` config-path lookup for the new
  hooks-detection manifest — out of scope; only `hooks_dir` (askfirst's own
  fixed script-install location) is tracked, not a config path, for
  opencode.
- Fixing `agent-hooks/install-agent-hooks.sh`'s pre-existing opencode
  config-registration path (`TARGET_CONFIG=".opencode/settings.json"`,
  written after install but never actually read by real opencode config
  discovery) — left unchanged as a known, out-of-scope inaccuracy; only the
  installer's opencode *detection* branch (which could never succeed) was
  removed this stage, not the separate config-registration write path.
- An anti-spoofing mechanism (signing, checksums, allowlisting) to restore
  some guarantee of message-text legitimacy now that hard-stop text carries
  real instructional weight without hooks to vouch for it in the no-hooks
  case — flagged as a candidate for a future stage, not attempted here.

**Messaging (stage 015):**
- Extending `ASKFIRST_SILENCE_NOTICE` to cover `stop-and-ask` signals —
  rejected outright; a halting, rare signal must never be silenceable by a
  package or session-level environment variable, regardless of noise
  complaints.
- Prefixing every reflowed body line (not just the bounding start/end
  tokens) with a marker, as the field report also suggested — deferred as
  added complexity against `cli::format_inline()`'s output; revisit only if
  a future report shows the token pair alone still isn't enough.
- Adding `.askfirst/` to a project's `.gitignore` automatically — deferred,
  though both `log` and `pending/` are now confirmed pure runtime artifacts
  with no reason to be committed.
- Requiring an explicit acknowledgment action to clear `.askfirst/pending/`,
  instead of clearing it implicitly on the next `UserPromptSubmit` event —
  chosen as the simplest mechanism available without adding a new exported
  "clear" function, but explicitly flagged as not battle-tested; a new user
  message is only a proxy for "the user had the chance to respond," not
  confirmation they actually did.
- Blocking on implementing `post_tool_use.sh`'s active-blocking change until
  opencode's own hook documentation confirmed blocking-result support —
  rejected; the documentation gap was treated as an unresolved question to
  flag transparently (via a code comment noting the fallback is unverified),
  not a reason to withhold the mechanism from opencode users entirely.

**Enforcement (stage 016):**
- A blocking gate for the new escalation (forcing `askfirst_check_scenarios()`
  before any further file edit) — rejected in favor of a non-blocking,
  escalating reminder; the trigger has no way to know whether a given edit
  actually touches the flagged package, so blocking risked stalling
  unrelated work on every false positive.
- Scoping the escalation trigger to files that reference the flagged
  package's name — rejected in favor of an untargeted trigger (any
  file-editing tool call); content-scanning a diff/file for a package name
  is itself a heuristic that can misfire (indirect or aliased usage), and
  the non-blocking severity level already keeps a false positive's cost low.
- Building a real opencode JS/TS plugin to actually implement this
  mechanism for opencode — deferred as a substantially larger, separate
  undertaking once investigation confirmed the existing shell-script hook
  files are very likely non-functional against real opencode; flagged as
  the top candidate for a future stage rather than attempted here.

**State storage (stage 016):**
- Hashing the mangled project path instead of a literal transform —
  rejected in favor of a human-debuggable literal path, accepting that the
  project's absolute path becomes visible as a directory name to other
  users on a shared multi-user `/tmp`.
- Using R's own `tempdir()` for the new state root — rejected; it is
  randomized per R session and has no way to be discovered by the separate
  hook script process that must read the same files.
- Adding active pruning of leftover, now-empty tmp directories — deferred in
  favor of relying on the OS's normal tmp reaping, to avoid adding new
  pruning logic and a threshold constant to design and maintain in this
  stage.
- Reconciling this repo's own local dev hook installation with the new
  version/paths — dropped mid-implementation once it was found this repo's
  local `.claude/hooks/` belong to an unrelated tool, not any prior askfirst
  installation; forcing the change would have overwritten hooks actively in
  use for unrelated purposes.

**Enforcement (stage 017):**
- A custom opencode Tool (`.opencode/tools/`) instead of a Plugin/Hooks-based
  implementation — rejected: Tools are agent-invoked/opt-in, which would
  reintroduce the exact reachability gap stage 016 fixed (an agent that
  never calls the tool gets no benefit); Plugins intercept the agent's
  existing tool calls automatically instead.
- `permission.ask` for the blocking gate instead of `tool.execute.before`
  throwing — rejected once live testing (and opencode's own docs) showed
  `permission.ask` operates only within opencode's existing
  permission-gating system, narrower than the unconditional-on-every-call
  coverage `tool.execute.before`'s abort-via-throw achieves.
- Keeping the legacy `agent-hooks/opencode/*.sh` shell scripts installed
  alongside the new plugin as a defensive fallback — rejected; they were
  already confirmed non-functional against real opencode in stage 016, so
  keeping them added no value once the real mechanism was verified working.
- Exporting internal helper functions (state-dir mangling) from
  `askfirst-plugin.js` for easier direct unit testing — rejected after live
  testing showed opencode's plugin loader tries to invoke *every* exported
  binding as if it were a `Plugin` function; a second, differently-shaped
  export hung plugin loading entirely. Tests exercise the real exported
  plugin function indirectly instead.
- `module.exports` (CommonJS) for the plugin's export — the first
  implementation attempt, silently never invoked by opencode at all; replaced
  with a named ES export (`export const AskfirstPlugin = ...`), confirmed
  live as the convention opencode's loader actually looks for.
- Active pruning or a new config-registration path for opencode's plugin
  install — rejected; opencode's own docs confirm local plugins are
  auto-discovered from `.opencode/plugins/` with no registration step
  needed at all, so the prior (already-suspected-inert)
  `register_hooks_opencode()`/`.opencode/settings.json` write was removed
  entirely rather than replaced with a new registration mechanism.

**Repo hygiene (stage 018):**
- Genuine cross-language code generation for the JS mangling port (rather
  than a manually-maintained translation verified via a shared fixture) —
  rejected as disproportionate machinery for a ~3-line utility function;
  bash and JS can't execute the same function body regardless, so the real
  choice was "codegen a JS AST" vs. "hand-port and verify equivalence,"
  and the latter was judged sufficient.
- Renaming `agent-hooks/` and the public R API's "hooks" terminology
  (`askfirst_install_agent_hooks()`, `askfirst_hooks_status()`,
  `askfirst_hooks_manifest()`) to something mechanism-neutral, given
  opencode's delivery format is called a "plugin" — considered and
  explicitly deferred, not rejected outright; "hooks" isn't inaccurate for
  what either tool actually implements today, and the blast radius (the
  whole public API) was judged to warrant its own dedicated future stage
  rather than folding into a stage about internal deduplication.
- Keeping the reminder-wording splice's generated source in the original
  multi-line, backslash-continued `printf`/argument-list form — the
  generator instead produces a single-line equivalent; held to identical
  *rendered* output (verified by executing both forms with sample values),
  not source-level formatting, since reproducing the exact original line-
  wrapping added complexity with no behavioral benefit.
- Treating `<askfirst-context>`/`</askfirst-context>` as needing a new
  synthetic marker-comment pair, the same way the reminder wording and
  mangling function needed new `ASKFIRST_*_START`/`_END` markers —
  rejected once it was recognized the tags are already unique literal
  content present in both target files, so they serve directly as splice
  boundaries with no new marker syntax needed.

**Hooks-nudge relay (stage 021):**
- A new general-purpose "must-relay" directive tier in `directive_map`,
  rather than a targeted third shape scoped to `askfirst_hooks_nudge`
  alone — rejected; that class is the only one today that is both
  non-halting and must-relay-to-a-human rather than must-act-on-by-the-
  agent, so a whole new tier had no other consumer yet.
- Special-casing `askfirst_error_redirect` in the merge logic — considered,
  then found unnecessary: the nudge fires once at session outset, so by the
  time any later `stop-and-ask` class fires, the pending relay is either
  already consumed or still available by construction, and the shared
  hard-stop-shape branch picks it up automatically either way.
- Interleaving the nudge's text inside the halt's own hard-stop block,
  rather than two back-to-back delimited blocks — rejected in favor of the
  latter, for clearer separation between the two distinct instructions.
- Keeping both blocks' own trailing `See:` line when merged — rejected;
  the nudge's own `See:` line is dropped so the halt's is the only one in
  the merged message, while the nudge's own `askfirst::.../type:` header
  line is kept so the merged nudge content stays machine-identifiable.
- Tracking a re-run of the sibling `askfirst-tests` harness's relevant
  trial cell as a task of this stage — rejected; that harness is a
  separate repository under the maintainer's own manual control, not part
  of this repo's own workflow.
