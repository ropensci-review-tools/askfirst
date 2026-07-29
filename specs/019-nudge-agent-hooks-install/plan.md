---
created: 2026-07-29T09:54:42Z
agent: claude-sonnet-5
git_hash: d612106394e2ac3d7bd514b7278fdff4649fa15e
---

# Plan: nudge-agent-hooks-install

## Overview

Add an agent-directed condition, signalled via `askfirst_signal()` alongside
the existing human-directed `cli::cli_inform()` console nudge from stage
014, so that when askfirst-aware agent hooks are missing or stale
(`askfirst_hooks_status()` returns `not_installed` or `stale`) and the
session is detected as high AI-agent confidence, the calling agent itself
receives a notice-shaped askfirst condition instructing it to tell the human
user to run `agent-hooks/install-agent-hooks.sh`. This complements (does not
replace) the existing unconditional human-directed nudge.

Because `bindings/r/` is currently askfirst's only language binding, but is
explicitly meant to be one of several (see `specs/002-design-agnostic-spec`),
this stage also extracts the **fixed, binding-agnostic condition/notice text**
that `bindings/r/R/conditions.R` currently hardcodes as R string literals —
the `<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>` marker delimiters, the
hard-stop consequence text, and the notice-prime text — plus this stage's own
new hooks-nudge text, into a new top-level `agent-content/` directory,
analogous in spirit to `agent-hooks/`'s canonical-content files but scoped to
content a *binding runtime* emits (R today, other languages later) rather
than content a *coding-agent-tool hook/plugin* injects. `bindings/r/`
consumes these canonical files the same way it already consumes
`agent-detect-spec/vendor/`: synced (copied, not symlinked) into
`bindings/r/inst/agent-content/` via a dedicated `data-raw/` script pair
(kept separate from the third-party-derived vendor sync), enforced by a new
local git pre-commit hook (no remote/CI sync workflow, since this content is
askfirst-authored, not fetched from upstream) as well as a CI check, and
read at runtime via `system.file()`. This stage also unifies
`agent-hooks/askfirst-context.txt`'s marker-token prose with
`agent-content/askfirst-markers.txt`, so the literal delimiter strings are
no longer hand-typed in two independently-maintained places.

## Context

**Stage 014** (`specs/014-self-sufficient-stop-signal`) introduced
`askfirst_hooks_status()` (`bindings/r/R/hooks_status.R`) — a hand-maintained
`agent-hooks/manifest.json` plus a `# askfirst-hook-version: <N>` marker line
per tool, reporting `"not_installed"`/`"stale"`/`"current"` for the current
project — and `askfirst_maybe_nudge_hooks_install()`, called once per session
from `askfirst_init()`, which prints a **human-directed-only**
`cli::cli_inform()` nudge toward `agent-hooks/install-agent-hooks.sh` when
status is `not_installed` or `stale`. That stage's explicit, documented
rationale (`specs/design-decisions.md`, "Hooks-installation detection..."):
gating the nudge on agent-confidence detection "would be self-defeating",
because hook context can't be relied on to reach an agent while hooks are
missing — an argument aimed at the *hooks themselves* (which inject context
via `.claude/hooks`/`.opencode/plugins` files) rather than at
`askfirst_signal()`'s own condition-based channel, which is independent of
whether hooks are installed and already reaches agents today for other
notices. This stage extends rather than overrules that decision: the
human-directed nudge is unchanged; a second, confidence-gated agent-directed
channel is added alongside it.

**Confidence detection** (`askfirst_ensure_detection()`, stages 001/002)
computes a session-wide `"low"`/`"medium"`/`"high"` LLM-caller-confidence
tier once per session, cached in `.askfirst_state$confidence`.
`askfirst_init()` already gates its own `askfirst_notice` condition on
`confidence == "high"` — the same gate this stage reuses for the new
hooks-nudge condition, rather than inventing a separate detection path.

**`askfirst_signal()`** (`bindings/r/R/conditions.R`, built up across stages
007, 011, 012, 013, 014, 015) is the single, existing mechanism by which
askfirst delivers structured, agent-readable conditions: a `type_map`/
`directive_map` keyed by condition class, a "notice" shape (used today only
by `"askfirst_notice"`) versus a "hard-stop" shape (used by the other three
classes), and delivery via `rlang::inform()`/`rlang::abort()`. This stage
adds a **fifth** class rather than repurposing an existing one, since the
hooks-nudge notice is not attributable to a specific adopting package's own
capability gap or scenario check — it is a project-wide hooks-installation
state, merely attributed to whichever `pkg` happened to trigger
`askfirst_init()` first in the session (matching how the existing
human-directed nudge is already triggered from inside that same call).

**Two existing, structurally different "canonical content" precedents
already exist in this repo, and this stage's binding-agnostic text belongs
with the second, not the first:**

- `agent-hooks/` (stage 012 onward, consolidated in stage 018): canonical
  prose/data files (`askfirst-context.txt`, `askfirst-reminder-messages.txt`,
  `askfirst-state-dir.sh`) consumed by `agent-hooks/generate-install-hooks.sh`,
  a dev-time **splicing** pipeline that renders them into each coding-agent
  tool's native syntax (bash for Claude Code, JS for opencode) and finally
  into the single-file `install-agent-hooks.sh`. This content is about what a
  *coding-agent tool's own hook/plugin* injects into an agent's context; nothing
  about it is R-specific or binding-specific.
- `agent-detect-spec/vendor/` (referenced from `bindings/r/R/detect.R`):
  canonical `agents.json`/`agents.schema.json`, synced — via
  `bindings/r/data-raw/sync-vendor.R` (`file.copy()`, not a symlink) — into
  `bindings/r/inst/agent-detect-spec/`, checked for drift in CI via
  `bindings/r/data-raw/check-vendor-sync.R`, and read at package runtime via
  `system.file("agent-detect-spec", "agents.json", package = "askfirst")` +
  `jsonlite::fromJSON()`. This is the established pattern for
  "repo-root canonical content that a specific language binding's *own
  runtime code* must read", as opposed to content a hook/plugin injects.

  The binding-emitted fixed strings in `conditions.R` (marker delimiters,
  stop-consequence text, notice-prime text, and this stage's new hooks-nudge
  text) are exactly this second kind of content: text an askfirst *binding*
  actually emits at runtime via its own condition-signalling code, which a
  second binding (Python, Rust, etc.) will need verbatim, not text a
  coding-agent tool's hook script injects. Following `agent-detect-spec/`'s
  precedent rather than `agent-hooks/`'s is also forced by a hard constraint
  already documented in `hooks_status.R`: `bindings/r/inst/agent-hooks` is a
  **symlink** to `../../../agent-hooks`, escaping the `bindings/r/` subtree
  entirely — fine for local monorepo development, but unable to survive
  being packaged into a distributable tarball whose root is `bindings/r/`
  itself (this is exactly why `askfirst_hooks_manifest()` hand-copies
  `manifest.json`'s data instead of reading the symlinked file at runtime).
  `agent-detect-spec/vendor/`'s sync-copy approach has no such problem, since
  the copied files physically live inside `bindings/r/inst/`.

**Relationship to `agent-hooks/askfirst-context.txt` (raised during
requirements gathering):** that file's prose already describes, in English,
the same marker-delimiter tokens and directive semantics that
`conditions.R`'s R constants implement operationally — today these are two
independently hand-maintained descriptions of the same contract, with
nothing enforcing they stay in sync. This stage does not fully unify them
(that would mean teaching `generate-install-hooks.sh`'s splicing pipeline to
pull literal token values out of `agent-content/` too, which is a
cross-cutting change to a pipeline stage 018 just finished consolidating);
see Open Questions.

## Design Goals

- Let high-confidence (agent-driven) sessions learn — via the same
  condition-signalling channel that already reaches them for
  `askfirst_notice`, capability-gap, and scenario-check signals — that this
  project's askfirst agent hooks are missing or stale, so the agent can
  proactively tell its human user to install/update them, rather than
  relying solely on a human noticing a plain console message that an
  agent-driven session may never surface to a human at all.
- Reuse existing architecture exactly: `askfirst_signal()`'s notice shape,
  the existing `askfirst_hooks_status()` check, and the existing
  once-per-session gating in `askfirst_maybe_nudge_hooks_install()` — no new
  detection mechanism, no new manifest field, no `hook_version` bump (this
  is a messaging-only change, not a change to what "current" hooks look
  like).
- Leave stage 014's human-directed nudge completely untouched in behavior:
  same trigger conditions, same unconditional (confidence-independent)
  firing, so humans running R directly without any agent involvement see
  exactly what they see today.
- Establish, now — while `bindings/r/` is still the only binding and the
  migration is small — a binding-agnostic home for askfirst's fixed
  condition/notice text, so a second binding can port `agent-content/`'s
  templates verbatim instead of reverse-engineering them from R source, and
  so this stage's own new hooks-nudge text doesn't become a *sixth* instance
  of the same hand-duplication-across-bindings risk stage 018 already fixed
  once, on the hooks side, for exactly this reason.
- Follow the existing `agent-detect-spec/vendor/` precedent (sync-copy +
  runtime `system.file()` read, not a symlink, not dev-time R-codegen) for
  how `bindings/r/` consumes `agent-content/`, since that precedent already
  solves the "installed package can't ship repo-root symlinks" constraint in
  a way proven to work in this exact codebase.
- Make it structurally impossible to commit a drifted `agent-content/` copy
  (a local pre-commit hook, checked in CI as a backstop) rather than relying
  on contributors remembering to re-run a sync script by hand.
- Remove the one remaining place (`askfirst-context.txt`'s prose) where the
  marker-delimiter token *values* are still hand-typed independently of
  `agent-content/`'s new canonical source, so the two descriptions of the
  same wire contract can no longer silently drift apart.

## Proposed Approach

**New directory `agent-content/`** (repo root, sibling to `agent-hooks/` and
`agent-detect-spec/`), holding one canonical template file per fixed
message, using the same `{{PKG}}`-style placeholder convention already
established by `agent-hooks/askfirst-reminder-messages.txt`:

- `askfirst-markers.txt` — the two delimiter tokens (`<<<ASKFIRST:HALT>>>`,
  `<<<ASKFIRST:RESUME>>>`), replacing `askfirst_stop_start_delimiter`/
  `askfirst_stop_end_delimiter`'s hardcoded R string literals.
- `askfirst-stop-consequence.txt` — the `{{PKG}}`-templated hard-stop
  consequence text, replacing `askfirst_stop_consequence()`'s `sprintf()`
  body.
- `askfirst-notice-prime.txt` — the `{{PKG}}`-templated notice-prime text,
  replacing `askfirst_notice_prime()`'s `sprintf()` body.
- `askfirst-hooks-nudge.txt` — this stage's new, `{{PKG}}`-templated
  hooks-nudge message text (the actual new user-facing feature), instructing
  the agent to tell its human user that this project has no current
  askfirst-aware agent hooks installed (or they are stale), and to run
  `agent-hooks/install-agent-hooks.sh` to install/update them — exact
  wording finalized during implementation.

**Sync into `bindings/r/`**, mirroring `sync-vendor.R`/`check-vendor-sync.R`'s
mechanism but in their own dedicated files, kept separate from the
third-party-derived vendor sync (resolved during requirements gathering:
`agent-content/` is askfirst-authored, `agent-detect-spec/vendor/` is
upstream-derived — same copy-and-check mechanism, distinct scripts so
neither concern's script accretes logic for the other):
- New `bindings/r/data-raw/sync-agent-content.R`, structurally identical to
  `sync-vendor.R` (`file.copy()`, not a symlink), copying `agent-content/*.txt`
  into `bindings/r/inst/agent-content/`.
- New `bindings/r/data-raw/check-agent-content-sync.R`, structurally
  identical to `check-vendor-sync.R`, verifying
  `bindings/r/inst/agent-content/` matches `agent-content/` byte-for-byte.
- `conditions.R` reads each file at runtime via
  `system.file("agent-content", "<file>.txt", package = "askfirst")` and
  substitutes `{{PKG}}` itself (a simple `gsub()`, matching the
  substitution style already used for `{{PKG}}`/`{{COUNT}}` elsewhere),
  replacing the current hardcoded `sprintf()` string literals in
  `askfirst_stop_start_delimiter`, `askfirst_stop_end_delimiter`,
  `askfirst_stop_consequence()`, and `askfirst_notice_prime()`. The
  **assembly logic** — how these pieces get glued into the notice vs.
  hard-stop shape inside `askfirst_signal()` — stays as R control flow; only
  the literal template text moves out.

**Local pre-commit hook enforces sync (resolved during requirements
gathering: no remote/CI workflow analogous to
`sync-agent-detect-spec.yml`'s scheduled remote sync is wanted here, since
`agent-content/` is askfirst-authored, not fetched from a third party — a
local guard against committing a drifted copy is enough):**
- New `.githooks/pre-commit` (repo-tracked, since `.git/hooks/` itself is
  never committed) runs `Rscript bindings/r/data-raw/check-agent-content-sync.R`
  (and, since it's already the same category of check, folds in
  `check-vendor-sync.R` too rather than running two near-identical checks
  from two different places) and aborts the commit non-zero if either
  reports drift, printing the same "run sync-agent-content.R and commit the
  result" guidance the CI job already prints.
- The existing CI job (`r-cmd-check.yml`'s `check-vendor-sync` step) gains a
  parallel `Rscript bindings/r/data-raw/check-agent-content-sync.R` step, so
  drift is still caught in CI for contributors who haven't opted into the
  local hook — the local hook is a faster/earlier check, not a replacement
  for CI enforcement.

**Unify `agent-hooks/askfirst-context.txt`'s marker-token prose with
`agent-content/askfirst-markers.txt` (resolved during requirements
gathering: do this now, not deferred)**, so the literal
`<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>` strings that
`askfirst-context.txt` currently hand-types are no longer an independent,
driftable description of the same contract `conditions.R` implements:
- `askfirst-markers.txt` uses the same `--- LEVELn ---`-style section-marker
  format `askfirst-reminder-messages.txt` already established (e.g. `---
  HALT ---` / `<<<ASKFIRST:HALT>>>` / `--- RESUME ---` /
  `<<<ASKFIRST:RESUME>>>`), so `generate-install-hooks.sh` can extract each
  token with the same `extract_reminder_raw()`-style awk logic already
  written for the reminder messages, rather than inventing a new extraction
  format.
- `askfirst-context.txt`'s prose is edited to reference the tokens via
  `{{HALT_MARKER}}`/`{{RESUME_MARKER}}` placeholders instead of the literal
  strings.
- `generate-install-hooks.sh` gains a preprocessing step (same
  `mktemp`-and-render pattern already used for the bash/JS reminder lines):
  read `agent-content/askfirst-markers.txt`, substitute both placeholders
  into a temp copy of `askfirst-context.txt`, and splice *that* rendered
  temp file into `session_start.sh`/`askfirst-plugin.js` — instead of
  splicing `askfirst-context.txt` directly, as it does today.
- Net effect: `agent-content/askfirst-markers.txt` becomes the single
  literal source for the two delimiter tokens, consumed by both
  `conditions.R` (via the `agent-content/` sync-and-`system.file()` path,
  for what R actually emits) and `generate-install-hooks.sh` (via a direct
  repo-root read, for what the prose describes) — the two descriptions can
  no longer drift apart on the token values themselves, even though they
  remain two separate files serving two different audiences (agent runtime
  output vs. coding-agent-tool context prose).

**New condition class** `"askfirst_hooks_nudge"` added to `conditions.R`'s
`type_map` (`type: "hooks_nudge"`) and `directive_map` (`directive:
"notice"`), using the existing notice shape (non-fatal, via
`rlang::inform()`) — no new shape logic needed.

**`askfirst_maybe_nudge_hooks_install()`** (`hooks_status.R`) gains a `pkg`
parameter (currently called with no arguments from `askfirst_init()`, which
already has `pkg` in scope as its own first argument). After the existing,
unchanged `cli::cli_inform()` call: if status is `"not_installed"` or
`"stale"` **and** `.askfirst_state$confidence` is `"high"`, additionally
call `askfirst_signal("askfirst_hooks_nudge", pkg = pkg, message =
<rendered askfirst-hooks-nudge.txt>)`.

**Single shared once-per-session flag**: both the human-directed
`cli::cli_inform()` call and the new `askfirst_signal()` call remain
governed by the one existing `.askfirst_state$hooks_nudge_shown` flag — they
fire together (or not at all) as two deliveries of the same underlying
event, rather than being tracked/silenced independently.

**No manifest/version changes**: `askfirst_hooks_manifest()`'s
`hook_version` and per-tool `hooks_dir`/`marker_file` entries are untouched;
this stage changes only what happens *after* a `not_installed`/`stale`
status is already detected, plus where the fixed text those signals carry
lives.

**Test coverage** (resolved during requirements gathering: in scope for this
stage, not deferred):
- `test-init.R`'s three existing hooks-nudge tests (`"askfirst_init prints a
  one-time hooks-install nudge..."`, `"...does not repeat the
  hooks-install nudge..."`, `"...does not print the hooks-install nudge when
  hooks are current"`) all set `.askfirst_state$confidence <- "low"`
  explicitly and assert only on the human-directed message text — these
  continue to pass unchanged (low confidence still means no new condition
  fires).
- New tests added covering the `confidence == "high"` branch specifically:
  the new `askfirst_hooks_nudge` condition fires when hooks are
  missing/stale under high confidence, and does not fire when hooks are
  current, or when confidence is not high (mirroring the existing
  `askfirst_notice` confidence-gating tests already in `test-init.R`).
- New tests for the `agent-content/`-reading/templating helpers in
  `conditions.R`, and for `sync-agent-content.R`/`check-agent-content-sync.R`
  (mirroring however `sync-vendor.R`/`check-vendor-sync.R` are currently
  tested or manually verified, if at all).

**Design-decisions forward-pointer** (resolved during requirements
gathering: in scope for this stage): once this stage's own
`design-decisions.md` is generated, add a short forward-pointing note to
stage 014's entry — both
`specs/014-self-sufficient-stop-signal/design-decisions.md` and the
aggregated `specs/design-decisions.md` ("Hooks-installation detection:
language-agnostic manifest and version marker, human-directed nudge") — so a
future reader of that entry in isolation isn't misled into thinking the
nudge is *still* human-directed-only, or that the fixed condition text is
*still* R-only, after this stage.

## Open Questions

- Exact wording of the new hooks-nudge message text, and of the
  `askfirst-context.txt` edits introducing the `{{HALT_MARKER}}`/
  `{{RESUME_MARKER}}` placeholders — to be finalized during implementation
  against the existing tone/style conventions already established in
  `conditions.R`, `hooks_status.R`, and `askfirst-context.txt` itself.
