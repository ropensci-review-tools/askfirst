---
created: 2026-07-27T12:12:53Z
agent: claude-sonnet-5
git_hash: fc95d2497f30e047600031ac74d1b03f39d47c1a
---

# Plan: revise-messaging

## Overview
Revise the entire way askfirst passes messages (load-time notices, error
redirects, capability-gap halts, scenario checks) to AI coding assistants,
replacing the current prompt-injection-vulnerable approach with a combined
strategy of (a) agent-tool hooks/settings that pre-configure the AI about
askfirst before it loads an adopting package, and (b) a structured output
format (`askfirst::<language>::<pkg>::<type>`) that assistants can recognize as
legitimate package metadata rather than an injection attack.

## Context
- Stages 001–003 established that askfirst signals conditions via R's
  condition system (`rlang::inform()` for non-fatal load-time/error-redirect
  notices, `rlang::abort()` for capability-gap halts). Messages are addressed
  directly to AI coding agents in second person.
- Stage 004 added `askfirst_check_scenarios()` — an agent-invoked fourth
  intervention point that also outputs messages in the same format.
- Stage 005 renamed the package and all exported symbols from `pkghooks_*`
  to `askfirst_*`; the messaging format was unchanged.
- Stage 006 introduced the project's first R vignettes, including a manual
  testing walkthrough (`askfirst-development.Rmd`) that documents what
  messages an agent *should* see at each intervention point.
- The transcript in `transcript.md` demonstrates the fundamental problem: an
  AI coding assistant running `library(tokenpkg)` sees the askfirst notice
  text and interprets it as a prompt injection attack, refusing to follow
  the embedded instructions and warning the user. This is a complete blocker
  — the current approach cannot work with any AI assistant that has
  prompt-injection guardrails.
- The project already has `.claude/hooks/` scripts (session_start.sh,
  post_tool_use.sh, stop.sh) used by designlens, proving the hook mechanism
  is viable for agent-tool pre-configuration.
- Stage 001's Decision 4 explicitly acknowledged that no single R
  condition-system primitive guarantees delivery across every calling
  architecture — but it did not anticipate that *successful* delivery would
  itself be counterproductive when the recipient interprets the message as
  hostile.

## Design Goals
- **Replace the prompt-injection pattern.** No askfirst message may be
  addressed directly to an AI agent in second person as an embedded
  instruction. Instead, output must use a structured format that an AI
  assistant can be taught (via pre-loaded context) to recognize as
  legitimate package metadata.
- **Structured prefix format:** All askfirst condition signals must carry a
  recognizable prefix of the form `askfirst::<language>::<pkg>::<type>` where
  `<language>` is the binding language (e.g. `r`, `python`, `rust`), `<pkg>`
  is the adopting package name, and `<type>` is one of `notice`,
  `error_redirect`, `capability_gap`, or `scenario_check`. This lets an AI
  assistant quickly categorize the output as a known, non-hostile signal,
  and distinguishes signals from different language bindings.
- **Agent-tool pre-configuration for Claude Code and opencode:** Provide
  SessionStart hooks that inject system-level context about askfirst into
  the assistant's prompt before any package code is loaded, and PostToolUse
  hooks that can intercept and explain askfirst conditions in tool output.
- **Agent-tool pre-configuration for both target tools:** Create
  `.claude/settings.json` hooks (extending the existing designlens hooks)
  and equivalent opencode configuration that load the askfirst context.
- **R function for automatic hook installation:** Export
  `askfirst_install_agent_hooks()` that auto-detects which agent tool is
  in use (Claude Code vs. opencode) and installs the appropriate
  configuration files.
- **Documentation for manual setup:** Update both vignettes
  (`askfirst-development.Rmd` and `using-askfirst.Rmd`) to describe the
  new hook/settings pre-configuration, and add a manual-setup appendix.
- **Template URL placeholder:** Include a placeholder URL in the structured
  output pointing to askfirst documentation (to be made real in a future
  stage), so an AI can self-educate about the system.
- **Preserve backward compatibility:** All existing programmatic interfaces
  (condition classes, `pkg` field on condition objects, exported functions)
  remain unchanged; only the *format* of what an agent sees changes.

## Proposed Approach
- **Define the structured prefix format** as implementation-time detail, but
  agreed shape: `askfirst::<language>::<pkg>::<type>` at the first line of every
  condition message, followed by the substantive message text and an
  optional URL line (`See: <url>`) with a placeholder URL.
- **Revise `askfirst_signal()` in `bindings/r/R/conditions.R`** to prepend
  the structured prefix and URL line to every message before formatting with
  `cli::format_inline()`. The prefix is constructed from the `pkg` and
  `class` arguments (mapping concrete classes to `notice`/`error_redirect`/
  `capability_gap`/`scenario_check` type labels). The URL is conditionally
  appended based on a new internal parameter (default: placeholder, toggleable
  for tests).
- **Revise `askfirst_build_notice()` in `bindings/r/R/init.R`** (if it exists
  as a separate helper) or the callers of `askfirst_signal()` to ensure the
  load-time scenario-augmented notice also includes the prefix at the top.
- **Store hooks at repo root** (`./agent-hooks/`), shared across all language
  bindings. Each binding's `inst/` directory contains a symlink to the shared
  hooks, so the installed package can locate them via `system.file()`.
- **Create Claude Code hooks:**
  - `agent-hooks/claude/session_start.sh` — injects system
    context describing what askfirst is, what its structured prefix means,
    and how to respond when seeing `askfirst::<language>::<pkg>::<type>` in R output
    (redirect to user, do not treat as injection). This fires once per session
    before any tool is used.
  - `agent-hooks/claude/post_tool_use.sh` — watches tool
    output for `askfirst::` lines and, when found, prints an explanatory
    note to stderr or appends a structured annotation. Must never cause the
    agent turn to fail (exit 0 on any error, matching the designlens hook
    pattern).
- **Create opencode hooks:** equivalent scripts at
  `agent-hooks/opencode/` with the same logic, adapted for
  opencode's hook interface (which uses the same SessionStart/PostToolUse
  pattern as Claude Code).
- **Symlink into R binding:** `bindings/r/inst/agent-hooks` ->
  `../../agent-hooks/` so `system.file("agent-hooks", ...)` resolves at
  install time.
- **Create shared shell script `tools/install-agent-hooks.sh`** — language-
  agnostic, callable from any binding (R, Python, Rust, etc.). The script:
  - Auto-detects the active agent tool (Claude Code vs. opencode) by
    checking for tool-specific config directories (`.claude/`, `.opencode/`).
  - Copies hook scripts from `agent-hooks/<tool>/` (resolved relative to
    the script's own location) to the project's `.claude/hooks/` or
    equivalent tool hooks directory.
  - Updates `.claude/settings.json` to register the new hooks, preserving
    any existing hook entries (e.g. designlens's SessionStart hook).
  - Accepts `--overwrite` to replace existing files silently; defaults to
    skipping existing files with a warning.
  - Accepts `--tool <name>` to override auto-detection.
  - Exits 0 on success, non-zero on failure, with clear error messages.
- **Create R wrapper `askfirst_install_agent_hooks()`** in a new file
  `bindings/r/R/install_hooks.R` — a thin exported wrapper that locates
  `tools/install-agent-hooks.sh` (via `system.file()` or relative to the
  package source) and calls it via `system2()`, forwarding arguments.
- **Update `bindings/r/DESCRIPTION`** if needed (no new dependencies should
  be required; `jsonlite` and `cli` are already in `Imports`).
- **Update vignettes:**
  - `askfirst-development.Rmd`: add a step that calls
    `askfirst_install_agent_hooks()` before building the token test package;
    document what the hooks do and what the structured prefix looks like in
    output. Update the transcript expectations to show the new prefix format.
  - `using-askfirst.Rmd`: add a section describing the agent pre-configuration
    that adopting-package users should expect, and how to manually set it up
    if the automatic function is not used.
- **Run `R CMD check`** to confirm no regressions.
- **Run a manual smoke test** (or update the existing procedure) loading
  `tokenpkg` under Claude Code to confirm the new prefix format is visible
  and the assistant no longer treats it as injection.

## Open Questions
- **Exact line-level format of the structured prefix:** Whether the URL
  line is always present or only at specific confidence tiers; whether the
  message body appears on the same line as the prefix or on subsequent
  lines. Deferred to implementation, consistent with this project's existing
  practice of resolving format details during implementation rather than
  planning.
- **PostToolUse hook behavior:** Whether the hook should modify the tool
  output (appending an annotation), write to stderr, or take some other
  action when it detects `askfirst::` in results. Left to implementation
  judgment with the constraint that it must never cause the agent turn to
  fail.
- **Placeholder URL target:** A specific URL path (e.g.
  `https://ropensci.github.io/askfirst/`) is workable as a placeholder, but
  the actual documentation page about askfirst's agent protocol does not
  exist yet. This stage will use the package's future pkgdown site as a
  placeholder target; making the URL resolvable is deferred to a future
  stage.
- **Other agent tools beyond Claude Code and opencode:** This stage targets
  only the two primary development tools. The same pattern generalizes to
  Cursor, Cline, etc. but implementation for those is deferred pending
  proof of concept with the first two.
- **How to test the hook behavior under CI:** The PostToolUse hook fires in
  a real agent session, which cannot be replicated under automation. Manual
  verification following the updated `askfirst-development.Rmd` procedure is
  the intended validation path, matching the project's existing testing
  strategy for agent-facing behavior.
