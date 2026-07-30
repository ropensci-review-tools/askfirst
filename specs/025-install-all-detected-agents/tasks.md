---
created: 2026-07-30T14:35:21Z
agent: claude-sonnet-5
git_hash: 9482dea3ea39b23747bf2eaf44e4637aa6883700
---

# Tasks: install-all-detected-agents

## T025-1: Splice a generated KNOWN_TOOLS array into install-agent-hooks.sh
- [x] T025-1: In `agent-hooks/install-agent-hooks.sh`, add a new marker pair
  near the top of the script (after the `MODE="install"` initialization,
  before `detect_tools()`), e.g.:
  ```bash
  # ASKFIRST_KNOWN_TOOLS_START
  KNOWN_TOOLS=(claude opencode)
  # ASKFIRST_KNOWN_TOOLS_END
  ```
  with a comment above it noting this is generated from
  `agent-hooks/manifest.json` by `agent-hooks/generate-install-hooks.sh` and
  must not be hand-edited (matching the existing "do not hand-edit"
  convention used for the SESSION_HOOK/POST_HOOK/etc. heredoc bodies). In
  `agent-hooks/generate-install-hooks.sh`, add a new splice step (alongside
  the existing Pass 1 splices) that: reads `agent-hooks/manifest.json`'s
  `.tools` object keys via `jq -r '.tools | keys[]'`, builds a single-line
  `KNOWN_TOOLS=(<space-separated names>)` string, writes it to a temp file,
  and calls the existing `splice_between_markers` helper against
  `install-agent-hooks.sh` with `'# ASKFIRST_KNOWN_TOOLS_START'`/
  `'# ASKFIRST_KNOWN_TOOLS_END'` in `exclusive` mode (same pattern already
  used for the `ASKFIRST_STATE_DIR_START`/`_END` splice). Run the generator
  and confirm `KNOWN_TOOLS=(claude opencode)` appears correctly in
  `install-agent-hooks.sh` afterward. Update the generator's own header
  comment (the "Run this after editing any of: ..." list) to include
  `agent-hooks/manifest.json`.

## T025-2: Add opencode auto-detection to detect_tools()
- [x] T025-2: In `agent-hooks/install-agent-hooks.sh`'s `detect_tools()`,
  add a check for an existing `.opencode/` directory (cwd only, no upward
  traversal) alongside the existing `.claude/settings.json` check for
  `claude`, appending `"opencode"` to the `found` array when it exists.
  Update the function's explanatory comment: opencode's project-level
  config (`opencode.json` or a `.opencode/` directory) is read and merged
  by opencode regardless of what else exists at other precedence levels
  (confirmed against `https://opencode.ai/docs/config`), so the mere
  existence of `.opencode/` is a reliable, always-applicable signal —
  `opencode.json`'s presence is deliberately not checked, since askfirst
  never reads or writes it, only installs into `.opencode/plugins/`. Remove
  or correct any now-stale comment claiming opencode "is never
  auto-detected."

## T025-3: Add a --list-tools mode
- [x] T025-3: In `agent-hooks/install-agent-hooks.sh`'s argument-parsing
  `while` loop, add a new `--list-tools` option (parallel to `--detect`)
  that sets `MODE="list-tools"`. Add a dispatch branch (parallel to the
  existing `if [[ "$MODE" == "detect" ]]; then detect_tools; exit 0; fi`)
  that prints `"${KNOWN_TOOLS[@]}"` one per line (`printf '%s\n'
  "${KNOWN_TOOLS[@]}"`) and exits 0. Add `--list-tools` to the script's
  `# Usage:` comment block at the top of the file (used by `usage()`).

## T025-4: Rework tool resolution and installation to support install-all and a stdin-aware fallback prompt
- [x] T025-4: Refactor `agent-hooks/install-agent-hooks.sh` so the two
  existing `case "$TOOL" in claude) ... opencode) ... esac` blocks (the
  target-variable-setting one and the actual-install one) are combined into
  a single function, e.g. `install_for_tool()`, taking a tool name as its
  argument and performing both the target-variable setup and the
  mkdir/write/register steps for that one tool — using a case statement
  whose `*)` branch prints `"error: unknown tool '$1' (supported:
  ${KNOWN_TOOLS[*]})"` (dynamic, from `KNOWN_TOOLS`, replacing the current
  hardcoded `"supported: claude, opencode"` text) and exits 1. Then rework
  the tool-resolution logic that currently sets a single `$TOOL` (today's
  lines ~63-81) as follows:
  - `--tool <name>` given: validate `<name>` is a member of `KNOWN_TOOLS`
    (clear error + exit 1, listing `KNOWN_TOOLS`, if not); call
    `install_for_tool "<name>"` once.
  - `--tool` not given, `detect_tools()` returns ≥1 tool: for each detected
    tool, print `"Installing hooks for detected tool: <name>"` to stderr,
    then call `install_for_tool "<name>"`. If any individual call fails,
    record the failure, continue with the remaining tools, and exit
    non-zero at the end if any failed (report which tools succeeded/failed
    in a final summary line) — do not abort the whole run on the first
    failure.
  - `--tool` not given, `detect_tools()` returns 0 tools: if `[ -t 0 ]`
    (stdin is a terminal), reuse the existing interactive `select` prompt
    pattern, built from `"${KNOWN_TOOLS[@]}"`, to let the user choose one
    tool, then call `install_for_tool` with that choice. If stdin is not a
    terminal, print an error to stderr listing `"${KNOWN_TOOLS[@]}"` and
    instructing the user to re-run with `--tool <name>`, then exit 1
    (rather than attempting `select`, which would hang or misbehave when
    stdin is a piped script, e.g. via `curl install.sh | bash`).
  Remove the now-unused single-`$TOOL`-scoped case statements this
  replaces.

## T025-5: Un-export askfirst_detect_agent_tool() and add askfirst_list_agent_tools()
- [x] T025-5: In `bindings/r/R/install_hooks.R`, remove the `@export` tag
  from `askfirst_detect_agent_tool()`'s roxygen block (keep the function
  itself, its body, and its documentation comment — just no longer part of
  the public API — add `@keywords internal` and `@noRd` in its place,
  matching the style of other internal helpers such as
  `askfirst_hooks_manifest()` in `hooks_status.R`). Add a new internal
  helper function `askfirst_list_agent_tools()` (also `@keywords internal`
  `@noRd`, no `@export`) that locates the installer script the same way
  `askfirst_detect_agent_tool()` does, calls it with `"--list-tools"` via
  `system2(..., stdout = TRUE, stderr = FALSE)`, and returns the result as
  a character vector.

## T025-6: Redesign askfirst_install_agent_hooks() to detect-install-all-or-prompt
- [x] T025-6: In `bindings/r/R/install_hooks.R`, change
  `askfirst_install_agent_hooks()`'s signature to
  `askfirst_install_agent_hooks(tool = NULL, overwrite = FALSE)`. New
  behavior:
  - `tool` supplied (single string): unchanged from today — installs just
    that one tool, returns invisibly.
  - `tool` is `NULL` (default): call `askfirst_detect_agent_tool()`
    internally.
    - Length ≥ 1: for each detected tool, `message()` which tool is being
      installed, then run the existing single-tool install logic for it;
      collect each tool's exit status.
    - Length 0, `interactive()` is `TRUE`: call `askfirst_list_agent_tools()`
      for the choices, prompt via `utils::menu(choices, title = "No agent
      tool detected. Which tool should hooks be installed for?")`, then
      install for the chosen tool (re-prompt or error clearly if the user
      cancels/enters `0`).
    - Length 0, `interactive()` is `FALSE`: `stop()` with a message listing
      `askfirst_list_agent_tools()`'s output and instructing the caller to
      pass `tool = "..."` explicitly.
  - Return value: invisibly, a named vector of exit statuses (one entry per
    tool actually installed), keyed by tool name — replacing the old
    single invisible integer. Update the roxygen `@return` docs to describe
    this, and note in the function's documentation that this is a breaking
    change from the previous single-integer return (pre-1.0, version
    `0.0.0.9000`).
  Update both functions' roxygen `@param`/`@examples` blocks to reflect the
  optional `tool` argument and the new zero/multi-detection behavior.

## T025-7: Regenerate NAMESPACE/man pages
- [x] T025-7: Run roxygen2 (e.g. `Rscript -e
  'roxygen2::roxygenise("bindings/r")'` or the project's usual
  `devtools::document()` equivalent) to regenerate `bindings/r/NAMESPACE`
  and `bindings/r/man/`. Confirm `askfirst_detect_agent_tool` no longer
  appears in `NAMESPACE`'s `export(...)` lines, confirm
  `bindings/r/man/askfirst_detect_agent_tool.Rd` is removed (or converted
  to an internal-only doc with no `.Rd`, per whatever roxygen produces for
  a `@keywords internal`/no-`@export` function — remove the stale file if
  roxygen doesn't do this automatically), and confirm
  `bindings/r/man/askfirst_install_agent_hooks.Rd` is regenerated with the
  new signature and return-value docs.

## T025-8: Update the vignette's install example
- [x] T025-8: In `bindings/r/vignettes/using-askfirst.Rmd`, section "0.
  Pre-configuring agent tools", replace the current example:
  ```r
  tools <- askfirst::askfirst_detect_agent_tool()
  if (length(tools) == 1) {
    askfirst::askfirst_install_agent_hooks(tools)
  } else if (length(tools) > 1) {
    askfirst::askfirst_install_agent_hooks("claude")
    askfirst::askfirst_install_agent_hooks("opencode")
  }
  ```
  with a single call:
  ```r
  askfirst::askfirst_install_agent_hooks()
  ```
  Update the surrounding prose to describe the new behavior: detects and
  installs hooks for every agent tool found in the project, prints which
  tool(s) were installed, and — when none are detected — prompts
  interactively for a tool name (or errors with instructions to pass
  `tool = "..."` explicitly, in a non-interactive session). Remove any
  remaining prose implying `askfirst_detect_agent_tool()` is meant to be
  called directly by users (it is no longer exported).

## T025-9: Add regression tests for the new detection/install-all/fallback behavior
- [x] T025-9: Add new tests to
  `bindings/r/tests/testthat/test-install-agent-hooks.R` (shell-level,
  following the existing `withr::local_tempdir()` + `system2(bash,
  shQuote(installer), ...)` pattern used by the existing tests in that
  file):
  - `--list-tools` prints exactly `claude` and `opencode` (in some order),
    one per line.
  - Seeding a scratch dir with both `.claude/settings.json` (minimal `{}`)
    and an empty `.opencode/` directory, then running the installer with
    **no** `--tool` flag, installs and registers hooks for **both** tools
    (assert `.claude/hooks/askfirst-*.sh` files and `.claude/settings.json`
    registration as the existing tests do, AND assert
    `.opencode/plugins/askfirst-plugin.js` exists), and that the printed
    output names both tools as installed.
  - Seeding a scratch dir with **neither** `.claude/settings.json` nor
    `.opencode/`, then running the installer with no `--tool` flag and
    stdin redirected from `/dev/null` (non-interactive), exits non-zero
    without hanging, and the printed error output lists `claude` and
    `opencode` as available tools and instructs use of `--tool <name>`.
  Add new tests to `bindings/r/tests/testthat/` (a new or existing file
  covering `install_hooks.R`'s R-level functions directly, not just via
  shell) covering: `askfirst_install_agent_hooks(tool = NULL)` in a
  non-interactive R session (`interactive()` is always `FALSE` under
  `testthat`) with zero tools detected raises an informative error (via
  `expect_error()`) naming the available tools; with ≥1 tool detected (seed
  a `withr::local_tempdir()` the same way), installs for each detected tool
  and returns a named vector of exit statuses; confirm
  `askfirst::askfirst_detect_agent_tool` is no longer reachable (only
  `askfirst:::askfirst_detect_agent_tool` is) via `expect_false(exists(
  "askfirst_detect_agent_tool", where = asNamespace("askfirst"), inherits =
  FALSE) ...)`-style check against the package's exported-names list (e.g.
  `expect_false("askfirst_detect_agent_tool" %in%
  getNamespaceExports("askfirst"))`).

## T025-10: Extend tests/test-install-hooks.sh with install-all and no-detection-no-tty coverage
- [x] T025-10: In `tests/test-install-hooks.sh` (added stage 024), add two
  new phases (numbered to follow the existing four): one that seeds a
  scratch dir with both a minimal `.claude/settings.json` and an empty
  `.opencode/` directory, runs `agent-hooks/install-agent-hooks.sh` with
  **no** `--tool` flag, and asserts both tools' hook files/registration are
  present (extend `check_hooks_installed` or add a parallel
  `check_opencode_installed` helper that checks for
  `.opencode/plugins/askfirst-plugin.js`); and one that seeds an empty
  scratch dir (neither indicator present), runs the installer with no
  `--tool` flag and stdin from `/dev/null`, and asserts a non-zero exit
  without the process hanging (e.g. via a `timeout` wrapper) plus an error
  message naming both available tools. Both new phases are hard
  requirements (always enforced, like phases 1/3/4), since they exercise
  `install-agent-hooks.sh` and `install.ps1`'s underlying script directly,
  not the private-repo-dependent live-fetch path. Update the script's
  `--skip-phase2`/`--phase2-only`/`all` mode dispatch to include the new
  phases in the appropriate (non-phase-2) branches.

## T025-11: Verify the full change set
- [x] T025-11: Run `bash -n agent-hooks/install-agent-hooks.sh` and `bash -n
  agent-hooks/generate-install-hooks.sh` to check syntax. Run
  `agent-hooks/generate-install-hooks.sh` and confirm it regenerates
  cleanly with no unintended diff beyond the new `KNOWN_TOOLS` splice. Run
  `tests/test-install-hooks.sh` (all phases) and confirm the two new phases
  from T025-10 pass alongside the existing four. Run the R package's test
  suite (`Rscript -e 'devtools::test("bindings/r")'` or equivalent) and
  confirm the new and existing tests from T025-9 pass, including that
  `askfirst_detect_agent_tool` is confirmed un-exported. Manually re-read
  the updated vignette section for accuracy against the new behavior.
