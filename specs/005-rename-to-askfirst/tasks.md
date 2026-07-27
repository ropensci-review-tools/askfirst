---
created: 2026-07-27T10:20:00Z
agent: claude-sonnet-5
git_hash: 21ac2c386aa3fa5bfd3c8478a56f3971e54710f0
---

# Tasks: rename-to-askfirst

Note on scope discovered while surveying: `flag_capability_gap()` is
renamed to `askfirst_capability_gap()` this stage too (per the resolved
decision), which means **four** `.Rd` files become orphaned after
regeneration (`pkghooks_init.Rd`, `pkghooks_check_scenarios.Rd`,
`pkghooks-package.Rd`, and `flag_capability_gap.Rd`), not the three
`plan.md` originally listed before that rename was decided. Similarly,
`bindings/r/tests/testthat/helper-state.R`'s own helper function
`local_reset_pkghooks_state()` also needs renaming (found by a full
symbol grep across `tests/`, not just `R/`) — `plan.md`'s survey covered
`R/` but this helper lives in `tests/`.

## T005-1: Rename the DESCRIPTION Package field
- [x] T005-1: In `bindings/r/DESCRIPTION`, change `Package: pkghooks` to
  `Package: askfirst`. Leave `Title:`/`Description:` text unchanged (they
  never literally said "pkghooks").

## T005-2: Rename all pkghooks_*-prefixed functions and the internal state object
- [x] T005-2: Across every file in `bindings/r/R/`, rename each of the
  following (definition sites and every call site) from `pkghooks_*`/
  `.pkghooks_state` to `askfirst_*`/`.askfirst_state`: `pkghooks_init`,
  `pkghooks_check_scenarios`, `pkghooks_signal`, `pkghooks_detect_tool`,
  `pkghooks_detect_confidence`, `pkghooks_ensure_detection`,
  `pkghooks_install_error_handler`, `pkghooks_error_handler`,
  `pkghooks_error_originates_from`, `pkghooks_build_notice`,
  `pkghooks_build_scenario_check_message`, `pkghooks_agents_path`,
  `pkghooks_load_agents`, `pkghooks_eval_condition`, and
  `.pkghooks_state`. Use a word-boundary-anchored substitution and verify
  afterward with `grep -rn 'pkghooks' bindings/r/R/` returning nothing.

## T005-3: Rename flag_capability_gap() to askfirst_capability_gap()
- [x] T005-3: In `bindings/r/R/capability_gap.R`, rename the exported
  function `flag_capability_gap` to `askfirst_capability_gap` (definition,
  roxygen `@export`/`@examples` content, and its own internal logic).
  Update every call site elsewhere in `bindings/r/R/` (there should be
  none besides its own definition, since it's a leaf function) and note
  the file itself can keep its current name (`capability_gap.R`) since R
  source file names don't need to match exported function names.

## T005-4: Rename the five condition-class strings
- [x] T005-4: In `bindings/r/R/conditions.R`, `init.R`, and `scenarios.R`,
  rename every literal condition-class string passed to
  `askfirst_signal()` (post-T005-2 rename): `"pkghooks_condition"` →
  `"askfirst_condition"`, `"pkghooks_notice"` → `"askfirst_notice"`,
  `"pkghooks_error_redirect"` → `"askfirst_error_redirect"`,
  `"pkghooks_capability_gap"` → `"askfirst_capability_gap"` (used by
  T005-3's renamed function), `"pkghooks_scenario_check"` →
  `"askfirst_scenario_check"`. Update roxygen documentation prose in each
  of these files that names the old class strings.

## T005-5: Rename the package-level doc file
- [x] T005-5: `git mv bindings/r/R/pkghooks-package.R
  bindings/r/R/askfirst-package.R`. Update its `"_PACKAGE"` roxygen block:
  the title line ("pkghooks: Detect and Redirect...") becomes ("askfirst:
  Detect and Redirect..."), and its references to `[pkghooks_init()]`/
  `[flag_capability_gap()]` become `[askfirst_init()]`/
  `[askfirst_capability_gap()]`.

## T005-6: Update all test files
- [x] T005-6: Across `bindings/r/tests/testthat/*.R` (all 7 files:
  `test-detect.R`, `test-confidence.R`, `test-init.R`,
  `test-capability-gap.R`, `test-scenarios.R`,
  `helper-agents.R`, `helper-state.R`) and `bindings/r/tests/testthat.R`:
  apply the same T005-2/T005-3/T005-4 renames to every call site and
  `expect_s3_class()`/class-string assertion, and rename
  `helper-state.R`'s own `local_reset_pkghooks_state()` function to
  `local_reset_askfirst_state()` (its one call site is at the top of
  nearly every test in `test-init.R`, `test-capability-gap.R`, and
  `test-scenarios.R`). Verify afterward with
  `grep -rn 'pkghooks' bindings/r/tests/` returning nothing.

## T005-7: Regenerate documentation and remove orphaned .Rd files
- [x] T005-7: Run `roxygen2::roxygenise()` from `bindings/r/` (run it
  twice if the first pass warns about unresolved cross-references between
  newly-renamed topics, matching the pattern from stages 003–004). Delete
  the four now-orphaned files: `bindings/r/man/pkghooks_init.Rd`,
  `bindings/r/man/pkghooks_check_scenarios.Rd`,
  `bindings/r/man/pkghooks-package.Rd`, and
  `bindings/r/man/flag_capability_gap.Rd`. Confirm `bindings/r/NAMESPACE`
  now exports `askfirst_init`, `askfirst_check_scenarios`, and
  `askfirst_capability_gap`.

## T005-8: Update MANUAL_TESTING.md
- [x] T005-8: In `bindings/r/MANUAL_TESTING.md`, update the `.onLoad()`
  example to call `askfirst::askfirst_init(...)`, the capability-gap
  example to call `askfirst::askfirst_capability_gap(...)`, and every
  mention of `pkghooks::pkghooks_check_scenarios()` to
  `askfirst::askfirst_check_scenarios()`. Update the one prose reference
  to `bindings/r/R/init.R`'s internals if it names a renamed function.

## T005-9: Update CI workflow and agent-detect-spec README prose
- [x] T005-9: In `.github/workflows/sync-agent-detect-spec.yml`, change
  the one prose mention ("The `pkghooks` R package's own copy...") to say
  `askfirst`. In `agent-detect-spec/README.md`, update its two prose
  mentions of `pkghooks` (the consumer description and the
  duplication-avoidance rationale) to say `askfirst`.

## T005-10: Update the root specs/design-decisions.md
- [x] T005-10: In `specs/design-decisions.md`, update the document title
  and "Current Architecture" section to describe `askfirst` rather than
  `pkghooks`. In each `Key Decisions` entry, update `**Outcome:**`/
  `**Rationale:**` text that names a specific current `pkghooks_*`
  function, file, or condition-class string to its `askfirst_*`
  equivalent (e.g. "`pkghooks_init()` computes..." →
  "`askfirst_init()` computes..."). Leave narrative prose that describes
  *what happened during a given stage* (e.g. "Stage 001 found direct
  prior art...", "**Stages:** 001, 002, 003" attribution lines) unchanged,
  since those are accurate historical narration, not current-state
  description.

## T005-11: Verify no regressions
- [x] T005-11: Run `devtools::test("bindings/r")` — confirm all
  previously-passing tests (now referencing `askfirst_*` names) still
  pass with 0 failures. Run
  `rcmdcheck::rcmdcheck("bindings/r", args = c("--no-manual", "--as-cran"), error_on = "warning")`
  — confirm 0 errors, 0 warnings, and the same single "New submission"
  NOTE as every prior stage (now for package `askfirst` instead of
  `pkghooks`).
