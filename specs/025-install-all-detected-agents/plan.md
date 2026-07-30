---
created: 2026-07-30T14:27:58Z
agent: claude-sonnet-5
git_hash: e55c550fcff857676098d5603b7a3fc74e231db9
---

# Plan: install-all-detected-agents

## Overview
Revise the agent-hooks installer and R binding so hook installation detects
and installs for all present agent tools (not just one), falls back to an
interactive prompt naming the available tools when none are detected,
sources the list of available tools from `agent-hooks/manifest.json` instead
of hardcoding tool names, and un-exports `askfirst_detect_agent_tool()` from
the R package's public API now that `askfirst_install_agent_hooks()` handles
detection internally.

## Context
- `agent-hooks/install-agent-hooks.sh`'s `detect_tools()` currently only ever
  checks for `.claude/settings.json`; opencode is never auto-detected and
  must always be selected via `--tool opencode` (a deliberate decision from
  stage 019, on the grounds that opencode's config file is discovered via a
  precedence order across several possible locations rather than a single
  fixed path). Because of this, the script's existing "multiple tools
  detected" branch — an interactive `select` prompt letting the user choose
  **one** of the detected tools — can never actually trigger today; it is
  effectively dead code.
- The "zero tools detected" case is a hard error today (`exit 1`, telling the
  user to pass `--tool <name>` explicitly) rather than any kind of
  interactive fallback.
- `bindings/r/vignettes/using-askfirst.Rmd`'s own documented example (section
  "0. Pre-configuring agent tools") has a latent, never-exercised bug that
  motivated this stage: it hardcodes calling
  `askfirst_install_agent_hooks("claude")` then `askfirst_install_agent_hooks("opencode")`
  whenever `length(tools) > 1`, regardless of what `tools` actually
  contains, and does nothing at all when `length(tools) == 0`.
- `agent-hooks/manifest.json` (introduced stage 014, extended stage 017)
  already hand-maintains exactly the set of tools the installer supports,
  each with a `hooks_dir` and `marker_file` — a ready-made, non-hardcoded
  source for "which tools exist" that nothing currently reads for
  detection/validation/prompting purposes.
- `agent-hooks/install-agent-hooks.sh`'s own header states it is
  self-contained "regardless of whether `agent-hooks/` exists at the call
  site" — true today because hook-script bodies are embedded inline via
  heredocs. Stage 024's `install.sh` relies on exactly this: it `curl`s only
  `agent-hooks/install-agent-hooks.sh` itself, not the rest of
  `agent-hooks/`, so `agent-hooks/manifest.json` is **not** present on disk
  in that invocation shape. A naive `--list-tools` mode doing a live `jq`
  read of `agent-hooks/manifest.json` would work from a full checkout but
  silently have nothing to read via the one-liner — the primary path this
  effort targets. `bindings/r/R/hooks_status.R` already hit the same
  constraint for a different reason (the installed R package doesn't ship
  the repo-relative `agent-hooks/` directory) and solved it with a
  hand-maintained, manually-synced hardcoded copy
  (`askfirst_hooks_manifest()`) — exactly the kind of duplication this stage
  is trying to move away from for the tool list, not add a second instance
  of.
- Checked against opencode's own current documentation
  (`https://opencode.ai/docs/config#locations`) during this stage's planning:
  config is discovered from multiple locations that are all read and merged
  (not first-match-wins), including project-level `opencode.json` and
  `.opencode/` directories (higher precedence than the global
  `~/.config/opencode/`). askfirst's own installer never reads or writes
  `opencode.json` — it only ever installs into `.opencode/plugins/`
  (auto-discovered by opencode, confirmed stage 017) — so a project-level
  `.opencode/` directory's mere existence is both a reliable and directly
  relevant signal that opencode is in use for this project, without needing
  to check `opencode.json` or traverse upward toward a `.git` root.
- `install.sh`/`install.ps1` (stage 024) invoke
  `agent-hooks/install-agent-hooks.sh` via `curl ... | bash` (and,
  respectively, a piped-through-bash equivalent on Windows). In that
  invocation shape, the script's stdin is the piped script source itself,
  not a terminal — any interactive prompt attempted through that path would
  hang or misbehave. This is a hard constraint on the new fallback-prompt
  design, not just an edge case: it is the primary way a first-time user is
  expected to reach this script at all.
- `bindings/r/R/install_hooks.R` currently exports both
  `askfirst_detect_agent_tool()` (calls `--detect`, returns a character
  vector) and `askfirst_install_agent_hooks(tool, overwrite = FALSE)`, where
  `tool` is a required single string — callers (the vignette, in practice)
  are expected to call the former, branch on its length, and pass a single
  tool name to the latter themselves.

## Design Goals
1. Detecting more than one agent tool for a project must result in hooks
   being installed for **all** of them, with explicit per-tool reporting of
   what was installed — not a single-choice prompt, and not silent partial
   installation.
2. Detecting zero agent tools must never be a dead end: fall back to an
   interactive prompt naming the available tools, when the invocation
   context genuinely supports interaction; fail with a clear, actionable
   error (not a hang) when it does not (notably the `curl | bash` one-liner
   path from stage 024).
3. The set of "available tools" used for validation, error text, and the
   fallback prompt's options must be read from `agent-hooks/manifest.json`
   at run time, not duplicated as hardcoded string literals in the
   installer, the R binding, or docs.
4. The R binding must expose the same detect-all-or-prompt behavior as the
   shell installer, without relying on the shell script's own interactive
   prompt (which cannot work reliably when invoked via R's `system2()`).
5. `askfirst_detect_agent_tool()` is no longer meaningful as public API once
   `askfirst_install_agent_hooks()` performs detection internally; un-export
   it (breaking change, acceptable pre-1.0 at version 0.0.0.9000).

## Proposed Approach
- **`detect_tools()` gains real opencode detection:** in addition to the
  existing `.claude/settings.json` check for `claude`, add a check for an
  existing `.opencode/` directory (cwd only, no upward traversal — matching
  how the `claude` check already works and how the installer itself always
  operates relative to cwd) as the `opencode` signal. This is what makes
  "multiple tools detected" a real, reachable case rather than dead code.
  `opencode.json`'s presence is deliberately **not** checked, since askfirst
  never reads or writes it.
- **`agent-hooks/generate-install-hooks.sh` gains a new splice target:**
  alongside its existing splices (hook-script bodies, context text, reminder
  wording, mangling function), it now also reads
  `agent-hooks/manifest.json`'s `.tools` object keys (via `jq -r '.tools |
  keys[]'`) and generates a `KNOWN_TOOLS=(claude opencode)` bash array
  literal, spliced into `install-agent-hooks.sh` with a "generated, do not
  hand-edit" comment — the same discipline already applied to every other
  embedded/generated section of that file. `manifest.json` remains the one
  hand-edited canonical source; nothing needs manual re-syncing the way
  `hooks_status.R`'s compiled-in copy does today.
- **New `--list-tools` mode:** prints `"${KNOWN_TOOLS[@]}"`, one per line —
  analogous to the existing `--detect` mode, but listing all *known* tools
  rather than *detected* ones, and requiring no runtime file read at all
  (works identically from a full checkout or a standalone-fetched copy).
  This becomes the single source both the shell script's own
  prompt/validation and the R binding's prompt/validation read from,
  replacing every hardcoded `claude`/`opencode` string literal in error
  messages, the `select` prompt, and R's `utils::menu()` choices.
- **No `--tool` given, ≥1 detected:** loop over all detected tools, running
  the existing per-tool install logic for each, printing which tool each
  step is for (e.g. `"Installing hooks for detected tool: claude"` before
  each). Exit non-zero only if any individual tool's install step fails;
  report success/failure per tool rather than aborting the whole run on the
  first failure.
- **No `--tool` given, 0 detected:**
  - If stdin is a terminal (`[ -t 0 ]`): interactively prompt via `select`,
    built from `--list-tools`' output, same as today's (currently
    unreachable) multi-detected prompt — reused for the zero-detected case
    instead.
  - If stdin is not a terminal: print an error listing the available tools
    (from `--list-tools`) and instructing the user to re-run with
    `--tool <name>` explicitly; exit non-zero. This is the path a
    `curl install.sh | bash` user with no agent tool configured yet will
    actually hit.
- **`--tool <name>` still works exactly as today** for a single explicit
  install, with its validation against "is this a known tool" now sourced
  from `--list-tools` instead of the case statement's implicit
  `claude|opencode` literal (the case statement's per-tool *install logic*
  bodies remain hardcoded bash, necessarily, since each tool's install
  mechanics genuinely differ — only the *known-tool-name* list becomes
  data-driven).
- **`bindings/r/R/install_hooks.R`:**
  - `askfirst_detect_agent_tool()`: drop `@export`, keep as an internal
    helper (still calls `--detect`).
  - New internal helper (e.g. `askfirst_list_agent_tools()`, not exported):
    calls the script's new `--list-tools` mode, returning a character
    vector — the same non-hardcoded source used for R's own fallback prompt
    and any future validation.
  - `askfirst_install_agent_hooks(tool = NULL, overwrite = FALSE)`: `tool`
    becomes optional.
    - `tool` supplied: installs just that one tool (unchanged behavior).
    - `tool` omitted: calls the internal detect helper.
      - ≥1 detected: loops, installing (and `message()`-reporting) each
        detected tool in turn.
      - 0 detected, `interactive()` is `TRUE`: `utils::menu()` prompt built
        from `askfirst_list_agent_tools()`, then installs the chosen tool.
      - 0 detected, `interactive()` is `FALSE`: `stop()` with the available
        tools listed and an instruction to call
        `askfirst_install_agent_hooks(tool = "...")` explicitly.
    - Return value changes from a single invisible exit-status integer to an
      invisible named vector/list of per-tool exit statuses, since one call
      can now install for multiple tools. Documented as a breaking change
      in the function's own roxygen docs (pre-1.0, acceptable).
- **Vignette (`using-askfirst.Rmd`, section "0. Pre-configuring agent
  tools"):** replace the current hardcoded/buggy example with a single
  `askfirst::askfirst_install_agent_hooks()` call, with prose explaining
  that it detects and installs for all present tools, or prompts
  interactively when none are found.

## Open Questions
None outstanding — tool-list sourcing, the opencode detection signal,
non-interactive fallback behavior for the `curl | bash` path, and the
R export/return-value changes were all resolved with the user before this
plan was written.
