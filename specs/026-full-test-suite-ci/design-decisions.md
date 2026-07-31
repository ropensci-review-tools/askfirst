---
created: 2026-07-31T13:00:38Z
agent: claude-sonnet-5
git_hash: fcdce2b7f0a7eebe1f2da6bf328be5eb0350b1fd
---

# Design Decisions: full-test-suite-ci

## Summary
Replaced the R-bindings-only `r-cmd-check.yml` and the path-filtered
`test-install.yml` with a single unconditional `test.yml` workflow that
runs the project's complete local test suite (R testthat, the install-hooks
shell test, and the opencode plugin's bun test) on every push and pull
request, and closed a deferred item from stage 024 by promoting the
install-hooks script's live-fetch phase to a hard requirement once the repo
went public.

## New Design Decisions

### Decision 1: CI-wiring scope only
**Chosen:** This stage closes the gap between the local `make test` target
and what actually runs in CI. It does not add new direct behavioral tests
for the Claude Code hook shell scripts (`agent-hooks/claude/*.sh`), a
second, distinct gap identified during scoping (those scripts' runtime
logic — blocking, escalating reminders, state-dir clearing — is only
checked indirectly today, via R-side installation tests).
**Rationale:** Two independent gaps existed; the requester chose to scope
this stage to the CI-wiring one.
**Tradeoffs:** The hook-script behavioral-test gap remains open.
**Proposed by:** joint

### Decision 2: One unified, unconditional workflow replacing `test-install.yml`
**Chosen:** `.github/workflows/test.yml`, triggered on push/PR to `main`
with no path filter, containing a `full-suite` job (`ubuntu-latest`: R
testthat + opencode `bun test`) and an `install-hooks` job (3-OS matrix,
migrated from `test-install.yml`, which was deleted).
**Rationale:** Path filters on the prior workflows meant a change touching
only, say, the opencode plugin never ran any CI at all; an unconditional
gate catches cross-cutting breakage that filters would miss. Splitting the
OS-agnostic suites onto a single runner (rather than the full 3-OS matrix)
keeps CI cost proportionate, since that logic is pure string/path
manipulation rather than OS-filesystem-dependent.
**Tradeoffs:** Slightly higher CI cost per push than the previous
path-filtered triggers.
**Proposed by:** joint

### Decision 3: Promote install.sh's live-fetch phase to a hard requirement
**Chosen:** The repo went public mid-stage. `tests/test-install-hooks.sh`'s
phase 2 (the live `curl .../main/install.sh | bash` fetch) now uses
`log_fail` instead of `log_soft_fail`, and the script always runs all 6
phases unconditionally — the `--skip-phase2`/`--phase2-only` mode split was
removed as no longer serving any purpose. `test.yml`'s `install-hooks` job
runs the script in a single step instead of a hard/soft pair.
**Rationale:** Closes stage 024's explicit deferred item directly; the
`raw.githubusercontent.com` 404-on-private-repo failure mode this soft-fail
worked around no longer applies. Verified locally: phase 2 now passes for
real against the public repo.
**Tradeoffs:** None identified.
**Proposed by:** git-user
**Relates to:** stage 024's Decision 3 and Deferred Items.

## Integration with Prior Work
Directly resolves the deferred item from
`specs/024-root-install-script/design-decisions.md` (promoting phase 2 once
the repo is public) and brings the opencode plugin test suite added in
stage 017 (hardened in 018/020) into CI for the first time.

## Issues Resolved
- No CI workflow ran the complete local test suite: closed by the new
  `test.yml`.
- The opencode plugin's `bun test` suite never ran in CI: closed by the
  `full-suite` job.
- Stage 024's deferred phase-2 promotion: closed once the repo went public
  mid-stage.

## Deferred Items
- Direct behavioral tests for `agent-hooks/claude/*.sh` (piping a real JSON
  payload in and asserting on stdout/exit code/state-dir effects) remain
  unaddressed — identified during this stage's scoping but explicitly left
  for a future stage.

## Process Notes
- The repo's visibility changed from private to public partway through
  implementation, which was handled as an in-flight update to the plan
  (see the stage's `plan.md` "Mid-Implementation Update" section and
  `tasks.md`'s T026-5) rather than deferred to a follow-up stage, since it
  directly affected code already being written in this stage.
