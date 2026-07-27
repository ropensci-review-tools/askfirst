---
created: 2026-07-27T16:28:45Z
agent: claude-sonnet-5
git_hash: 34a7653f165cda18b283a70dad6cbca25db135b8
---

# Plan: contribute-upstream-guidance

## Overview
Improve final output messaging about upstream fixes: replace the vague generic 'the capability may belong in {pkg} itself' framing with a concrete invitation naming askfirst and, when the package maintainer supplies them, explaining how and where to contribute.

## Context
Two of askfirst's own generated message strings currently end on a vague, unattributed note rather than a concrete invitation:
- `askfirst_build_notice()` (`bindings/r/R/scenarios.R`): "...the capability may belong in `{pkg}` itself."
- `askfirst_build_scenario_check_message()` (same file): "...whether this capability should be added to `{pkg}` itself..."

Neither names `askfirst` itself, nor gives a human any concrete next step. The request that started this stage: replace this with something like "The developers of `<pkg>` use the 'askfirst' system, which suggests they might be able to fix this in their own package. You are invited to contribute by ...", with the "by ..." part coming from maintainer-supplied guidance rather than being invented generically.

Directly relevant prior decisions:
- **Stage 007** (`specs/design-decisions.md`, "Messaging format" key decision): message text signalled by an adopting package stays neutral/non-imperative/non-second-person, because it originates from a potentially untrusted, spoofable package call — directive-strength instruction lives in the trusted `agent-hooks/` context instead, not in message text. This stage's new "contribute" text must stay *factual/descriptive* (what the situation is, what the maintainer offers) rather than a second-person imperative instruction to the agent, the same way `notice` and `scenarios` text already do today — see the next bullet for why the literal "You are invited to contribute" phrasing from the original request does not, in fact, satisfy this on its own.
- **Referent ambiguity of "you" (identified during plan review, not yet resolved when the draft above was written):** the *agent* is the direct reader of this message text — it is not a human reading over the agent's shoulder. A bare "you are invited to contribute" is therefore not merely a stage-007-style second-person-tone concern; it is actively ambiguous about *who* is being invited. Read literally by the agent processing the text, "you" defaults to referring to the agent itself, not the human the invitation is actually meant for. That misreading is worse than stylistically off: it could lead an agent to conclude *it* has been invited to go open an upstream PR unsupervised — precisely the kind of autonomous action askfirst exists to route through the human first. Every sentence in the new "contribute" text must therefore name its addressee explicitly (e.g. "the human user" or "the maintainer's contribution process") rather than relying on an unqualified "you", regardless of who ends up reading the relayed text downstream.
- **Stage 012** (just completed): hardened the mechanism around *whether* an agent stops to ask before implementing a workaround (halting `askfirst_check_scenarios()`, severity-differentiated `directive:` field, hook guidance forbidding workaround-as-menu framing). This stage is unrelated to that mechanism — it only changes the *content* of what gets said once the agent has already stopped and is relaying the situation to the human, i.e. the "why" framing, not the "must stop" gating. `askfirst_check_scenarios()`'s halting behavior (stage 012) and this message-content change compose independently: the message text below is what gets carried inside the `askfirst_scenario_check` condition that now halts.
- **Stage 004** (scenario-check design): `askfirst_check_scenarios()` exists precisely because there's no mechanical way for `askfirst` to detect an agent about to duplicate package functionality — the self-check relies on message content being persuasive/informative enough for an agent to act on and relay faithfully. Concrete, attributed guidance serves that same goal better than generic prose.

Design decisions already confirmed with the user via `AskUserQuestion` before writing this plan:
1. **Scope**: the new concrete invitation replaces text in exactly two places — the load-time notice's generic reminder (`askfirst_build_notice()`) and the `scenario_check` message (`askfirst_build_scenario_check_message()`). `askfirst_capability_gap()` (author-supplied message, no askfirst-added boilerplate today) and `askfirst_error_redirect` (deliberately reuses raw `notice` text verbatim, per stage 003) are explicitly **out of scope** for this stage.
2. **No per-call override**: `askfirst_capability_gap()` is out of scope anyway (per decision 1), so the per-call-override question is moot; if capability_gap ever gains this messaging in a future stage, it will inherit the package-level values registered via `askfirst_init()`, not take its own override parameters.
3. **Fallback framing**: even when a maintainer supplies neither new field, the message still names `askfirst` generically ("The developers of `{pkg}` use the 'askfirst' system, which suggests they may be able to fix this in their own package") — it just omits the concrete "how"/"where to contribute" sentences. The message never silently reverts to today's fully generic, unattributed wording.

## Design Goals
- **Replace vague, unattributed framing with a concrete, attributed one, in the two in-scope message-generating functions.** Every high-confidence session that sees the load-time notice or the `scenario_check` halt message should see `askfirst` named as the reason this capability-gap question is even being raised, not a bare "may belong in `{pkg}` itself."
- **Let maintainers supply concrete "how" and "where" guidance, both optional.** Add `contribute_how` (free text, e.g. "Open an issue describing the gap, or a PR against `main` following `CONTRIBUTING.md`") and `contribute_url` (a single URL, e.g. a repo's issues page or `CONTRIBUTING.md` link) to `askfirst_init()`. Both default to `NULL` — no breaking change for existing adopters, and a package can supply either, both, or neither.
- **Keep the two in-scope messages internally consistent with each other.** Both should build the "contribute" portion of their text via one shared internal helper, so wording never drifts between the load-time notice and the scenario-check message the way stage 011 found the scenario bullet lists had.
- **Preserve the stage-007 message-text trust boundary.** The new text remains factual/descriptive (what askfirst is, what the maintainer offers), not a second-person imperative instructing the agent what to do — consistent with how `notice` and `scenarios` text are already written, and with why directive-strength instruction lives in `agent-hooks/` rather than in message text.
- **Never address the reader as "you" in the new text.** The agent is the direct reader/parser of this message, not the human it's meant for — an unqualified "you" defaults to being read as addressing the agent itself, which is actively wrong here (the invitation is for the human, and a misread invitation could plausibly lead an agent to go open an upstream PR unsupervised). Every sentence must name its addressee explicitly (e.g. "the human user") so the text reads correctly regardless of whether the agent relays it verbatim or the human somehow sees it directly.

## Proposed Approach

### 1. Add `contribute_how`/`contribute_url` parameters to `askfirst_init()`
- `bindings/r/R/init.R`: add `contribute_how = NULL` and `contribute_url = NULL` parameters to `askfirst_init(pkg, notice, on_error = TRUE, scenarios = character(), ...)`. Validate each as `NULL` or a single string (mirroring the existing `stopifnot()` checks for `pkg`/`notice`/`scenarios`).
- Store both in the package registry entry (`.askfirst_state$packages[[pkg]]`) alongside the existing `notice`/`on_error`/`scenarios` fields.
- Update the roxygen docs (`@param` entries) with guidance on what makes good `contribute_how` text (concrete and actionable, e.g. naming a specific process) and confirming `contribute_url` is a single URL, both optional.

### 2. Add a shared "contribute line" builder
- `bindings/r/R/scenarios.R`: add an internal helper (e.g. `askfirst_build_contribute_line(contribute_how, contribute_url)`) that always returns a sentence naming `askfirst` and `{pkg}` (glue-interpolated later at signal time, same pattern as the rest of these builder functions), optionally followed by a sentence naming the human user explicitly when `contribute_how` is supplied (e.g. "The human user is invited to contribute: `{contribute_how}`." — not "You are invited..."; see the referent-ambiguity note in Context/Design Goals), and a "Contribution guide: `{contribute_url}`" sentence when supplied (using distinct wording from the trailing `See: <askfirst-url>` line `askfirst_signal()` already appends to every message, to avoid the two URLs reading as the same thing).
- Both `askfirst_build_notice()` and `askfirst_build_scenario_check_message()` call this one helper, so the "contribute" framing can't independently drift between the two messages the way stage 011 found the scenario-bullet duplication had.

### 3. Wire the new fields through the two in-scope message builders
- `askfirst_build_notice(pkg, notice, contribute_how, contribute_url)`: replace the current generic closing clause ("...the capability may belong in `{pkg}` itself.") with a call to the new helper. `askfirst_init()` passes the registered `contribute_how`/`contribute_url` through when calling this at load time.
- `askfirst_build_scenario_check_message(scenarios, contribute_how, contribute_url)`: replace the current header's closing clause ("...whether this capability should be added to `{pkg}` itself...") similarly. `askfirst_check_scenarios()` reads `info$contribute_how`/`info$contribute_url` from the registry entry (the same `info` list it already reads `scenarios` from) and passes them through.

### 4. Update docs
- Roxygen `@return`/`@examples` blocks on `askfirst_init()` and `askfirst_check_scenarios()` touched by the wording change.
- `bindings/r/vignettes/using-askfirst.Rmd`, section "1. Registering your package": add `contribute_how`/`contribute_url` to the example `.onLoad()` call and explain what they're for, alongside the existing `notice`/`scenarios`/`on_error` explanations.
- `bindings/r/man/*.Rd`: regenerate via `roxygen2::roxygenise()` once source docblocks are updated (per the pattern established in stage 012).

### 5. Tests
- `bindings/r/tests/testthat/test-init.R`: registry stores `contribute_how`/`contribute_url` when supplied; defaults to `NULL` when omitted; validation rejects non-string/non-`NULL` values.
- `bindings/r/tests/testthat/test-scenarios.R`: load-time notice and scenario-check messages include the concrete invitation text when `contribute_how`/`contribute_url` are registered, include the generic-but-attributed fallback framing when neither is registered, and correctly include only the "how" or only the "url" sentence when just one is supplied.

## Open Questions
None outstanding — scope, override behavior, and fallback framing were all resolved via `AskUserQuestion` before this plan was written. One implementation-level detail intentionally left open for `/designlens.make-tasks`/implementation to settle rather than over-specifying here: the exact sentence wording for the "contribute" helper (the plan above gives representative draft text, not final copy).
