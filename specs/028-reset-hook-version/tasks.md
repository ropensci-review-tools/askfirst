---
created: 2026-07-31T00:00:00Z
agent: claude-sonnet-5
git_hash: 890fc451edc257dc0f79c69b39f6d9af0d446228
---

# Tasks: reset-hook-version

## T028-1: Reset hook_version in manifest.json
- [x] T028-1: In `agent-hooks/manifest.json`, change `"hook_version": 4` to
  `"hook_version": 1`. This becomes the sole file where this number is ever
  hand-edited going forward.

## T028-2: Add manifest-derived version-marker substitution to the generator
- [x] T028-2: In `agent-hooks/generate-install-hooks.sh`, add a new step in
  Pass 1 (placed alongside the existing `KNOWN_TOOLS` derivation, after the
  escalation-reminder splicing and before the "regenerated (pass 1)" echo):
  read `hook_version` from `MANIFEST_SRC` via
  `jq -r '.hook_version' "$MANIFEST_SRC"`, then use `sed -i` to rewrite the
  `askfirst-hook-version:` marker line in place in each of `$SESSION_SRC`,
  `$POST_SRC`, `$USER_PROMPT_SRC` (shell-comment form, `# askfirst-hook-version: `)
  and `$PLUGIN_SRC` (JS-comment form, `// askfirst-hook-version: `). Match on
  the fixed `askfirst-hook-version:` prefix (e.g.
  `s/^\(# askfirst-hook-version: \).*/\1${hook_version}/` and the `//` variant
  for `$PLUGIN_SRC`), not on the literal old number, so the substitution
  keeps working after future bumps regardless of the file's current value.
  Add a one-line comment above this block explaining that these four files'
  version markers are now generated from `manifest.json`, not hand-maintained.
  Update the script's own header comment (the numbered list of
  what triggers regeneration) to mention that editing `manifest.json`'s
  `hook_version` also requires regeneration, if not already implied by the
  existing `agent-hooks/manifest.json` entry there.

## T028-3: Regenerate the canonical per-tool files and the installer
- [x] T028-3: Run `bash agent-hooks/generate-install-hooks.sh` once. Confirm
  via `git diff` that the three Claude Code scripts' and the plugin file's
  `askfirst-hook-version` lines now read `1`, and that
  `agent-hooks/install-agent-hooks.sh`'s four spliced copies of those same
  lines also read `1`. Run the script a second time and confirm `git diff`
  shows no further changes (idempotency).

## T028-4: Update stale test fixtures to the new current version
- [x] T028-4: In `bindings/r/tests/testthat/test-init.R`, change both
  occurrences of `"# askfirst-hook-version: 4"` (lines ~328 and ~380) to
  `"# askfirst-hook-version: 1"`. In
  `bindings/r/tests/testthat/test-hooks-status.R`, change the two fixtures
  representing the current/up-to-date version (`"# askfirst-hook-version: 4"`
  at line ~39 and `"// askfirst-hook-version: 4"` at line ~52, plus the
  occurrence at line ~64) to version `1`. Leave the deliberately-stale
  fixture (`"// askfirst-hook-version: 0"` at line ~26) unchanged, since it
  exists to test the "stale" detection branch and only needs to remain lower
  than the current version.

## T028-5: Run the full test suite and confirm no other references remain
- [x] T028-5: Run `grep -rn "askfirst-hook-version: [0-9]" .` (excluding
  `.git/`) and confirm every remaining literal reference to a specific
  version number is either `1` (current) or `0` (the intentional stale
  fixture in `test-hooks-status.R`) — no leftover `4`. Run the R test suite
  (`make test` or `testthat::test_local("bindings/r")`) and the opencode
  plugin's `bun test` suite, and confirm both pass.

## Notes (discovered during implementation)
- `bindings/r/R/hooks_status.R:33` (`askfirst_hooks_manifest()`) holds a
  fifth, previously unaccounted-for hardcoded copy of `hook_version = 4L` —
  a hand-maintained compiled-in mirror of `agent-hooks/manifest.json`,
  needed because the installed R package doesn't ship the repo-relative
  `agent-hooks/` directory at all. This wasn't caught by T028-5's
  `askfirst-hook-version: <N>` grep pattern (different literal format, no
  colon-prefixed marker string), and running the R test suite after T028-4
  surfaced it directly: 6 failures, all traced to `askfirst_hooks_status()`
  comparing marker files now reading `1` against this still-`4` compiled-in
  copy and reporting `"stale"`. Fixed in place (`4L` → `1L`); this brought
  all 6 failures to pass with no other changes needed.
- Mid-implementation, the user separately asked to update the placeholder
  docs URL `https://ropensci.github.io/askfirst/` (a pkgdown site that
  doesn't exist yet) to `https://github.com/ropensci-review-tools/askfirst`
  everywhere live. This was unrelated to the hook_version reset but applied
  in the same session: fixed the one live source
  (`bindings/r/R/lang.R`'s `askfirst_url()`) and its two dependent test
  assertions in `test-init.R`; left the same string as it appears in frozen
  historical stage records (`specs/007-*`, `specs/014-*`) untouched, since
  those are point-in-time records of what was true when written, not live
  documentation.
