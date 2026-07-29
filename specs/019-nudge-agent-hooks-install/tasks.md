---
created: 2026-07-29T10:36:16Z
agent: claude-sonnet-5
git_hash: d612106394e2ac3d7bd514b7278fdff4649fa15e
---

# Tasks: nudge-agent-hooks-install

## T019-1: Create `agent-content/` with four canonical template files

- [x] T019-1: Create a new top-level `agent-content/` directory (sibling to
  `agent-hooks/` and `agent-detect-spec/`) containing four plain-text
  template files, using the `{{PLACEHOLDER}}` convention already
  established by `agent-hooks/askfirst-reminder-messages.txt`:
  - `agent-content/askfirst-markers.txt` — the two delimiter tokens, using
    the same `--- LEVELn ---`-style section-marker format
    `askfirst-reminder-messages.txt` already uses:
    ```
    --- HALT ---
    <<<ASKFIRST:HALT>>>
    --- RESUME ---
    <<<ASKFIRST:RESUME>>>
    ```
  - `agent-content/askfirst-stop-consequence.txt` — the `{{PKG}}`-templated
    hard-stop consequence text, extracted **verbatim** (only the two `%s`
    positions become `{{PKG}}`) from the current
    `askfirst_stop_consequence()` body in
    `bindings/r/R/conditions.R`.
  - `agent-content/askfirst-notice-prime.txt` — the notice-prime text,
    extracted verbatim from the current `askfirst_notice_prime()` body in
    `bindings/r/R/conditions.R`, with `%s` positions for `pkg` becoming
    `{{PKG}}` and the two `%s` positions for the delimiters becoming
    `{{HALT_MARKER}}`/`{{RESUME_MARKER}}` (this text quotes the marker
    tokens themselves, so it needs both kinds of placeholder).
  - `agent-content/askfirst-hooks-nudge.txt` — new text, addressed to the
    calling agent (not a human), stating that this project has no current
    askfirst-aware agent hooks installed (or they are stale), and
    instructing the agent to tell its human user to run
    `agent-hooks/install-agent-hooks.sh` (from the askfirst repository) to
    install or update hooks that help AI coding assistants recognise
    askfirst's structured signals directly. Use `{{PKG}}` at least once
    (e.g. noting the check ran while loading `{{PKG}}`), matching the
    template convention of the other three files.

## T019-2: Wire `conditions.R` to read markers/stop-consequence/notice-prime from `agent-content/`

- [x] T019-2: In `bindings/r/R/conditions.R`, replace the hardcoded R
  string literals with runtime reads of the new template files:
  - Add a small internal helper (e.g. `askfirst_read_content(file)`) that
    reads `system.file("agent-content", file, package = "askfirst")` via
    `readLines()`/`paste(collapse = "\n")`.
  - Add a helper to extract a named section from
    `askfirst-markers.txt`'s `--- HALT ---`/`--- RESUME ---` format
    (mirroring `agent-hooks/generate-install-hooks.sh`'s
    `extract_reminder_raw()` logic, ported to R).
  - Replace `askfirst_stop_start_delimiter`/`askfirst_stop_end_delimiter`'s
    literal string assignments with values read from
    `askfirst-markers.txt` via the new helpers.
  - Replace `askfirst_stop_consequence()`'s `sprintf()` body with a read of
    `askfirst-stop-consequence.txt`, substituting `{{PKG}}` with `pkg` via
    `gsub("{{PKG}}", pkg, ..., fixed = TRUE)`.
  - Replace `askfirst_notice_prime()`'s `sprintf()` body with a read of
    `askfirst-notice-prime.txt`, substituting `{{PKG}}` with `pkg` and
    `{{HALT_MARKER}}`/`{{RESUME_MARKER}}` with the now-loaded
    `askfirst_stop_start_delimiter`/`askfirst_stop_end_delimiter` values.
  - Leave `askfirst_signal()`'s assembly logic (how these pieces are
    `paste()`d into the notice vs. hard-stop shape) unchanged — only the
    literal template text moves out of R source.
  - Update the roxygen `@keywords internal`/`@noRd` comments on
    `askfirst_stop_start_delimiter`, `askfirst_stop_consequence()`, and
    `askfirst_notice_prime()` to reference `agent-content/` as the new
    source of truth instead of describing the text as R-authored.

## T019-3: Add the `askfirst_hooks_nudge` condition class

- [x] T019-3: In `bindings/r/R/conditions.R`'s `askfirst_signal()`, add
  `askfirst_hooks_nudge = "hooks_nudge"` to `type_map` and
  `askfirst_hooks_nudge = "notice"` to `directive_map`, so the class uses
  the existing notice shape (non-fatal, via `rlang::inform()`) with no new
  shape logic. Update the function's roxygen documentation listing the
  four concrete condition classes to list this fifth one, including its
  directive (`"notice"`) and shape (notice shape), and note it is
  triggered from `askfirst_maybe_nudge_hooks_install()` rather than a
  specific adopting package's own capability-gap/scenario-check code path.

## T019-4: Add `bindings/r/data-raw/sync-agent-content.R`

- [x] T019-4: Create `bindings/r/data-raw/sync-agent-content.R`,
  structurally identical to the existing `sync-vendor.R` (`file.copy()`,
  never a symlink), copying every file in `agent-content/` into
  `bindings/r/inst/agent-content/`. Include the same header-comment style
  as `sync-vendor.R` (what it does, when to re-run it, that it must be run
  from the repository root). Run the script once now and commit the
  resulting `bindings/r/inst/agent-content/*.txt` files alongside the
  repo-root `agent-content/*.txt` sources from T019-1.

## T019-5: Add `bindings/r/data-raw/check-agent-content-sync.R`

- [x] T019-5: Create `bindings/r/data-raw/check-agent-content-sync.R`,
  structurally identical to the existing `check-vendor-sync.R`: compares
  every file in `agent-content/` against its counterpart in
  `bindings/r/inst/agent-content/` via `readLines()`/`identical()`,
  printing a mismatch report and exiting with status 1 if any file is
  missing or differs, pointing at `sync-agent-content.R` as the fix.

## T019-6: Wire the agent-directed hooks-nudge signal into `askfirst_init()`

- [x] T019-6: In `bindings/r/R/hooks_status.R`, give
  `askfirst_maybe_nudge_hooks_install()` a `pkg` parameter. After the
  existing, unchanged `cli::cli_inform()` call: if `status %in%
  c("not_installed", "stale")` **and** `.askfirst_state$confidence` is
  `"high"`, additionally call `askfirst_signal("askfirst_hooks_nudge", pkg
  = pkg, message = <askfirst-hooks-nudge.txt rendered with {{PKG}}
  substituted for pkg>)`. Both the `cli::cli_inform()` call and this new
  `askfirst_signal()` call remain governed by the single existing
  `.askfirst_state$hooks_nudge_shown` once-per-session flag (do not add a
  second flag). Update `bindings/r/R/init.R`'s `askfirst_init()` to pass
  its own `pkg` argument through to
  `askfirst_maybe_nudge_hooks_install(pkg)`. Update both functions'
  roxygen documentation to describe the new confidence-gated
  agent-directed branch, and note explicitly that it is additive to (does
  not replace) the pre-existing unconditional human-directed nudge from
  stage 014.

## T019-7: Add a local pre-commit hook enforcing both sync checks

- [x] T019-7: Create `.githooks/pre-commit` (executable, repo-tracked —
  `.git/hooks/` itself is never committed) that runs `Rscript
  bindings/r/data-raw/check-vendor-sync.R` and `Rscript
  bindings/r/data-raw/check-agent-content-sync.R`, aborting the commit
  (non-zero exit) if either reports drift, and printing which sync script
  to re-run. Include a header comment in the script itself explaining that
  it is opt-in via `git config core.hooksPath .githooks` (no other
  documentation of this opt-in step is needed — this is a developer-only,
  local convenience hook).

## T019-8: Extend CI to check `agent-content/` sync

- [x] T019-8: In `.github/workflows/r-cmd-check.yml`, add
  `"agent-content/**"` to both the `on.push.paths` and
  `on.pull_request.paths` lists (alongside the existing
  `"agent-detect-spec/**"` entry), and add a step to the existing
  `check-vendor-sync` job running `Rscript
  bindings/r/data-raw/check-agent-content-sync.R` (named to reflect that
  the job now checks both `agent-detect-spec/` and `agent-content/` sync,
  e.g. rename the step/job description accordingly without necessarily
  renaming the job key if that would break other references — check for
  any other workflow or doc referencing the `check-vendor-sync` job name
  first).

## T019-9: Unify `askfirst-context.txt`'s marker prose with `agent-content/askfirst-markers.txt`

- [x] T019-9: Edit `agent-hooks/askfirst-context.txt`, replacing its
  literal `<<<ASKFIRST:HALT>>>`/`<<<ASKFIRST:RESUME>>>` occurrences with
  `{{HALT_MARKER}}`/`{{RESUME_MARKER}}` placeholders. Extend
  `agent-hooks/generate-install-hooks.sh` with a new preprocessing step
  (using the same `mktemp`-and-render pattern already used for the
  bash/JS reminder lines): read the two token values out of
  `agent-content/askfirst-markers.txt` (reusing/adapting the existing
  `extract_reminder_raw()`-style awk extraction), substitute
  `{{HALT_MARKER}}`/`{{RESUME_MARKER}}` into a temporary rendered copy of
  `askfirst-context.txt`, and splice *that* rendered temp file — instead
  of `askfirst-context.txt` directly, as today — into
  `agent-hooks/claude/session_start.sh` and
  `agent-hooks/opencode/askfirst-plugin.js`. Update the script's own
  header comment (which currently lists
  `askfirst-context.txt`/`askfirst-reminder-messages.txt`/
  `askfirst-state-dir.sh` as the files to edit before re-running it) to
  also list `agent-content/askfirst-markers.txt`. Re-run
  `agent-hooks/generate-install-hooks.sh` and commit every regenerated
  file it touches (`agent-hooks/claude/session_start.sh`,
  `agent-hooks/claude/post_tool_use.sh`,
  `agent-hooks/claude/user_prompt_submit.sh`,
  `agent-hooks/opencode/askfirst-plugin.js`,
  `agent-hooks/install-agent-hooks.sh`) together.

## T019-10: Test the `confidence == "high"` hooks-nudge branch

- [x] T019-10: In `bindings/r/tests/testthat/test-init.R`, add tests
  (alongside the three existing hooks-nudge tests, which all set
  `confidence <- "low"` and must continue passing unchanged) covering the
  new branch: (1) with hooks `not_installed` (or `stale`) and
  `.askfirst_state$confidence <- "high"`, `askfirst_init()` signals an
  `askfirst_hooks_nudge` condition (assert class, `pkg` field, and message
  content, mirroring the existing `askfirst_notice` confidence test's
  structure); (2) with hooks current and confidence `"high"`, no
  `askfirst_hooks_nudge` condition fires; (3) with hooks `not_installed`
  and confidence `"low"`/`"medium"`, no `askfirst_hooks_nudge` condition
  fires (only the existing human-directed message still prints).

## T019-11: Test the `agent-content/`-reading helpers in `conditions.R`

- [x] T019-11: Add tests (new or in an existing `test-conditions.R`-style
  file, matching whatever test file already covers `askfirst_signal()`'s
  hard-stop/notice shapes) verifying: `askfirst_stop_start_delimiter`/
  `askfirst_stop_end_delimiter` load the expected literal token values
  from `agent-content/askfirst-markers.txt`; `askfirst_stop_consequence(pkg)`
  and `askfirst_notice_prime(pkg)` render with `{{PKG}}` (and, for the
  latter, `{{HALT_MARKER}}`/`{{RESUME_MARKER}}`) correctly substituted;
  and the new `askfirst-hooks-nudge.txt` renders correctly via whatever
  helper T019-6 introduced. Do not add testthat coverage for
  `check-agent-content-sync.R`/`sync-agent-content.R` themselves — this
  matches the existing, deliberate precedent that `check-vendor-sync.R` /
  `sync-vendor.R` have no testthat coverage either and are verified only
  by direct execution (CI job / pre-commit hook).

## T019-12: Add forward-pointing notes to stage 014's design-decisions entries

- [x] T019-12: Add a short forward-pointing note to the "Hooks-installation
  detection: language-agnostic manifest and version marker, human-directed
  nudge" entry in both
  `specs/014-self-sufficient-stop-signal/design-decisions.md` and the
  aggregated `specs/design-decisions.md`, stating that stage 019 added a
  second, confidence-gated agent-directed channel alongside the
  human-directed nudge described in that entry (which remains unchanged),
  and moved the fixed condition text this entry doesn't mention into
  `agent-content/` — so a reader of the stage-014 entry in isolation isn't
  misled about the current state of either.

## T019-13: Regenerate roxygen docs

- [x] T019-13: Run `devtools::document()` (or equivalent) in `bindings/r/`
  to regenerate any `man/*.Rd` files affected by the roxygen comment
  changes in T019-2, T019-3, and T019-6 (e.g. `askfirst_install_agent_hooks.Rd`
  if `askfirst_init()`'s exported documentation changed), and commit the
  regenerated files alongside the source changes.
