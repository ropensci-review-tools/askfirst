---
created: 2026-07-27T10:40:00Z
agent: claude-sonnet-5
git_hash: 690e1293bd25d48a746652f6368d2321c4b6c524
---

# Design Decisions: rename-to-askfirst

## Summary
This stage renamed the R package and every `pkghooks`-prefixed symbol
(functions, internal state object, condition classes) to `askfirst`
throughout the repo's current contents, following a naming brainstorm
that ruled out `askahuman` due to an existing, unrelated GitHub project.
53 tests and a clean `R CMD check` confirm the rename introduced no
behavior change.

## New Design Decisions

### Decision 1: Adopt askfirst, accepting an npm name conflict
**Chosen:** `askfirst` as the project/package name, confirmed unclaimed on
GitHub/CRAN/PyPI but already taken on npm.
**Rationale:** npm has heavy name-squatting for short, generic-sounding
words; a scoped/suffixed variant (`askfirst-js`, `@askfirst/js`) is normal
practice once a JS binding actually exists, rather than compromising the
primary name now for an ecosystem this project hasn't built into yet.
**Tradeoffs:** A future JS binding won't get the bare `askfirst` npm name.

### Decision 2: In-repo rename only; external rename deferred
**Chosen:** Package name, all `pkghooks_*` functions/state/condition
classes, docs, and CI prose renamed within the repo. The GitHub repository
name and local working directory are untouched by this stage.
**Rationale:** The user will handle both separately; no git remote was
configured, so nothing external broke in the interim.
**Tradeoffs:** The local directory (`pkghooks/`) and any future GitHub
repo will keep not matching the package name until that separate step
happens.

### Decision 3: Historical stage documents preserved as-is
**Chosen:** `specs/001-detect-llm-callers` through
`specs/004-scenario-check` are entirely unchanged. Only the root
`specs/design-decisions.md` was updated, since its stated purpose
("Current Architecture") is continuously revised, unlike per-stage
documents that record a fixed point in history.
**Rationale:** Matches this project's established precedent (stage 002)
of treating `specs/` as an honest historical record.
**Tradeoffs:** None significant.

### Decision 4: flag_capability_gap() renamed for API consistency
**Chosen:** `flag_capability_gap()` → `askfirst_capability_gap()`,
including its condition-class string (which already coincidentally became
`"askfirst_capability_gap"` via the class-string rename, so the function
and the condition it signals now share one name).
**Rationale:** Closes the one inconsistency in the exported API surface —
every other exported function already carried an `askfirst_`-matching
prefix. Confirmed directly by the user, not inferred from literal-text
substitution (the old name never contained "pkghooks").
**Tradeoffs:** None significant; package is unreleased (`0.0.0.9000`), so
no external adopters are broken.

## Integration with Prior Work
Builds directly on the registry, signaling helper, and condition-class
hierarchy from stages 003–004, and on the `bindings/r/` relocation that
preceded stage 004 — this rename is the first change to touch every file
in that structure at once, and served as an end-to-end confirmation that
the `bindings/r/` layout and its CI workflows tolerate a full package
rename cleanly.

## Issues Resolved
- Whether to reconsider the `askfirst` name given the npm conflict:
  resolved no — proceed, treat npm naming as a separable, later concern.
- Scope of the rename (in-repo vs. also external repo/directory):
  resolved as in-repo only, with the external rename explicitly delegated
  to the user.
- Whether `flag_capability_gap()` should also be renamed: resolved yes.

## Deferred Items
- Renaming the GitHub repository and local working directory (the user's
  own task).
- Checking `askfirst`'s name availability on CRAN specifically, before any
  future release.
- A scoped/suffixed npm name, if a JS binding is ever built.

## Process Notes
- The mechanical rename was done as ordered, longest-string-first literal
  substitution (not regex word-boundaries) across a fixed file list,
  chosen to avoid partial-prefix collisions between symbols that share a
  common substring (e.g. `pkghooks_error_handler` vs.
  `pkghooks_error_originates_from`).
- Two gaps in `plan.md`'s original file survey were caught during
  implementation, not anticipated in the plan: `bindings/r/tests/`'s own
  `local_reset_pkghooks_state()` helper (the survey covered `R/` but not
  `tests/`), and a stray comment reference in
  `bindings/r/data-raw/sync-vendor.R`. Both were found by grepping the
  full repo after the main substitution pass, not by re-reading the plan.
