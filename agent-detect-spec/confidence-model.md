# Confidence Model

This document specifies a language-agnostic confidence-tiering model for
LLM/AI-agent-caller detection. It is layered on top of `vendor/agents.json`
(vendored verbatim from `vercel/detect-agent`, see `README.md`), which
identifies *which* tool is calling but carries no concept of confidence
itself. Any implementation consuming `agent-detect-spec` (R or otherwise)
maps its own detection lookup onto this tier enum, so that downstream
behavior (e.g. whether/how to fire a redirect message per
`intervention-model.md`) is driven by a consistent, language-neutral scale
rather than each implementation inventing its own.

## Tier enum

A closed enum for v1: `high`, `medium`, `low`, `cooperative`.

Closed rather than open/extensible because a small, fixed set is simpler for
every consuming implementation to reason about and switch on, and adding a
new tier later is an additive, non-breaking change to the enum — there is no
cost to starting closed that isn't recoverable.

## Mapping rules

Given the current process/environment, evaluate in this order:

1. **`high`** — the environment matches any entry in `vendor/agents.json`
   (first-match-wins, per upstream's own evaluation order). This is the
   primary, high-precision signal: these markers are set by the calling
   tool's own process spawning and require no cooperation from the target
   package's users, so a match here is treated as confident regardless of
   whether any corroborating signal is also present.
2. **`medium`** — no `vendor/agents.json` entry matched, but a corroborating
   signal is present: no TTY attached to stdin/stdout, and/or process
   ancestry matches a known agent-tool binary name. This is ambiguous
   non-interactive automation — it may be an agent tool not yet covered by
   the vendored data, or it may be ordinary human CI/scripted automation,
   since TTY/ancestry alone false-positive on plain, non-agent CI or
   scripted runs — hence `medium`, not `high`.
3. **`low`** — no signals present at all: a TTY is attached and no vendored
   entry matched. Treated as the default human/interactive assumption.
4. **`cooperative`** — reserved for a future signal in which the calling
   tool itself explicitly announces agent-driven status to the target
   package (e.g. a hypothetical marker exposed by an R context-sharing
   tool such as `btw`'s MCP server; no such marker currently exists in any
   known tool integration). No lookup path currently produces this tier;
   it is included in the enum now purely so
   that adding one later is additive rather than a breaking schema change.
   A `cooperative` result, once real, should be treated as at least as
   confident as `high`, since it removes ambiguity entirely rather than
   inferring it from process/environment facts.

## Non-goals

This document does not specify *how* a given language reads TTY state or
walks process ancestry (R's approach, via `isatty()` and the `ps` package,
is R-specific and is left to individual implementations) — only the tier
outcomes and the rules for assigning them once those checks have been
performed.
