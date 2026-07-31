---
created: 2026-07-31T12:47:46Z
agent: claude-sonnet-5
git_hash: 4fa90858d2c6ed69b6b1a63404524aeee1c0d008
---

# Tasks: full-test-suite-ci

## T026-1: Create `.github/workflows/test.yml` with the `full-suite` job (R testthat + opencode bun test)
- [x] T026-1: Create `.github/workflows/test.yml`. Name it `Full test suite`.
  Trigger on `push` and `pull_request` with `branches: [main]` and **no**
  `paths:` filter (unconditional — this is the point of the new workflow).
  Set `permissions: { contents: read }` at the workflow level, matching
  `r-cmd-check.yml` and the current `test-install.yml`.
  Add a `full-suite` job running on `ubuntu-latest` with these steps:
  1. `actions/checkout@v4`
  2. `r-lib/actions/setup-r@v2`
  3. `r-lib/actions/setup-r-dependencies@v2` with
     `working-directory: bindings/r`
  4. A step named "Run R testthat suite" that runs:
     `Rscript -e 'testthat::test_local("bindings/r")'`
  5. `oven-sh/setup-bun@v2`
  6. A step named "Run opencode plugin bun test" that runs:
     `bun test agent-hooks/opencode/askfirst-plugin.test.js`
     (no `bun install`/lockfile step needed — the plugin and its test file
     have no external deps beyond Node/Bun builtins, confirmed by reading
     `agent-hooks/opencode/askfirst-plugin.js`'s header comment).

## T026-2: Add the `install-hooks` job (3-OS matrix) to the same workflow, migrated from `test-install.yml`
- [x] T026-2: In `.github/workflows/test.yml`, add a second job,
  `install-hooks`, with `strategy.matrix.os: [ubuntu-latest, macos-latest,
  windows-latest]` and `defaults.run.shell: bash`. Port the steps
  currently in `.github/workflows/test-install.yml` verbatim:
  1. `actions/checkout@v4`
  2. `r-lib/actions/setup-r@v2`
  3. `r-lib/actions/setup-r-dependencies@v2` with
     `working-directory: bindings/r`
  4. A step named "Run install tests (phases 1, 3, 4 — hard requirements)"
     running `tests/test-install-hooks.sh --skip-phase2`
  5. A step named "Run install test (phase 2 — soft requirement while repo
     is private)" with `continue-on-error: true`, running
     `tests/test-install-hooks.sh --phase2-only`
  Carry forward the existing comment above step 5 verbatim (the
  explanation of why phase 2 soft-fails while the repo is private, and the
  note to remove `continue-on-error` and fold it back into the hard step
  once the repo is public — see `specs/024-root-install-script/design-decisions.md`).
  This job's two jobs (`full-suite`, `install-hooks`) both live in the one
  `test.yml` file.

## T026-3: Delete `.github/workflows/test-install.yml`
- [x] T026-3: Delete `.github/workflows/test-install.yml` now that its
  content is fully represented by the `install-hooks` job in `test.yml`
  (T026-2). Do not modify `.github/workflows/r-cmd-check.yml` — it remains
  a separate, path-filtered, heavier CRAN-style check that was never part
  of `make test`.

## T026-4: Validate the new workflow
- [x] T026-4: Sanity-check `.github/workflows/test.yml` for correctness
  before committing:
  - Confirm YAML is well-formed (e.g. `python3 -c "import yaml,
    sys; yaml.safe_load(open('.github/workflows/test.yml'))"` or
    `actionlint` if available).
  - Confirm the workflow's trigger has no `paths:` key (grep the file).
  - Confirm `.github/workflows/test-install.yml` no longer exists and
    `.github/workflows/r-cmd-check.yml` is byte-identical to its
    pre-stage state (`git diff` should show no changes to that file).
  - Run `make test` locally (or the equivalent individual commands, if
    `make`/R/bun aren't all available in this environment) to confirm the
    three suites still pass on their own, independent of the new CI
    wiring.

## T026-5: Promote phase 2 to a hard requirement now that the repo is public
- [x] T026-5: The `ropensci-review-tools/askfirst` repo went public partway
  through this stage's implementation, closing stage 024's deferred item
  (`specs/024-root-install-script/design-decisions.md`'s "Deferred Items").
  Updated `tests/test-install-hooks.sh`: `phase2()` now calls `log_fail`
  instead of `log_soft_fail` (removed entirely, since it was
  phase2()'s only caller), the `--skip-phase2`/`--phase2-only` mode
  dispatch was removed in favor of always running all 6 phases
  unconditionally, and the private-repo caveat comments were updated to
  past tense. Updated `.github/workflows/test.yml`'s `install-hooks` job
  to a single "Run install tests (all 6 phases — hard requirements)" step
  (`tests/test-install-hooks.sh`, no flags, no `continue-on-error`),
  replacing the two-step hard/soft split from T026-2. Verified locally:
  `bash tests/test-install-hooks.sh` now reports phase 2 passing for real
  (the live `curl .../main/install.sh | bash` fetch succeeds against the
  now-public repo).
