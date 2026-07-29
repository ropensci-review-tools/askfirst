---
created: 2026-07-29T10:56:39Z
agent: claude-sonnet-5
git_hash: 7ff6ec5d47e1e408e6188acecd8bdd43d2800d5a
---

# Design Decisions: nudge-agent-hooks-install

## Summary
Added a confidence-gated, agent-directed condition that fires alongside
stage 014's existing human-directed console nudge when askfirst agent
hooks are missing or stale, and used the opportunity to extract askfirst's
fixed, binding-emitted condition text out of R source into a new
binding-agnostic `agent-content/` directory, ahead of any second language
binding existing.

## New Design Decisions

### Decision 1: Agent-directed hooks nudge is additive, not a replacement
**Chosen:** A new `askfirst_hooks_nudge` condition class, using
`askfirst_signal()`'s existing notice shape, fires when hooks are
`not_installed`/`stale` **and** session confidence is `"high"` — alongside,
not instead of, the unchanged, unconditional human-directed
`cli::cli_inform()` nudge from stage 014. Both channels share the single
`hooks_nudge_shown` once-per-session flag.
**Rationale:** Stage 014's human-directed-only design was reasoned around
hook *context* being unreliable while hooks are missing; `askfirst_signal()`'s
condition channel has no such dependency and already reaches
agent-driven sessions for other signals.
**Tradeoffs:** None to the existing behavior; purely additive.
**Proposed by:** joint
**Relates to:** Stage 014, Decision 3 (the human-directed nudge this
extends)

### Decision 2: `agent-content/` as the binding-agnostic home for fixed condition text
**Chosen:** The hard-stop marker delimiters, stop-consequence text, and
notice-prime text — previously R string literals in `conditions.R` — were
extracted into a new top-level `agent-content/` directory, alongside the
new hooks-nudge text. `bindings/r/` consumes it via a sync-copy into
`bindings/r/inst/agent-content/` (mirroring `agent-detect-spec/vendor/`'s
established pattern) and reads it at runtime via `system.file()`.
**Rationale:** `agent-hooks/`'s symlink-based delivery (`bindings/r/inst/agent-hooks`)
escapes the `bindings/r/` package subtree and cannot survive being
packaged for distribution — already documented in `hooks_status.R`'s own
manifest-copy rationale. `agent-detect-spec/vendor/`'s sync-copy-and-check
mechanism solves exactly this problem already, and is the closer
precedent since this content, like that vendor data, is read by the
binding's own runtime rather than injected by a coding-agent-tool hook.
**Tradeoffs:** Retrofitting the three pre-existing fixed strings (not just
the new hooks-nudge text) enlarged this stage's diff, in exchange for not
leaving two conventions side by side in `conditions.R`.
**Proposed by:** git-user
**Relates to:** Stage 018 (canonical-content consolidation, but for
coding-agent-tool hook content rather than binding-runtime content)

### Decision 3: Local pre-commit hook, dedicated sync scripts, no remote workflow
**Chosen:** New `bindings/r/data-raw/sync-agent-content.R` /
`check-agent-content-sync.R`, structurally identical to but kept separate
from `sync-vendor.R`/`check-vendor-sync.R`. A new `.githooks/pre-commit`
(opt-in via `git config core.hooksPath .githooks`) runs both checks
locally; CI (`r-cmd-check.yml`) gained a parallel step as the enforced
backstop. No scheduled remote sync workflow (unlike
`sync-agent-detect-spec.yml`), since `agent-content/` is
askfirst-authored, not vendored from a third party.
**Proposed by:** git-user

### Decision 4: Unify marker-token prose with the same canonical source
**Chosen:** `agent-hooks/askfirst-context.txt`'s prose now references
`{{HALT_MARKER}}`/`{{RESUME_MARKER}}` placeholders instead of hand-typed
literal tokens; `generate-install-hooks.sh` renders them from
`agent-content/askfirst-markers.txt` — the same file `conditions.R` reads
at runtime — before splicing into the per-tool hook/plugin files.
**Rationale:** Removes the last remaining place where the marker-token
values were maintained independently of their new canonical source.
**Proposed by:** git-user

## Integration with Prior Work
Extends stage 014's hooks-installation detection without altering its
existing behavior. Follows stage 018's precedent of eliminating
hand-duplicated content, applied here to the binding-runtime side rather
than the coding-agent-tool-hook side stage 018 covered. Reuses stage
012/013's `askfirst_signal()` condition machinery unchanged in structure.

## Issues Resolved
- No channel existed for an agent-driven session to learn about missing
  hooks other than incidentally noticing a plain console message —
  resolved via the new confidence-gated `askfirst_hooks_nudge` condition.
- Fixed condition text existed only as R string literals, with no path for
  a future non-R binding to consume it without hand-porting — resolved via
  `agent-content/`.

## Deferred Items
None — all items raised during planning (retrofit scope, sync mechanism,
pre-commit enforcement, context-prose unification, test coverage,
design-decisions cross-referencing) were resolved and completed within
this stage.

## Process Notes
- The plan was substantially expanded mid-review, after initial approval,
  once the binding-agnostic-architecture implication was raised — the
  scope grew from a single new condition class to include a new top-level
  content directory, two new data-raw scripts, a new local git hook, and a
  cross-cutting edit to stage 018's `generate-install-hooks.sh` pipeline.
- The proposed sync mechanism changed during planning from dev-time
  R-codegen to runtime `system.file()` reads once the closer
  `agent-detect-spec/vendor/` precedent was found in the existing
  codebase.
