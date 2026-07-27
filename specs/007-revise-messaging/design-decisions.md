---
created: 2026-07-27T12:32:25Z
agent: claude-sonnet-5
git_hash: 159764dd12ea1465a1eafa4bcd91bfc815c1a30b
---

# Design Decisions: revise-messaging

## Summary
Replaced askfirst's prompt-injection-vulnerable second-person condition messages with a structured `askfirst::<language>::<pkg>::<type>` prefix format, and introduced pre-configured agent-tool hooks (SessionStart and PostToolUse for Claude Code and opencode) at a shared, language-agnostic `agent-hooks/` location with a common installation script at `tools/install-agent-hooks.sh`.

## New Design Decisions

### Decision 1: Structured prefix `askfirst::<language>::<pkg>::<type>`
**Chosen:** Every condition signal from `askfirst_signal()` now prepends a line of the form `askfirst::r::mypkg::notice` (with language, package name, and signal type) and appends a `See: <url>` line, before `cli::format_inline()` rendering. A `prefix = FALSE` parameter is available for tests.
**Rationale:** AI assistants can be taught (via pre-loaded hook context) to recognise this prefix as a legitimate, non-hostile signal. The language component (`r`, `python`, `rust`) distinguishes bindings in a multi-language project.
**Tradeoffs:** Adds fixed overhead of two lines to every signal; the placeholder URL is unresolvable until pkgdown documentation is published.
**Proposed by:** joint

### Decision 2: Shared, root-level agent hooks directory
**Chosen:** Hook scripts live at `agent-hooks/claude/` and `agent-hooks/opencode/` at the repo root. Each binding's `inst/` directory contains a symlink (`inst/agent-hooks` -> `../../../agent-hooks/`) so `system.file()` resolves the hooks at install time.
**Rationale:** Hooks are language-agnostic; a single source of truth avoids drift between R, Python, and future bindings.
**Tradeoffs:** Symlinks in `inst/` may be fragile under `R CMD build` depending on platform; confirmed resolving correctly for this stage.
**Proposed by:** agent

### Decision 3: Shared shell script for hook installation, thin R wrapper
**Chosen:** `tools/install-agent-hooks.sh` is a standalone shell script that auto-detects the agent tool (Claude Code or opencode), copies hook scripts, and updates `settings.json` via `jq`. The exported R function `askfirst_install_agent_hooks()` is a thin wrapper that locates the script via `system.file()` and calls it with `system2()`.
**Rationale:** Hook installation is fundamentally file/JSON operations best done in shell. A single script serves all language bindings without reimplementing installation logic per binding.
**Tradeoffs:** Requires `jq` for automatic settings registration; warns if unavailable and instructs manual setup.
**Proposed by:** mpadge

### Decision 4: Neutral, non-instructive message framing
**Chosen:** Removed second-person address ("If you are an AI coding agent...", "ask your user") from all generic notice and scenario-check message templates, replaced with factual descriptions of what the capability check does.
**Rationale:** The structured prefix and pre-loaded hook context handle identification; the body should describe the mechanism rather than issuing embedded instructions that trigger prompt-injection guardrails.
**Tradeoffs:** Messages become slightly less direct, but the hook context already tells the AI how to respond.
**Proposed by:** joint

## Integration with Prior Work
Replaces the pre-existing messaging layer established in stage 003 (which used `rlang::inform()`/`rlang::abort()` with second-person embedded instructions). Builds on the four-intervention-point architecture from stages 003–004 and the vignette infrastructure from stage 006. The `agent-hooks/` directory follows the same root-level shared pattern as `agent-detect-spec/` (set in stage 002), using symlinks into `inst/` for R package distribution following the same approach as the vendored detection data (stage 003).

## Issues Resolved
- Prompt-injection rejection by AI assistants (from transcript.md): resolved by introducing structured prefix and pre-loaded hook context
- Second-person message framing causing guardrail triggers: resolved by shifting to neutral, descriptive text
- Need for binding-agnostic hook installation: resolved by shared shell script at `tools/install-agent-hooks.sh`

## Deferred Items
- Resolvable URL target for `See: <url>` — placeholder `https://ropensci.github.io/askfirst/` used; actual protocol documentation page deferred until pkgdown publishing
- Other agent tools (Cursor, Cline, etc.) — hook patterns generalise but implementation deferred pending proof of concept
- PostToolUse hook exact output format — left to implementation judgment with the constraint of never failing

## Process Notes
- The shared shell script approach was adopted mid-stage after user direction, replacing the original plan of an R-only installation function
- The symlink path needed correction during implementation: `bindings/r/inst/agent-hooks` -> `../../../agent-hooks/` (three levels up to repo root) was required, not `../../agent-hooks/`
- The em dash character in scenarios.R triggered a non-ASCII R CMD check warning and was replaced with ASCII hyphens
- All pre-existing test failures (4 detect tests from OPENCODE env var in the test environment) are unrelated to this stage
