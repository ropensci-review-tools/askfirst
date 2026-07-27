---
created: 2026-07-27T10:04:43Z
agent: claude-sonnet-5
git_hash: 21ac2c386aa3fa5bfd3c8478a56f3971e54710f0
---

# Plan: rename-to-askfirst

## Overview
Rename the R package and every `pkghooks`-prefixed symbol (functions,
internal state object, condition classes) to `askfirst` throughout this
repo's current contents: the `DESCRIPTION`, all R source and test files,
regenerated `NAMESPACE`/`man/`, `MANUAL_TESTING.md`, the two CI workflows,
`agent-detect-spec/README.md`'s prose references, and the root
`specs/design-decisions.md`'s forward-looking "Current Architecture"
content. Historical stage documents (`specs/001-004/*`) are left
unchanged, since they accurately record decisions made when the package
was literally named `pkghooks`. The external GitHub repository name and
the local working directory are explicitly out of scope for this stage —
this repo has no configured git remote right now, so there is nothing
external to break, but that operational change is deliberately deferred
to be done separately rather than folded into this text/code rename.

## Context
This is the project's fifth design stage, following stage 004
(`specs/004-scenario-check/`), which added `pkghooks_check_scenarios()` to
the R package built in stage 003 (`bindings/r/`). The name `askfirst` was
chosen this session (in conversation, not yet reflected in any `specs/`
document) after `askahuman` was ruled out due to an existing, unrelated
`github.com/askahuman` project creating a name-conflict risk.

Four clarifying questions were raised before this plan and went
unanswered directly, so this stage proceeds on the following assumed
defaults — flagged here for correction if wrong:
- **Scope**: in-repo rename only (package/function/class names, docs, CI
  references). The GitHub repository name and local directory name are
  *not* changed in this stage.
- **Historical accuracy**: `specs/001-detect-llm-callers` through
  `specs/004-scenario-check` keep referring to `pkghooks`, matching what
  the package was actually called at each point in its history — this
  project has an established precedent (stage 002) of treating `specs/`
  as an honest historical record rather than a document to retroactively
  clean up. The root `specs/design-decisions.md` is a different case: its
  own stated purpose is "Current Architecture," continuously revised —
  after this rename, leaving stale `pkghooks_*` references there would be
  actively wrong, not merely historical, so it *is* updated by this stage
  wherever it describes present-day names.
- **Condition classes**: `pkghooks_condition`, `pkghooks_notice`,
  `pkghooks_error_redirect`, `pkghooks_capability_gap`,
  `pkghooks_scenario_check` are renamed to their `askfirst_*` equivalents,
  since the package has no external adopters yet (unreleased, version
  `0.0.0.9000`) and renaming now avoids a later breaking change.
- **GitHub org**: moot for this stage, since no rename of the external
  repo is happening here; if/when it is, staying under
  `ropensci-review-tools` is the assumed default.

All four questions have since been resolved directly by mpadge:
1. **`flag_capability_gap()` renaming**: yes, rename to
   `askfirst_capability_gap()`.
2. **GitHub repo / local directory rename**: mpadge will do this
   themselves, separately — confirms this stage's assumed scope (in-repo
   text/code only) is correct.
3. **Name availability**: mpadge checked and `askfirst` is unclaimed
   everywhere except npm. Discussed and decided to proceed with
   `askfirst` regardless — npm has heavy name-squatting for short,
   generic-sounding words, and it's normal practice for a project to use
   a scoped/suffixed variant (e.g. `askfirst-js`, `@askfirst/js`) in one
   registry once a binding for that ecosystem actually exists, rather than
   compromising the primary name now for a language this project hasn't
   built yet.

Surveyed scope of the rename (from grepping the current repo):
- **Function/object names** (all in `bindings/r/R/`): `pkghooks_init`,
  `pkghooks_check_scenarios`, `pkghooks_signal`, `pkghooks_detect_tool`,
  `pkghooks_detect_confidence`, `pkghooks_ensure_detection`,
  `pkghooks_install_error_handler`, `pkghooks_error_handler`,
  `pkghooks_error_originates_from`, `pkghooks_build_notice`,
  `pkghooks_build_scenario_check_message`, `pkghooks_agents_path`,
  `pkghooks_load_agents`, `pkghooks_eval_condition`, and the internal state
  environment `.pkghooks_state`.
- **`flag_capability_gap()`** does not literally contain "pkghooks", so a
  literal substitution wouldn't touch it — but it's the one exported
  function without an `askfirst_`-style prefix, so it is *also* renamed
  this stage, to `askfirst_capability_gap()`, for API consistency
  (decided in conversation, not merely a literal-substitution artifact).
- **Files needing content changes**: `bindings/r/DESCRIPTION`,
  `bindings/r/R/*.R` (all 8 files), `bindings/r/R/pkghooks-package.R`
  (also a candidate for renaming the file itself),
  `bindings/r/tests/testthat/*.R` (all 7 files, including the two
  `helper-*.R` files), `bindings/r/MANUAL_TESTING.md`,
  `.github/workflows/sync-agent-detect-spec.yml` (one prose mention),
  `agent-detect-spec/README.md` (two prose mentions), and
  `specs/design-decisions.md` (the root aggregate).
- **Files needing no changes**: `.github/workflows/r-cmd-check.yml` (only
  references `bindings/r/**` paths, no package-name mentions);
  `agent-detect-spec/manifest.json`; `AGENTS.md`; `.designlens.json` — none
  of these mention `pkghooks`.
- **`bindings/r/man/*.Rd` and `NAMESPACE`**: regenerated automatically by
  `roxygen2::roxygenise()` once the underlying `.R` files are renamed; the
  old `pkghooks_init.Rd`/`pkghooks_check_scenarios.Rd`/`pkghooks-package.Rd`
  files must be deleted so they don't linger as orphaned, stale docs
  alongside the newly-generated `askfirst_*.Rd` files.

## Design Goals
- `DESCRIPTION`'s `Package:` field changes from `pkghooks` to `askfirst`;
  `Title:`/`Description:` text (which never literally said "pkghooks")
  needs no wording change beyond this.
- Every `pkghooks_*`-prefixed function and the `.pkghooks_state` internal
  environment is renamed to its `askfirst_*` equivalent, consistently
  across definition sites, call sites, and test files.
- `flag_capability_gap()` is renamed to `askfirst_capability_gap()`
  (confirmed decision, not merely literal substitution), including its
  `bindings/r/man/flag_capability_gap.Rd` regenerated under the new name,
  its `bindings/r/tests/testthat/test-capability-gap.R` call sites, and
  every prose mention in `MANUAL_TESTING.md`.
- The five condition classes (`pkghooks_condition`, `pkghooks_notice`,
  `pkghooks_error_redirect`, `pkghooks_capability_gap`,
  `pkghooks_scenario_check`) are renamed to `askfirst_*` equivalents,
  including every `pkghooks_signal()`/`pkghooks_build_notice()` call site
  and every test assertion checking condition class membership
  (`expect_s3_class()`).
- `bindings/r/R/pkghooks-package.R` is renamed to
  `bindings/r/R/askfirst-package.R`, and its `"_PACKAGE"` roxygen block
  updated to describe `askfirst` rather than `pkghooks`.
- `roxygen2::roxygenise()` is re-run after the rename to regenerate
  `NAMESPACE` and `man/`; the stale `pkghooks_init.Rd`,
  `pkghooks_check_scenarios.Rd`, and `pkghooks-package.Rd` files are
  deleted rather than left alongside the new ones.
- `bindings/r/MANUAL_TESTING.md`'s example code (the `.onLoad()` snippet,
  `flag_capability_gap()` call, `pkghooks_check_scenarios()` mentions) is
  updated to use `askfirst::askfirst_init()` etc., consistent with the
  renamed API.
- The one prose mention of `pkghooks` in
  `.github/workflows/sync-agent-detect-spec.yml` and the two in
  `agent-detect-spec/README.md` are updated to say `askfirst`.
- `specs/design-decisions.md` (the root aggregate) has its title and
  "Current Architecture" section updated to describe `askfirst`, and every
  `Key Decisions` entry's `**Outcome:**`/`**Rationale:**` text that
  currently names a specific `pkghooks_*` function, file, or condition
  class is updated to the renamed equivalent, since those describe
  present-day reality, not a frozen historical snapshot. Prose that
  narrates *what happened during a given stage* (e.g. "Stage 001 found
  direct prior art...") is left as accurate historical narration and not
  rewritten just to swap a name.
- After the rename, the full `testthat` suite and `R CMD check --as-cran`
  must both still pass cleanly (0 errors, 0 warnings), matching every
  prior stage's baseline — this is a pure rename, not a behavior change.
- Explicitly out of scope: renaming the GitHub repository and moving/
  renaming the local working directory (mpadge will handle both
  separately), and changing `specs/001-004`'s own historical documents.

## Proposed Approach
- Do the rename as a single, mechanical, verifiable pass rather than
  file-by-file ad hoc edits: first rename `.pkghooks_state` and every
  `pkghooks_*` function definition/call site consistently (a careful
  word-boundary-anchored substitution, checked against false positives the
  same way stage 002's `agent-detect-spec` → `bindings/r` path rename was
  verified — e.g. nothing in this repo is named like `somepkghooksthing`
  that could partially match), then handle the five condition-class
  strings the same way, then separately rename `flag_capability_gap()` →
  `askfirst_capability_gap()` (a distinct, decided rename, not part of the
  literal `pkghooks`→`askfirst` substitution).
- Rename `bindings/r/R/pkghooks-package.R` → `askfirst-package.R` via
  `git mv`, preserving history, matching the same approach used for the
  stage-004-preceding `r/` → `bindings/r/` move.
- Update `DESCRIPTION`'s `Package:` field directly.
- Re-run `roxygen2::roxygenise()` from `bindings/r/`, then delete the
  three now-orphaned `.Rd` files whose names still say `pkghooks_*`/
  `pkghooks-package` (roxygen2 does not automatically remove `.Rd` files
  for renamed topics).
- Update `MANUAL_TESTING.md`, the two workflow/README prose mentions, and
  the root `specs/design-decisions.md` as described in Design Goals.
- Verify with the same two-step check used throughout stages 003–004:
  `devtools::test("bindings/r")` (expect all previously-passing tests to
  still pass, now referencing `askfirst_*` names) and
  `rcmdcheck::rcmdcheck("bindings/r", args = c("--no-manual", "--as-cran"), error_on = "warning")`
  (expect 0 errors/warnings, same 1 expected "New submission" NOTE as
  every prior stage).
- Leave `specs/001-detect-llm-callers/` through
  `specs/004-scenario-check/` entirely untouched, per the historical-record
  decision above.
- Leave `bindings/r/` as the directory name (it names the *language*
  binding, not the package), `agent-detect-spec/` untouched (never
  package-name-specific), and the GitHub repo/local directory untouched.

## Open Questions
None outstanding. The three questions this plan started with are all
resolved (see Context): `flag_capability_gap()` is renamed too; the GitHub
repo/local directory rename is mpadge's own, separate task; and `askfirst`
is confirmed as the name to proceed with, accepting that a future JS
binding will need a scoped/suffixed npm name. Whether `askfirst` should
also be the R package's eventual CRAN submission name remains a genuinely
separate, later concern (CRAN name availability isn't the same check as
GitHub/npm), but doesn't block this stage.
