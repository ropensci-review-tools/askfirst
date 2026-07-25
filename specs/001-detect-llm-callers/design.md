# Design: detect-llm-callers

Research-and-design output for stage `001-detect-llm-callers`. Sections
correspond 1:1 to the tasks in `tasks.md`. This document is the primary
input for this stage's `/designlens.retrospective`.

---

## T001-1: Non-cooperative environment/process signals

Non-cooperative signals are environment variables that AI coding tools set on
processes they spawn, without any code in the target language needing to opt
in. The most authoritative source found is
[`vercel/detect-agent`](https://github.com/vercel/detect-agent)'s
[`agents.json`](https://raw.githubusercontent.com/vercel/detect-agent/main/agents.json)
— a maintained, language-agnostic, machine-readable spec of exactly these
signals, used by Vercel's own Go/JS/TS detection libraries and referenced by
the `unjs/std-env` JS library. It evaluates agents in order (first match
wins) and models each check as `env_set` / `env_value` / `env_matches` /
`file_exists` / `no_tty` conditions, optionally combined with `anyOf`/`allOf`.

| Tool | Signal(s) | Reliability notes |
|---|---|---|
| Claude Code | `CLAUDECODE` or `CLAUDE_CODE` set | Documented, propagated to subprocesses. Known caveat: inherited by grandchild processes too, so a human manually running a nested shell inside a Claude Code session would also trip it — not just LLM-initiated calls. `CLAUDE_CODE_IS_COWORK` distinguishes the Cowork variant. |
| Claude Code (subprocess/session detail) | `CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_REMOTE`, `CLAUDE_CODE_ENVIRONMENT_KIND`, etc. | Undocumented/internal (found via community gist, not official docs) — useful for diagnostics, not for a stable public API to depend on. |
| Cursor (IDE agent) | `CURSOR_TRACE_ID` set | IDE-integrated agent context. |
| Cursor CLI | `CURSOR_AGENT` set, or `CURSOR_EXTENSION_HOST_ROLE=agent-exec` | Distinguished from the plain Cursor IDE terminal (which sets `CURSOR_CLI` but is not itself agent-driven — a human can open a Cursor integrated terminal and type manually). |
| Gemini CLI | `GEMINI_CLI` set | — |
| Cline | `CLINE_ACTIVE` set | — |
| OpenAI Codex CLI | `CODEX_SANDBOX`, `CODEX_CI`, `CODEX_THREAD_ID`, or `CODEX_SANDBOX_NETWORK_DISABLED` set | — |
| Antigravity | `ANTIGRAVITY_AGENT` or `ANTIGRAVITY_CLI_ALIAS` set | — |
| Augment CLI | `AUGMENT_AGENT` set | — |
| opencode | `OPENCODE_CLIENT` or `OPENCODE` set | — |
| Goose | `GOOSE_PROVIDER` set | — |
| Junie (JetBrains) | `JUNIE_DATA` or `JUNIE_SHIM_PATH` set | — |
| Replit Agent | `REPL_ID` set | Ambiguous alone — `REPL_ID` is set for *any* Replit workspace, human or agent-driven, so on its own it signals "running on Replit," not "LLM-driven." |
| GitHub Copilot CLI | `COPILOT_MODEL`, `COPILOT_ALLOW_ALL`, or `COPILOT_GITHUB_TOKEN` set | GitHub Copilot Chat's terminal tool (VS Code) does **not** currently set any such marker for commands it runs — this is an open, tracked gap ([vscode#311734](https://github.com/microsoft/vscode/issues/311734)), so Copilot Chat-in-VS-Code agent-run commands are currently **undetectable** this way. |
| AWS Kiro | `TERM_PROGRAM` matches `kiro` **and** no TTY attached | Notable pattern: `TERM_PROGRAM=kiro` alone is set by both the IDE's human-facing integrated terminal and the CLI agent, so Kiro's own detection gates on `no_tty` to disambiguate — direct prior art for the interactive()-is-insufficient problem in T001-2. |
| openclaw | `OPENCLAW_SHELL` set | — |
| Devin | file `/opt/.devin` exists | Only tool in the set using filesystem presence rather than an env var — evidence that env-var coverage isn't universal and other signal types are sometimes necessary. |
| Generic/universal | `AI_AGENT` env var (any value) | An emerging, not-yet-universal convention (`aiAgentVar` in the vercel spec; also discussed as a candidate standard in [agents.md issue #136](https://github.com/agentsmd/agents.md/issues/136), alongside a competing bare `AGENT` proposal used already by Goose/Amp/Bun). No single standard exists yet — a package relying on it will miss any tool that hasn't adopted it. |

**Reliability summary**: coverage is good for CLI-native coding agents (Claude
Code, Cursor CLI, Codex, Gemini CLI, opencode, Goose, etc.) because these
tools deliberately mark their own subprocess environment. Coverage is poor to
absent for IDE "agent modes" that reuse the human's existing terminal
integration without a distinct marker (GitHub Copilot Chat in VS Code being
the clearest documented example) — for those, no signal in this category
exists yet, cooperative or not. None of these require the tool to specifically
support R; they are shell/process-level and language-agnostic by
construction, which directly informs T001-9.

---

## T001-2: R session/process introspection signals

Candidate R-native signals, independent of any tool cooperation:

- **`Sys.getenv()`** — reads the process-level markers surveyed in T001-1
  (`CLAUDECODE`, `CURSOR_AGENT`, etc.) since R subprocesses inherit the
  spawning shell's environment like any other process. This is the primary
  mechanism by which T001-1's findings become usable from R; no R-specific
  discovery work was needed beyond confirming `Sys.getenv()` exposes them
  (it does, trivially — it's a full environment dump).
- **`commandArgs()`** — exposes how the R process was invoked
  (`Rscript foo.R`, `R --no-save`, `R -e '...'`, etc). An agent driving R
  non-interactively will typically show up as `Rscript` or `R --no-echo -e`
  invocations, but scripted/CI human workflows look identical, so this is at
  best a weak corroborating signal, not a standalone detector.
- **Parent process name** — R has no base-package way to walk the process
  tree; the `ps` package (used inside RStudio itself, actively maintained)
  provides `ps::ps_pid()`, `ps::ps_parent()`, and `$name()`/`$cmdline()` on
  the result, enabling e.g. "is my parent process named `node` and does its
  cmdline contain `claude`?". This is unreliable in general (shells,
  wrappers, and process supervisors interpose arbitrary intermediate
  processes) but can corroborate an env-var signal, and going further up the
  ancestor chain (not just immediate parent) improves robustness somewhat.
  Adds a hard dependency on `ps`, which is itself is a reasonably safe,
  widely-used package but not part of base R.
- **stdin/stdout TTY attachment** — `isatty(stdin())` / `isatty(stdout())`.
  This is exactly the axis AWS Kiro's own detector uses (T001-1) to
  disambiguate its IDE terminal from its CLI agent, both of which set the
  same `TERM_PROGRAM` value. The same pattern generalizes: an agent driving R
  as a subprocess (piping commands in, reading output back programmatically)
  will almost always have no TTY on at least one of stdin/stdout, whereas a
  human at an R console has both.

**Why `interactive()` alone is insufficient**: `interactive()` answers "is R
running in a read-eval-print loop that expects interactive input," which is
true for a human at an R/RStudio console but is *also* true whenever an agent
drives R by feeding commands into a live, interactively-launched R session
(e.g. an MCP tool that keeps a persistent `R --interactive` process open and
writes to its stdin) rather than invoking `Rscript` per call. In that
architecture the R process is indistinguishable from a human's session by
`interactive()` alone — both return `TRUE`. Reliably telling the two apart
requires layering in something `interactive()` doesn't check: whether stdin
is actually a TTY the way a real terminal would be (an agent's pipe isn't),
process-tree ancestry, or an explicit tool-set environment variable. None of
these individually is bulletproof (a human could pipe a script into a
persistent R session too, in principle), which is why T001-5 treats
corroboration across signal categories, rather than any single check, as the
target design.

---

## T001-3: Call-stack / caller-frame signals

Investigated `sys.calls()`, `sys.function()`, frame depth, and calling
namespace as potential differentiators.

**Finding: no reliable signal here.** R's call stack reflects the *R-level*
call chain (which function called which), not *how the R process itself was
invoked or who is driving it*. A human sourcing a script and an LLM agent
piping the same script into R produce byte-identical call stacks once
execution reaches a `pkghooks`-instrumented function — same frame depth, same
calling package/namespace, same `sys.function()` results — because in both
cases the ultimate entry point is the same script/console evaluation loop.
Frame depth might differ marginally depending on whether code is `source()`d
vs. typed line-by-line vs. run via `Rscript -e`, but that's a proxy for
*invocation style*, not caller identity, and scripted human workflows
(`Rscript run.R` in a Makefile or CI job) produce the same shape an agent
would. MCP-based R tool servers that expose individual R functions as
callable "tools" (as `btw`'s MCP server does, see T001-4) are the one case
where the immediate caller frame could plausibly carry an agent-attributable
marker — but that's a property of the *tool server's* wrapping convention,
not of R's call stack per se, and only applies when a package deliberately
integrates with such a server. This is effectively a restatement of the
cooperative-signal category (T001-4/T001-11), not a new non-cooperative one.

**Conclusion**: call-stack introspection is ruled out as a detection
category. It does not distinguish agentic from human invocation at the R
language level under any invocation pattern examined.

---

## T001-4: `btw` as a cooperative detection signal

Reviewed `btw`'s GitHub repo, `AGENTS.md`, and public docs
([posit-dev.github.io/btw](https://posit-dev.github.io/btw/)).

**(a) What's available today**: `btw` is built to feed R context *to* LLMs,
not to expose *that an LLM is present* to arbitrary R code. Its three
integration surfaces are: `btw()` / `btw_app()` for copy-paste or interactive
chat use by a human; `btw_tools()` for registering R introspection tools with
`ellmer` chat clients; and `btw_mcp_server()`, which exposes those same tools
over MCP to external agents (Claude Desktop, etc.). Tool-wrapping functions
internally carry a `_intent` parameter (via an internal `wrap_with_intent()`
helper) but this is plumbing for `btw`'s own tool-calling machinery, not a
documented, public signal a third-party package could read to detect
"this call came from an LLM." No environment variable, global option, or
session flag documented anywhere in `btw` marks "an agent is driving this
session."

**(b) Extensibility**: Because `btw_mcp_server()` is the one place where
`btw` genuinely sits between an LLM and a live R session, it's the
architecturally natural point to add a marker — e.g. having the MCP server
set `options(btw.llm_driven = TRUE)` or an env var in the R session it
manages, when it starts. That would require a patch (or upstream PR) to
`btw` itself, not something `pkghooks` can add non-invasively from outside.
It would also only cover the subset of LLM-R interaction that goes through
`btw`'s MCP server specifically — an agent driving R via a raw subprocess
(most current CLI coding agents, per T001-1) or via a different MCP R server
entirely would not be covered.

**(c) Maintenance burden vs. usable-unmodified**: relying on an upstream
`btw` change means `pkghooks` depends on a Posit-maintained package accepting
and shipping a feature purpose-built for a different project's use case —
plausible to propose upstream, but not something `pkghooks` controls on its
own timeline. A local fork avoids that dependency but commits `pkghooks`'s
maintainer to tracking `btw` upstream indefinitely. Given `btw` covers only
one (currently minority, per T001-1) integration pattern even if extended,
and non-cooperative signals already cover the dominant CLI-agent pattern,
**`btw` is not worth pursuing as a required dependency for v1.** It remains
a reasonable candidate for a future, optional, high-confidence corroborating
signal (T001-5) if `pkghooks` or a collaborator later upstreams the marker —
but nothing in this stage should block on it.

---

## T001-5: Evaluate and rank candidate detection signals

Candidates from T001-1 through T001-4, scored against the three constraints
(no false positives for humans / works without cooperation / low overhead):

| Signal | No false positives | Works w/o cooperation | Low overhead | Verdict |
|---|---|---|---|---|
| Tool-specific env vars (`CLAUDECODE`, `CURSOR_AGENT`, etc.) | High — these are set specifically by the tool's own subprocess spawning, not by generic shell/CI use | No — requires the *tool* to have adopted the convention, but not the R package being called | Yes — one `Sys.getenv()` read per session | **Primary signal.** Best-in-class today; covers the majority of current CLI-native agents. |
| `AI_AGENT` / `AGENT` generic env var | High, same reasoning | No | Yes | **Secondary/future-proofing signal.** Not yet universal, but free to check alongside the above and will improve in coverage over time as tools converge on it. |
| TTY attachment (`isatty()`) | Medium — piped/CI human scripts also lack a TTY, so this alone *would* false-positive on non-interactive human automation (e.g. an Rscript run from a CI pipeline) | Yes — no tool cooperation needed at all | Yes — cheap syscall | **Corroborating signal only.** Must not be used standalone because of the CI/scripted-human overlap; useful to raise confidence when combined with an env-var hit, or to soften a "no env var, but also no TTY" ambiguous case. |
| Parent-process inspection (`ps`) | Medium — depends entirely on the specific check; matching a known agent binary name in the ancestry is fairly safe, matching "not a known shell" is not | Partially — works without the *target tool's* cooperation but depends on process names being stable/predictable, which isn't guaranteed across OSes or wrapper layers | Medium — extra dependency (`ps`) and a syscall walk, but still session-scoped/cheap if done once | **Optional corroborating signal.** Adds a real dependency for modest incremental confidence over env vars alone; worth offering as opt-in, not a default requirement. |
| `commandArgs()` invocation shape | Low standalone (identical for human `Rscript` runs and agent-driven runs) | Yes | Yes | **Not a standalone signal**; too coarse to be useful even as corroboration beyond what TTY-checking already gives. |
| Call-stack/frame introspection | N/A — no signal found | N/A | N/A | **Rejected** (T001-3): does not distinguish caller identity at all. |
| `btw` MCP marker (hypothetical, requires upstream change) | High, if implemented | No (opposite: requires tool cooperation with `btw` specifically) | Yes | **Deferred.** Real signal in principle, but not implementable without upstream buy-in, and only covers `btw`-mediated sessions. |

**Recommendation — top 1–3 approaches to carry forward:**

1. **Env-var check against a maintained detection table** (tool-specific
   markers + the emerging `AI_AGENT`/`AGENT` convention), checked once per
   session at load time. This is the load-bearing signal: highest precision,
   zero cooperation required from the R package's own users, negligible
   cost.
2. **TTY-attachment as a confidence modifier, not a gate**: don't use it to
   independently declare "this is an agent," but use it to (a) raise
   confidence when it corroborates an env-var hit, and (b) potentially
   soften messaging in the ambiguous "no known env var, no TTY" case
   (non-interactive automation of *some* kind, agent or not) rather than
   staying silent or false-positiving on plain CI.
3. **Parent-process ancestry via `ps`, as an opt-in, best-effort layer** —
   left as a documented extension point (T001-11) rather than a default,
   since it adds a dependency for marginal gain over (1).

Rejected outright: call-stack introspection (no signal exists) and
`commandArgs()` alone (too coarse). `btw` cooperation is deferred, not
rejected, pending upstream feasibility.

This ranking directly implies a **confidence-tiered, not binary,
classification** — resolving one of `plan.md`'s open questions: signal (1)
alone should be sufficient to trigger load-time messaging (T001-7) at
"high confidence," while (1)+(2) or (1)+(3) corroboration could be used later
to gate more assertive interventions if the design ever wants a
higher-confidence tier for something more targeted than a load-time notice.

---

## T001-6: Message-delivery mechanisms

Candidate mechanisms for actually getting a redirect message in front of the
LLM (and, transitively, the human):

- **`message()`** — R's standard informational condition. Pro: zero
  friction, doesn't interrupt execution, universally supported by every R
  invocation path (console, `Rscript`, `source()`, MCP tool call). Con: by
  far the easiest for an agent (or a wrapping tool) to swallow silently —
  many agent harnesses capture stdout/stderr and only surface it to the
  human if the agent's own summarization step chooses to quote it; there's
  no guarantee of surfacing.
- **`warning()`** — Slightly more attention-grabbing than `message()` (many
  R tools/IDEs visually flag warnings), but same fundamental risk: an agent
  can catch it with `tryCatch()`/`withCallingHandlers()` and continue past it
  unremarked, especially since warnings are explicitly non-fatal by design —
  which is also exactly the behavior we're trying to *prevent* (the agent
  working around/past the problem rather than surfacing it).
- **A custom condition class** (e.g.
  `structure(class = c("pkghooks_redirect", "condition"), ...)`, signaled via
  `signalCondition()` or `rlang::abort()`/`rlang::cnd_signal()` with a
  distinct class) — Pro: doesn't require guessing what text an agent's
  harness will or won't surface; an agent's *code* (as opposed to a human
  glancing at console output) is far more likely to inspect condition
  *classes* programmatically if it's doing careful error handling, and a
  distinctively-named class (`pkghooks_redirect_notice`) is self-describing
  even out of context. Con: only helps if the agent's tool-calling layer
  propagates condition metadata (not just captured text) back to the model —
  true for some MCP-based tool integrations, not guaranteed for a raw
  subprocess/stdout-capture integration.
- **An actual R error** (`stop()`/`rlang::abort()`) for the highest-severity
  cases — Pro: by far the hardest for an agent to silently ignore, since
  execution halts and most agent harnesses *do* feed error text back to the
  model as something requiring a response. Con: turns a "please redirect the
  user" notice into something that actually breaks the calling code's
  control flow, which is a much bigger intervention than a notice — probably
  appropriate only for the capability-gap/error-time case (T001-7/T001-8),
  never for the load-time notice, and risks being *too* effective in the
  wrong direction (an agent might try to work around the error itself rather
  than relay it, exactly the failure mode this project exists to prevent).
- **Annotated return-value attribute** (e.g. `attr(result, "pkghooks_notice")`
  on an otherwise-normal return value) — Pro: doesn't disrupt control flow at
  all, works even at capability-gap time when nothing errors. Con: by far the
  weakest surfacing guarantee — attributes are routinely dropped by
  downstream operations and essentially never inspected unless the caller
  specifically knows to look, so an agent has to be deliberately checking for
  this exact package's convention. Realistically only useful as a
  *secondary*, structured channel alongside one of the condition-based
  mechanisms above, not standalone.

**Recommendation**: no single mechanism dominates, and reliability
fundamentally depends on the calling tool's architecture (raw subprocess vs.
MCP tool call vs. persistent interactive session), which `pkghooks` cannot
control. The pragmatic answer is to **layer them**: a custom condition class
as the primary, structured, self-describing channel (best chance of being
inspected programmatically by a careful agent), signaled via `message()`
semantics (non-fatal) at load time and reserving an actual `stop()`/`abort()`
only for capability-gap/error-time interventions where halting execution is
the explicit intent. This mechanism choice is revisited per intervention
point in T001-7.

---

## T001-7: Session intervention points

Evaluating each candidate from `plan.md` against the three constraints:

- **Package load (`.onLoad()`/`.onAttach()`)** — **Recommended, primary
  point.** Fires exactly once per session, before any use of the package, at
  negligible cost (a handful of `Sys.getenv()` reads). This is where the
  env-var + TTY-corroboration check from T001-5 belongs. Delivers a general
  "you appear to be an LLM agent; if you hit a bug or missing capability,
  tell the user to contact the maintainer rather than working around it"
  notice via the condition mechanism from T001-6. Confirms `plan.md`'s
  working hypothesis for this point.
- **First function call (lazy, on-first-use)** — **Rejected as a
  replacement for load-time; not pursued as a refinement either.** It only
  improves on load-time by not firing for a package that's attached but
  never used — a marginal, low-value win — while adding real complexity
  (needing a package-level mutable flag/environment to track "have I already
  fired," which itself has to be as cheap as `.onLoad()` already is to be
  worth it). Load-time is simpler and just as cheap; this point doesn't earn
  its keep.
- **Every function call** — **Ruled out**, per `plan.md`'s explicit call to
  document the reasoning rather than skip it. Two independent reasons: (1)
  overhead — even a cheap check repeated on every hooked call across a
  package's whole API surface adds up, and violates the "low overhead"
  constraint by construction, especially for packages with hot-path
  functions called in loops; (2) noise — repeating the same general notice
  on every call is actively counterproductive, training the agent (or a
  human accidentally triggering it) to tune it out, which undermines the
  goal of the *specific*, rarer error-time/capability-gap-time messages
  actually landing. The one-time load-time notice already achieves
  "the agent has been told, once, up front" without this cost.
- **Error/failure time** — **Recommended, second point.** Confirmed as
  practicable: R's condition system gives a natural interception point
  (a package can wrap its own error paths, or more generally offer a
  `pkghooks`-provided error-wrapping helper per T001-11) with no additional
  detection cost beyond what already ran at load time (the LLM-driven
  determination is made once and cached for the session; error time just
  decides *whether* to layer the redirect message onto an error that's
  happening anyway). Matches idea.md's "if an LLM finds a bug" framing
  directly.
- **Capability-gap time (no error thrown)** — **Recommended, third,
  independent point**, per `plan.md`'s framing — see T001-8 for the
  detection mechanism, which is the hard part; the *intervention-point*
  question itself (should this be a distinct point from error-time) is
  answered yes: a capability gap is definitionally a case where nothing
  errors, so it cannot piggyback on the error-time hook and needs its own
  call site (an explicit `pkghooks::flag_capability_gap()`-style call, per
  T001-8/T001-11).
- **Help/documentation access (`?fun`, `help()`)** — **Noted, not
  recommended for v1.** Plausible in principle (an agent probing docs is a
  moment where the answer "this doesn't do what you need" could be
  injected), but R's help system is not designed as a hookable
  extension point the way `.onLoad()` or the condition system are —
  intercepting `?`/`help()` calls generically would require non-trivial,
  fragile machinery (overriding `help()` itself or similar), for a touchpoint
  that only matters if the agent actually reads docs before acting, which
  isn't guaranteed. Worth revisiting only if the three primary points prove
  insufficient in practice.
- **Session startup / `.Rprofile`, package installation time** (raised in
  `plan.md`'s open questions) — **Not pursued.** `.Rprofile` is
  user/project-owned, not something `pkghooks` can inject into on a target
  package's behalf without much more invasive setup instructions, and
  install-time is before the package is even loaded into a live session, so
  it can't carry session-specific detection state — it could at best print a
  static, always-shown notice at install time, which doesn't correlate with
  *this session* being LLM-driven at all.

**Conclusion**: `plan.md`'s three-point hypothesis (load-time,
error-time, capability-gap-time) is validated. First-call and every-call are
explicitly ruled out with the above reasoning; help-access is noted as a
plausible future point but out of scope for v1.

---

## T001-8: Capability-gap detection approaches

The core difficulty, as `plan.md` identifies: a capability gap is by
definition a case where the call "succeeds" (returns normally) but doesn't
meet the actual need — there is no condition to hook into, because nothing
signals a condition at all.

Approaches considered:

- **Package-author-maintained annotations of known limitations** — the
  author marks specific functions/arguments/combinations as known gaps
  (e.g. "this function doesn't support X yet") ahead of time. Requires
  authors to (a) know their own gaps and (b) proactively register them, but
  once registered, detection is mechanical: `pkghooks` can check "was this
  known-gap condition hit" at the point the author's code calls a
  `pkghooks`-provided marker function (e.g.
  `pkghooks::flag_capability_gap("no support for grouped input yet")`)
  inline at the relevant branch. This is the only approach found that
  reaches 100% precision (no false positives) because the author is
  asserting the gap directly, at the exact moment it's hit.
- **A registry of requestable-but-unimplemented capabilities** — a
  variant of the above, structured as a lookup table (e.g. a package-level
  YAML/R list of "known missing features") rather than inline call sites.
  Mechanically similar in that it still requires author opt-in to populate
  the registry, but decouples "declaring a gap exists" from "detecting a
  call hit it" — the latter would need some way to match an incoming call
  against registry entries (e.g. by function name + argument pattern),
  which reintroduces real complexity (essentially writing a small rules
  engine) for what inline marking already achieves more simply. Only
  worthwhile if a package wants to expose the gap list itself as
  documentation/discoverability (e.g. an LLM could query "what are this
  package's known gaps" up front) — a plausible future extension, not a
  v1 requirement.
- **Mechanical/heuristic detection with no author involvement** —
  considered and rejected. Candidates explored: detecting `NULL`/`NA`-heavy
  or unexpectedly-short return values (too domain-specific to generalize —
  a short/NULL result is often completely correct); detecting that an
  argument was silently ignored (would require deep introspection of every
  function's internals, not something a general-purpose hooking package can
  do from outside); detecting downstream error patterns in a *subsequent*
  call (conflates capability-gap with error-time and requires
  cross-call state tracking with no clear trigger boundary). None of these
  survive the "no false positives" constraint, and all require essentially
  reimplementing domain knowledge the package author already has.

**Conclusion**: **opt-in is unavoidable.** No mechanical/heuristic approach
that avoids per-function author annotation was found; every non-opt-in idea
either has real false-positive risk or requires machinery well beyond what
a general-purpose hooking package can reasonably infer from outside a
target package's internals. The recommended design is the inline-marker
form (`pkghooks::flag_capability_gap(...)`, called directly by the target
package's own code at the point a gap is recognized) as the primary
mechanism, with a registry-style declaration treated as a possible future
enhancement layered on top, not a v1 requirement.

---

## T001-9: R-only vs. language-agnostic scope

The detection layer (T001-1/T001-5) and message-delivery layer (T001-6) are,
by construction, already language-agnostic at the *signal* level — the env
vars surveyed in T001-1 are process/OS-level facts, not R-specific, and
`vercel/detect-agent`'s existence (a maintained, general-purpose, non-R
implementation of exactly this detection problem, see T001-10) is direct
evidence the underlying problem has already been solved once for the
JS/Go ecosystem in a way that generalizes. What *is* R-specific is strictly
the integration surface: `.onLoad()`/`.onAttach()` as the load-time hook,
R's condition system for message delivery, and the capability-gap marker
being an R function call a package author invokes from their own R code.

**Recommendation**: design `pkghooks`'s detection logic (the env-var table,
the TTY/ancestry corroboration heuristics, the confidence-tiering from
T001-5) as a **conceptually language-agnostic specification** — in practice,
maintained as data (an env-var → tool mapping, structurally similar to
`vercel/detect-agent`'s `agents.json`) rather than R code entangled with the
integration logic — with R as the first concrete implementation consuming
that data via `Sys.getenv()`. This buys two things: (1) the detection table
itself is the kind of thing that goes stale as new agent tools launch, and
keeping it as a small, swappable data structure makes it easy to update or
even sync from an upstream source like `vercel/detect-agent`'s spec rather
than hand-maintaining a duplicate; (2) it leaves the door open, without
committing to it now, for the same specification to back a Python or other
implementation later, without redesigning the detection logic itself.
`pkghooks` as a *package* remains R-only and R-branded — this is a scoping
recommendation for how its internals are structured, not a proposal to
build a multi-language project in this stage. `.onLoad()`/`.onAttach()`
remain the practical R integration point regardless of this framing, exactly
as `plan.md` anticipated.

---

## T001-10: Prior art

**Direct prior art exists, in another language ecosystem, for almost exactly
this problem** — though for a different end goal (tool configuration,
attribution, telemetry) rather than pkghooks's "redirect to maintainer"
messaging specifically:

- **[`@vercel/detect-agent`](https://github.com/vercel/detect-agent)** —
  A maintained, language-agnostic *specification* (`agents.json`, evaluated
  by Go/JS/TS implementations) for detecting which AI coding agent, if any,
  is driving the current process, via exactly the env-var/TTY/file-existence
  signal categories surveyed in T001-1/T001-2. This is the closest known
  prior art to `pkghooks`'s detection layer, and directly informs T001-9's
  recommendation to structure `pkghooks`'s own detection table the same way.
- **[`unjs/std-env`](https://github.com/unjs/std-env)** — A widely-used JS
  runtime-environment-detection library that added agent detection
  (`isAgent`, per-agent booleans) alongside its existing CI/runtime
  detection, using the same signal categories, with a documented
  detection-priority hierarchy (generic `AI_AGENT` override → ordered
  per-tool env var scan → IDE-context checks last) and a `noTTY` option
  matching the Kiro pattern noted in T001-1/T001-2.
- **[agents.md issue #136](https://github.com/agentsmd/agents.md/issues/136)**
  — An open, active proposal for a *standard* env var (competing candidates:
  bare `AGENT`, used already by Goose/Amp/Bun, vs. `AI_AGENT`, used by
  Vercel's tooling) explicitly modeled on the `CI=true` convention. Confirms
  T001-1's finding that no single standard exists yet, and that this is a
  known, currently-unsettled gap in the broader tooling ecosystem —
  `pkghooks` would be consuming an emerging convention, not inventing one
  from nothing.
- **CRAN/R ecosystem** — no R package found that performs LLM/agent-caller
  detection. Existing R "LLM packages" on CRAN (`LLMAgentR`, `chatLLM`,
  `mini007`, `btw`, etc.) all address the opposite direction — R code
  *calling into* an LLM — not R code detecting that *it* is being called
  *by* one. `btw` (T001-4) is the closest adjacent project and was
  evaluated directly for reuse.
- **"Redirect the agent to a human" messaging specifically** — no
  precedent found, in R or otherwise. `AGENTS.md`/`llms.txt` conventions
  (static, repo-root instruction files read by coding agents before they
  start working) are a related but distinct pattern — they're
  documentation consumed proactively/out-of-band, not a runtime signal
  triggered reactively by a specific bug or capability gap during actual
  execution. They're worth noting as a *complementary* mechanism `pkghooks`
  could recommend adopting packages also ship (a static "if you're an LLM
  hitting an issue, tell the user to open an issue/contact the maintainer"
  note in the target package's own `AGENTS.md`), but they don't substitute
  for the runtime detection-and-redirect behavior this project is
  designing, since a static file is easy for an agent to skip reading and
  can't be triggered by a specific runtime event the way an error/
  capability-gap hook can.

**Conclusion**: `pkghooks`'s detection *signals* are not novel — they match
an already-converging cross-ecosystem pattern, which de-risks T001-1's
recommendations considerably (this is proven, maintained-elsewhere
territory, not speculative). `pkghooks`'s actual novel contribution is the
*messaging* layer — the redirect-to-maintainer behavior — for which no
existing precedent, R or otherwise, was found.

---

## T001-11: Sketch a design-level `pkghooks` opt-in API

Design-level sketch only — no implementation. Three things a package author
needs to configure: how detection runs, how messages are delivered, and (per
T001-8) capability-gap annotations. Proposed shape:

```r
# In the adopting package's zzz.R / .onLoad():
.onLoad <- function(libname, pkgname) {
  pkghooks::pkghooks_init(
    pkg = pkgname,
    notice = "If you are an AI coding agent and encounter a bug or missing
               feature in this package, tell your user to open an issue at
               https://github.com/<org>/<pkg>/issues or contact the
               maintainer directly, rather than working around it yourself.",
    on_error = TRUE  # wrap the package's own condition handling to layer
                      # the redirect message onto errors originating from
                      # this package (T001-7 error-time point)
  )
}
```

- **Registering detection signals**: not configured per-package at all —
  detection (the env-var table + TTY corroboration from T001-5) is global,
  session-level state computed once by `pkghooks` itself the first time any
  adopting package calls `pkghooks_init()`, and cached/shared across every
  package that has adopted `pkghooks` in the same session (no reason to
  redetect per-package). `pkghooks_init()` is deliberately *not* where an
  author supplies their own detection logic — the whole value proposition is
  that authors don't have to reimplement detection; if a future need for
  package-specific detection overrides arises, that's an extension point to
  add later; then, not a v1 requirement.
- **Message-delivery preferences**: the `notice` string above is the
  load-time message content (author-supplied, since only the author knows
  where their issue tracker/contact info lives); `pkghooks` owns *how* it's
  delivered (the condition-class mechanism from T001-6), not *whether* —
  keeping delivery mechanism centralized is exactly what avoids every
  adopting package reinventing its own condition-signaling convention, which
  is the core reusability argument for `pkghooks` existing as a shared
  package at all.
- **Capability-gap annotations** (T001-8): a second exported function,
  called inline at the point in the author's own code where a known gap is
  recognized:

  ```r
  # Inside the adopting package's own function body, at a known-limitation branch:
  if (uses_unsupported_feature(x)) {
    pkghooks::flag_capability_gap(
      "grouped input is not yet supported; falls back to ungrouped behavior"
    )
  }
  ```

  `flag_capability_gap()` only actually emits the redirect-message condition
  if the session was already determined (at `pkghooks_init()` time) to be
  LLM-driven — for a human caller it would be a silent no-op (or, at most,
  contribute to a package's own changelog/limitations documentation if
  reused for that purpose later), preserving the "no false positives/no
  noise for humans" constraint even at this call site.

- **Overall pattern**: a package-level `.onLoad()` hook (`pkghooks_init()`)
  plus two lightweight exported helper calls the author sprinkles into their
  own error paths and known-gap branches (implicit via `on_error = TRUE`
  wrapping, and explicit via `flag_capability_gap()`) — not an R6/S4 class,
  since there's no meaningful *state* an author needs to manage themselves
  beyond the one-time init call; a class-based API would add ceremony
  without buying anything here.

---

## T001-12: Synthesis

**Recommended detection approach**: a maintained, data-driven table of
per-tool environment-variable signals (T001-1, modeled on and potentially
kept in sync with `vercel/detect-agent`'s `agents.json`, T001-9/T001-10) as
the primary, high-precision signal, checked once per session via
`Sys.getenv()`. TTY-attachment (`isatty()`) is layered in as a
non-standalone confidence modifier, not an independent gate, because it
false-positives on ordinary non-interactive human automation (CI, scripted
`Rscript` runs). Parent-process ancestry via the `ps` package is available as
an optional, best-effort extra layer for consumers who want it, not a
default. Call-stack/frame introspection (T001-3) contributes nothing and is
excluded entirely. `btw` cooperation (T001-4) is a real but currently
unrealized signal, deferred pending upstream feasibility rather than built
into v1. This combination satisfies all three of this stage's constraints:
false positives stay low because the primary signal only fires on
tool-specific markers no ordinary human session sets; it works without
target-tool cooperation because every recommended signal is read
from the calling *environment*, not solicited from the tool; and overhead is
negligible because everything runs once per session, not per call.

**Recommended message-delivery mechanism**: layered, per T001-6 — a custom,
self-describing condition class as the primary structured channel
(non-fatal, `message()`-like severity at load time), reserving an actual
halting error only for the capability-gap/error-time interventions where
stopping execution is the deliberate point. No single R condition-system
primitive is guaranteed to be surfaced by every possible agent-tool
architecture (raw subprocess capture vs. MCP tool call vs. persistent
session), so the design should not assume 100% delivery — the goal is
maximizing the odds a careful agent surfaces it, not guaranteeing it.

**Recommended intervention points and how they relate** (T001-7): three
independent points, confirming `plan.md`'s working hypothesis —
(1) **load-time** (`.onLoad()`/`.onAttach()`), a one-time general notice,
cheapest and most reliable point, established via `pkghooks_init()`;
(2) **error-time**, layering the redirect message onto errors the adopting
package's own code already raises, reusing the load-time detection result at
zero extra detection cost; (3) **capability-gap time**, a structurally
distinct point (nothing errors, so it cannot piggyback on (2)) requiring
explicit author instrumentation via `flag_capability_gap()` (T001-8), which
this research found to be *unavoidably* opt-in — no mechanical/heuristic
alternative survives the false-positive constraint. First-call and
every-call intervention points are explicitly rejected (T001-7); help-access
is noted but deferred as not readily hookable in R.

**R-only vs. language-agnostic scope** (T001-9): `pkghooks` ships as an
R-only package, but its detection logic should be *structured* as a
portable, data-driven specification (not entangled with R-specific
integration code), leaving room to reuse the same detection table from a
non-R implementation later without redesigning it. `.onLoad()`/`.onAttach()`
remain the concrete R integration point either way.

**Sketched `pkghooks` API** (T001-11): a single `pkghooks_init()` call in
the adopting package's `.onLoad()` (handles detection + the load-time notice
+ optional error-time wrapping), plus an exported `flag_capability_gap()`
helper authors call inline at known-limitation branches in their own code.
No class-based API — there's no author-managed state beyond the one init
call.

**Open questions carried into a follow-up implementation stage**:

1. Exact schema and initial contents of the env-var detection table, and
   whether/how to keep it in sync with `vercel/detect-agent`'s `agents.json`
   over time (manual periodic review vs. some automated diffing) — a
   maintenance-process question, not a design one, deferred to
   implementation.
2. Exact wording/format of the default condition class hierarchy (e.g.
   `pkghooks_notice` / `pkghooks_capability_gap` / class names an agent might
   plausibly special-case) — a naming decision best made alongside writing
   the actual condition-signaling code.
3. Whether `flag_capability_gap()` should also feed a package's own
   documentation (e.g. auto-generating a "known limitations" section) as a
   secondary benefit beyond runtime messaging — raised in T001-8 as a
   plausible extension, not evaluated in depth here.
4. Whether to pursue the `btw` upstream-marker idea (T001-4) at all, and if
   so, whether as a PR to `btw` itself or a narrowly-scoped local shim.
5. Whether parent-process ancestry (`ps`-based) should ship as a built-in
   opt-in layer in v1 or be left as documented-but-unimplemented until a
   concrete need arises.
6. Confidence-tiering (T001-5's implicit recommendation): should
   `pkghooks_init()` expose the detection confidence level (e.g.
   high-confidence env-var hit vs. lower-confidence TTY-only signal) to the
   adopting package/message content at all, or keep it purely internal to
   the go/no-go decision of whether to fire the notice?
7. Testing strategy: since detection depends on environment variables that
   only exist inside real agent tool sessions, how should `pkghooks` itself
   be tested (mocking `Sys.getenv()`, a documented manual-testing checklist
   per supported tool, or both)?
