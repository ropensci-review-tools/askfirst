# Design: design-agnostic-spec

Implementation output for stage `002-design-agnostic-spec`. Sections
correspond 1:1 to the tasks in `tasks.md`.

**Post-retrospective revision:** after this stage's retrospective was
recorded, the confidence-tiering and intervention-point models (originally
shipped as standalone files `agent-detect-spec/confidence-model.md` and
`agent-detect-spec/intervention-model.md`) were removed from
`agent-detect-spec/` and folded back into this document and
`design-decisions.md` instead. Rationale: unlike `vendor/agents.json`,
which is machine-read data with a real consumer, these two documents were
prose describing design principles that any real implementation (R or
otherwise) would translate directly into code — nothing in the repo
enforced conformance between the prose and an implementation, so keeping
them as standalone "spec" files overstated what they were. Their content,
below (T002-4/T002-5), is preserved as design rationale for the R
implementation stage to consult, without living on as a separate,
unenforceable artifact. `agent-detect-spec/` now contains only the
vendored data (T002-1) plus its manifest and sync tooling (T002-2, T002-3).

---

## T002-1: Vendor upstream agents.json

Fetched `agents.json` and its companion `agents.schema.json` verbatim from
`vercel/detect-agent`'s `main` branch, saved unmodified at
`agent-detect-spec/vendor/agents.json` and
`agent-detect-spec/vendor/agents.schema.json`. Both files are consumed
directly using upstream's own schema — no `pkghooks`-specific reformatting.

The vendored data covers 17 agents (`cursor`, `cursor-cli`, `gemini`,
`cline`, `codex`, `antigravity`, `augment-cli`, `opencode`, `goose`,
`junie`, `pi`, `cowork`, `claude`, `replit`, `github-copilot`, `kiro`,
`openclaw`, `devin`), which is a superset of stage 001's T001-1 survey
table — it additionally includes `pi` (a PATH-segment-based check not
identified in stage 001) and explicitly orders `cowork` before `claude` so
the more specific Cowork marker wins, matching stage 001's own note about
`CLAUDE_CODE_IS_COWORK`. This confirms the mid-stage scope reduction was
correct: upstream's data already covers everything stage 001 surveyed, with
no gaps that would have justified maintaining a parallel schema.

The last commit touching `agents.json` at fetch time was
`db63e913876eebbe8526e67a21d5ab392a58908c` (2026-07-15T20:48:51Z),
recorded in `manifest.json`.

---

## T002-2: Write the spec manifest

Wrote `agent-detect-spec/manifest.json` with `name`, `version: "0.1.0"`,
a `files` map pointing to the vendored data/schema, and a `vendor_source`
object recording the upstream repo, path, URLs, last-synced commit/date,
and sync timestamp. (Post-retrospective: the `files` map and description
originally also referenced the two model documents; both were removed
when those documents were folded back into this file — see the note at
the top of this document.)

---

## T002-3: Build the upstream sync GitHub Action

Wrote `.github/workflows/sync-agent-detect-spec.yml`: triggered weekly via
`schedule` (Mondays 06:00 UTC) and manually via `workflow_dispatch`. It
fetches the current upstream `agents.json`/`agents.schema.json`, diffs them
against the vendored copies, and — only if they differ — updates the
vendored files, refreshes `manifest.json`'s `vendor_source` metadata, and
opens a pull request via `peter-evans/create-pull-request` rather than
auto-merging, so a human reviews any upstream change before it takes
effect for consumers. Validated the workflow file as syntactically valid
YAML.

---

## T002-4: The abstract confidence-tiering model

Originally shipped as `agent-detect-spec/confidence-model.md`; folded back
here (see note at top of this document). This is the layer
`vendor/agents.json` does not provide — it identifies *which* tool is
calling but carries no concept of confidence itself. Any implementation
consuming `agent-detect-spec` maps its own detection lookup onto this tier
enum, so that downstream behavior (e.g. whether/how to fire a redirect
message per T002-5's intervention-point model) is driven by a consistent,
language-neutral scale rather than each implementation inventing its own.

**Tier enum:** a closed enum for v1: `high`, `medium`, `low`,
`cooperative`. Closed rather than open/extensible because a small, fixed
set is simpler for every consuming implementation to reason about and
switch on, and adding a new tier later is an additive, non-breaking change
to the enum — there is no cost to starting closed that isn't recoverable.
This resolves `plan.md`'s confidence-enum question in favor of closed, as
decided before implementation began.

**Mapping rules**, evaluated in this order given the current
process/environment:

1. **`high`** — the environment matches any entry in `vendor/agents.json`
   (first-match-wins, per upstream's own evaluation order). These markers
   are set by the calling tool's own process spawning and require no
   cooperation from the target package's users, so a match here is
   treated as confident regardless of whether any corroborating signal is
   also present.
2. **`medium`** — no `vendor/agents.json` entry matched, but a
   corroborating signal is present: no TTY attached to stdin/stdout,
   and/or process ancestry matches a known agent-tool binary name. This is
   ambiguous non-interactive automation — it may be an agent tool not yet
   covered by the vendored data, or it may be ordinary human CI/scripted
   automation, since TTY/ancestry alone false-positive on plain, non-agent
   CI or scripted runs — hence `medium`, not `high`.
3. **`low`** — no signals present at all: a TTY is attached and no
   vendored entry matched. Treated as the default human/interactive
   assumption.
4. **`cooperative`** — reserved for a future signal in which the calling
   tool itself explicitly announces agent-driven status to the target
   package (e.g. a hypothetical marker exposed by an R context-sharing
   tool such as `btw`'s MCP server; no such marker currently exists in any
   known tool integration). No lookup path currently produces this tier;
   it is included in the enum now purely so that adding one later is
   additive rather than a breaking schema change. A `cooperative` result,
   once real, should be treated as at least as confident as `high`, since
   it removes ambiguity entirely rather than inferring it from
   process/environment facts.

**Non-goal:** this model does not specify *how* a given language reads TTY
state or walks process ancestry (R's approach, via `isatty()` and the `ps`
package, is R-specific and is left to individual implementations) — only
the tier outcomes and the rules for assigning them once those checks have
been performed.

---

## T002-5: The abstract intervention-point model

Originally shipped as `agent-detect-spec/intervention-model.md`; folded
back here (see note at top of this document). Specifies, as
language-neutral concepts, the points during a calling session at which a
redirect-to-maintainer message may be delivered once a caller has been
assessed via T002-4's confidence model. Intentionally does not specify
*how* any given language delivers the message (R's mapping onto its
condition system is R-specific and is left to individual implementations)
— only the trigger, default severity, and cardinality of each point, and
which candidate points were considered and rejected.

These three points are independent: none of them substitutes for or
subsumes another, and an implementation may support all three, a subset,
or add support for one before another.

**Recommended points:**

- **`load_time`** — Trigger: the package/module is loaded or imported into
  the session. Cardinality: once per session. Default severity: `notice`
  (non-fatal). Purpose: a general, one-time disclaimer — "if you are an AI
  coding agent and hit a bug or missing feature, tell your user to contact
  the maintainer rather than working around it yourself" — fired before
  any use of the package, at negligible cost.
- **`error_time`** — Trigger: an error/exception the calling code already
  raises, originating from the target package. Cardinality:
  re-triggerable, once per error, not deduplicated across the session,
  since each error is a distinct event worth surfacing. Default severity:
  `notice`, layered onto the error that is happening anyway (this point
  does not itself decide whether execution halts). Purpose: matches the
  "if an LLM finds a bug" half of the original motivation; reuses whatever
  condition/exception mechanism the calling language already has, at zero
  additional detection cost beyond what ran at `load_time`.
- **`capability_gap_time`** — Trigger: an explicit, author-instrumented
  call site in the target package's own code, marking that a known
  limitation or unimplemented capability was just reached; unlike
  `error_time`, nothing errors, so this point cannot piggyback on it and
  requires its own call site. Cardinality: re-triggerable, once per call
  site hit. Default severity: `halt`-capable — this point may be delivered
  as a hard stop, since halting is the deliberate intent here, unlike the
  non-fatal `load_time` notice. Purpose: matches the "or something my
  software can't do" half of the original motivation — the scenario an LLM
  is most likely to silently work around unless surfaced directly.
  Requires author opt-in; no mechanical/heuristic alternative was found
  that satisfies the no-false-positive constraint (every candidate —
  short/NULL return-value heuristics, silently-ignored-argument detection,
  cross-call error-pattern matching — either risks false positives or
  requires reimplementing domain knowledge only the package author has).

**Rejected points:**

- **`first_call`** (lazy, first-use-only messaging) — rejected as a
  replacement for or refinement of `load_time`. Only avoids firing for a
  package that's attached but never used, a marginal win that doesn't
  justify the added bookkeeping needed to implement it.
- **`every_call`** — rejected outright: (1) overhead, since even a cheap
  check repeated on every hooked call violates a low-overhead constraint
  by construction; (2) noise, since repeating the same general notice on
  every call trains callers to tune it out, undermining the rarer, more
  important `error_time`/`capability_gap_time` messages actually landing.
- **`help_access`** (e.g. `?fun`, `help()` in R) — plausible in principle
  but not recommended for v1. In R specifically, the help system is not a
  hookable extension point the way load-time or the condition system are;
  this reasoning is language-specific, and each implementation should
  re-evaluate whether its own language's documentation-access mechanism is
  hookable rather than assuming R's conclusion applies universally.

---

## T002-6: Write the spec directory's README

Wrote `agent-detect-spec/README.md`: explains the directory's purpose and
layout, the versioning policy, and the sync-workflow review process
(review the PR's diff, merge — no other repo changes required, since
`vendor/agents.json` is consumed directly). Post-retrospective, the README
was revised to drop its description of the confidence/intervention models
(now T002-4/T002-5 above) since those files no longer live in the
directory it describes.

---

## T002-7: Synthesis

This stage began with a broader plan — designing an independent JSON
schema and data file mirroring `agents.json`'s content in a
`pkghooks`-specific shape — before the user correctly identified that this
would duplicate `vercel/detect-agent`'s already-maintained data for no real
benefit. The plan and tasks were revised mid-stage to drop that duplication
entirely: `agents.json` is vendored and consumed verbatim.

The stage's actual design contribution was the two layers upstream doesn't
provide — the confidence-tiering model and the abstract intervention-point
model — plus the automation (sync workflow, manifest) needed to keep the
vendored data current without hand-maintenance. Both previously-open
questions from `plan.md` are resolved:
- **Confidence-tier enum**: closed (`high`/`medium`/`low`/`cooperative`)
  for v1, extensible later without a breaking change.
- **Detection-data shape**: moot — the vendored file uses whatever shape
  `vercel/detect-agent` defines (a flat array), consumed as-is rather than
  re-derived into a parallel shape.

After the retrospective, a further question was raised: standalone
`confidence-model.md`/`intervention-model.md` files had no real
enforcement mechanism (unlike `vendor/agents.json`, which is machine-read
data), and any actual implementation would translate their prose directly
into code regardless. They were removed from `agent-detect-spec/` and
folded into T002-4/T002-5 above, so the reasoning remains available to the
R implementation stage as design rationale rather than as an unenforceable
"contract."

`agent-detect-spec/` is now a narrower, complete artifact — vendored
detection data plus a manifest and sync tooling (`manifest.json` at
`0.1.0`) — ready to be consumed by a follow-up R-specific implementation
stage, which will consult this document's T002-4/T002-5 content to build
`pkghooks_init()`, `flag_capability_gap()`, and R's own condition-based
delivery mechanism, none of which was designed in this stage.
