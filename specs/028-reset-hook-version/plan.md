---
created: 2026-07-31T00:00:00Z
agent: claude-sonnet-5
git_hash: 890fc451edc257dc0f79c69b39f6d9af0d446228
---

# Plan: reset-hook-version

## Overview
Reset `hook_version` in `agent-hooks/manifest.json` to `1`, since it has no
community usage yet and all four increments to date (stages 015/019/017/023,
landing at 4) were dev-only, pre-public churn. The project has just gone
public, so there is no installed base anywhere to leave behind by resetting
the counter now — this is the last point at which doing so is free.

## Context
Per `specs/design-decisions.md`'s "Hooks-installation detection" decision,
`hook_version` is a single counter shared across every tool (Claude Code,
opencode), read from `agent-hooks/manifest.json` and compared against a
`# askfirst-hook-version: <N>` (shell) / `// askfirst-hook-version: <N>` (JS)
marker comment embedded in each tool's canonical hook/plugin file. The
canonical sources live in `agent-hooks/claude/*.sh` and
`agent-hooks/opencode/askfirst-plugin.js`; `agent-hooks/generate-install-hooks.sh`
splices their content into the single distributable
`agent-hooks/install-agent-hooks.sh`, which is what
`askfirst_install_agent_hooks()` (R) and end users actually run. Today each of
the four canonical files hardcodes its own version-marker line independently
of `manifest.json`'s `hook_version` — kept in sync only by hand-discipline,
the same kind of gap stage 012 found already went stale once before (the
generated installer silently never received an earlier stage's hook-text
fix). This stage both performs the reset and closes that gap, by having the
generator derive the marker value from `manifest.json` directly instead —
the same generation-time-inheritance pattern it already uses for
`install-agent-hooks.sh`'s `KNOWN_TOOLS` array (stage 025). The underlying
hook logic each version bump shipped is otherwise unaffected; only the
version-number bookkeeping changes.

## Design Goals
- `agent-hooks/manifest.json`'s `hook_version` reads `1`, and becomes the
  *sole* place this number is ever written by hand from now on.
- The four canonical marker lines (three Claude Code shell scripts plus the
  opencode plugin) no longer hardcode their own literal version number;
  instead `agent-hooks/generate-install-hooks.sh` rewrites each marker
  in-place from `manifest.json`'s `hook_version` field every time it runs —
  the same generation-time-inheritance pattern the script already uses for
  `install-agent-hooks.sh`'s `KNOWN_TOOLS` array (stage 025, also sourced
  from `manifest.json` via `jq`). This removes the four-file manual-edit
  step for every future version bump: bump `manifest.json` once, regenerate,
  and every marker (plus the spliced copies in
  `agent-hooks/install-agent-hooks.sh`) follows automatically.
- Existing R test fixtures that hardcode the old value `4` as the
  "up to date" / "current" reference version are updated to `1`, so the test
  suite continues to assert the real current-version behavior rather than a
  stale historical one.
- No other behavioral change: this stage touches only version markers, the
  generator script, and their directly-dependent test fixtures — not
  hook/plugin logic itself.

## Proposed Approach
1. Edit `agent-hooks/manifest.json`: `hook_version` 4 → 1. This is now the
   only file where the number is ever hand-edited.
2. Extend `agent-hooks/generate-install-hooks.sh`'s Pass 1 (shared sources →
   per-tool canonical files) with a new step, alongside the existing
   `KNOWN_TOOLS` derivation: read `hook_version` from `manifest.json` via
   `jq`, then `sed`-substitute the `# askfirst-hook-version: <N>` line (three
   Claude Code scripts) and the `// askfirst-hook-version: <N>` line (the
   opencode plugin) in place, matching on the fixed
   `askfirst-hook-version:` prefix rather than the old literal number so the
   substitution keeps working after future bumps.
3. Remove the now-stale hardcoded `4` from the three Claude Code scripts and
   the plugin file by running the regenerator once (rather than hand-editing
   each), then run it again to confirm it's idempotent.
4. Run `agent-hooks/generate-install-hooks.sh` to regenerate
   `agent-hooks/install-agent-hooks.sh`'s four spliced copies (Pass 2 is
   unchanged — it still splices the per-tool canonical files verbatim, which
   now carry the value Pass 1 just wrote).
5. Update the hardcoded `askfirst-hook-version: 4` fixture lines in
   `bindings/r/tests/testthat/test-init.R` (2 occurrences) and
   `test-hooks-status.R` (2 occurrences representing "current") to `1`;
   leave `test-hooks-status.R`'s deliberately-stale fixture (currently
   `askfirst-hook-version: 0`) unchanged, since it exists specifically to
   test the "stale" branch and only needs to remain lower than whatever the
   current version is.
6. Run the full R test suite (`make test` / `testthat`) to confirm nothing
   else depends on the old literal value, and that `generate-install-hooks.sh`
   run twice in a row produces no diff (idempotency check).

## Open Questions
None — this is a narrowly scoped, mechanical version reset with no design
alternatives to weigh.
