---
created: 2026-07-31T12:43:37Z
agent: claude-sonnet-5
git_hash: 4fa90858d2c6ed69b6b1a63404524aeee1c0d008
---

# Plan: full-test-suite-ci

## Overview
Wire the full local test suite (R testthat, tests/test-install-hooks.sh, and the opencode plugin's bun test) into a single unconditional CI workflow, so pushes/PRs are gated on more than just the R-bindings-scoped r-cmd-check.yml

## Context
Today, `make test` runs three independent suites locally (R testthat via
`Rscript -e 'testthat::test_local("bindings/r")'`, `tests/test-install-hooks.sh`,
and `bun test agent-hooks/opencode/askfirst-plugin.test.js`), but CI never
runs all three together:
- `.github/workflows/r-cmd-check.yml` runs a full `R CMD check` (a heavier,
  CRAN-style build+check across a 5-OS/R-version matrix), path-filtered to
  `bindings/r/**`, `agent-detect-spec/**`, `agent-content/**`. It does not
  run `testthat::test_local()` the same way `make test` does, and it isn't
  part of the Makefile's `test` target at all.
- `.github/workflows/test-install.yml` runs `tests/test-install-hooks.sh`
  across a 3-OS matrix (ubuntu/macos/windows), path-filtered to
  `install.sh`, `install.ps1`, `agent-hooks/**`, `tests/test-install-hooks.sh`,
  `bindings/r/R/install_hooks.R`. It splits phase 2 (install.sh's live
  `curl .../main/install.sh | bash` fetch) into a hard `--skip-phase2` run
  plus a soft, `continue-on-error` `--phase2-only` run, because
  `raw.githubusercontent.com` 404s on unauthenticated requests while this
  repo is private (stage 024's Decision 3 / Issues Resolved / Deferred
  Items — see `specs/024-root-install-script/design-decisions.md`).
  Promoting phase 2 to a hard requirement once the repo goes public is an
  explicit deferred item from that stage, not something to redo here.
- The opencode plugin's `bun test` suite (`agent-hooks/opencode/askfirst-plugin.test.js`,
  added in stage 017 and hardened in stage 018/020) has real behavioral
  coverage — including the shared cross-language path-mangling fixture
  (`agent-hooks/askfirst-state-dir-fixture.txt`) also checked by
  `bindings/r/tests/testthat/test-log.R` — but no CI workflow runs it at
  all today. A change that breaks the opencode plugin currently passes CI
  cleanly.

Stage decisions already made in conversation (see this stage's
`.transcript.md`):
- Scope is CI wiring only, not adding new direct behavioral tests for the
  Claude Code hook shell scripts (`agent-hooks/claude/*.sh`) — that gap
  was identified but explicitly deferred, not folded into this stage.
- The fix is a new, single unified workflow that mirrors `make test` 1:1,
  triggered unconditionally (no `paths:` filter) on push/PR to `main` —
  not path-filtered like the existing workflows, and not merely adding a
  bun-test step to `test-install.yml` in isolation.

## Design Goals
- Every push/PR to `main` runs the complete local `make test` suite (R
  testthat, `tests/test-install-hooks.sh`, opencode `bun test`) via CI, not
  just the R-bindings-scoped `r-cmd-check.yml`.
- No existing coverage is lost or silently duplicated: retire
  `test-install.yml` by folding its jobs into the new workflow, rather than
  running the same install-hooks script twice per PR in two separate
  workflows.
- Preserve the established private-repo soft-fail convention for
  `install.sh`'s live-curl phase 2 (stage 024's deferred item) — this stage
  does not attempt to promote it to a hard requirement, since the repo is
  still private.
- Keep the new workflow's CI cost proportionate: run the OS-agnostic suites
  (R testthat, bun test) once, on `ubuntu-latest`, since that logic is pure
  string/path manipulation, not OS-filesystem-dependent; keep the 3-OS
  matrix only for the install-hooks phases that genuinely exercise
  per-OS behavior (bash vs. `pwsh`, `install.sh` vs. `install.ps1`).

## Proposed Approach
- Add a new workflow file, `.github/workflows/test.yml`, triggered on
  `push` and `pull_request` to `main` with **no** `paths:` filter
  (unconditional), containing two jobs:
  - **`full-suite`** (`ubuntu-latest`): set up R + `bindings/r` deps, run
    `Rscript -e 'testthat::test_local("bindings/r")'`; set up bun
    (`oven-sh/setup-bun`), run
    `bun test agent-hooks/opencode/askfirst-plugin.test.js`.
  - **`install-hooks`** (matrix: `ubuntu-latest`, `macos-latest`,
    `windows-latest`): the same steps currently in `test-install.yml` —
    set up R + `bindings/r` deps, run
    `tests/test-install-hooks.sh --skip-phase2` (hard requirement), then
    `tests/test-install-hooks.sh --phase2-only` (`continue-on-error`, soft
    requirement) — carrying forward the private-repo caveat comment
    verbatim, including the note to promote it to hard once the repo is
    public.
- Delete `.github/workflows/test-install.yml` — its content becomes the
  `install-hooks` job above; nothing here changes its actual test logic or
  the phase-2 soft-fail handling, only where it's declared.
- Leave `.github/workflows/r-cmd-check.yml` untouched: it checks something
  genuinely different (a full CRAN-style package build+check across 5
  OS/R-version combinations) that was never part of `make test`, so it
  keeps its own path-filtered trigger for cost reasons.
- Leave `agent-hooks/claude/*.sh`'s direct-execution test gap untouched in
  this stage (see Context) — flagged for a future stage.

## Mid-Implementation Update
The `ropensci-review-tools/askfirst` repo went public partway through this
stage's implementation. This closes stage 024's deferred item directly, so
rather than leaving the newly-created `install-hooks` job with the
now-obsolete private-repo soft-fail split (Design Goal 3 / Proposed
Approach above, as originally written), phase 2 was promoted to a hard
requirement in the same pass: `tests/test-install-hooks.sh` now runs all 6
phases unconditionally with no soft-fail path, and `test.yml`'s
`install-hooks` job runs it in a single step. See T026-5 in `tasks.md`.

## Open Questions
Both resolved during plan review:
- Naming: confirmed as `test.yml`, matching the Makefile's `test` target
  name 1:1.
- Direct behavioral tests for `agent-hooks/claude/*.sh` (piping a real JSON
  payload in and asserting on stdout/exit code/state-dir side effects, the
  way `askfirst-plugin.test.js` already does for the opencode side):
  confirmed out of scope for this stage — deferred to a future stage.
