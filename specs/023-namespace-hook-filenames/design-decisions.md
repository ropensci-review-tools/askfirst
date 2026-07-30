---
created: 2026-07-30T12:04:09Z
agent: claude-sonnet-5
git_hash: 50b71277d6f64fb216dbf1c5db0963dff2338c49
---

# Design Decisions: namespace-hook-filenames

## Summary
Renamed askfirst's three Claude Code hook script files to askfirst-namespaced
filenames, closing a collision risk where the installer's prior generic
filenames (`session_start.sh`, `post_tool_use.sh`, `user_prompt_submit.sh`)
could already be occupied by an unrelated tool's own hook scripts in a
shared `.claude/hooks/` directory.

## New Design Decisions

### Decision 1: Askfirst-namespaced Claude Code hook filenames
**Chosen:** `agent-hooks/claude/session_start.sh`,
`post_tool_use.sh`, and `user_prompt_submit.sh` were renamed to
`askfirst-session-start.sh`, `askfirst-post-tool-use.sh`, and
`askfirst-user-prompt-submit.sh`, with `install-agent-hooks.sh`'s
`write_*` functions and `register_hooks_claude`'s registered `command`
strings updated to match, alongside `agent-hooks/manifest.json`'s and
`bindings/r/R/hooks_status.R`'s `marker_file` value.
**Rationale:** A field report found the installer's prior generic
filenames are exactly the kind another tool might already use in
`.claude/hooks/` — confirmed concretely against this repo itself, where
those exact filenames already belong to `designlens`. The installer's
prior behavior would either silently clobber such a file (with
`--overwrite`) or silently fail to install askfirst at all (without it,
since `write_session_start`'s non-zero return under `set -e` aborts the
whole script before any other hook gets written or registered).
Namespacing removes the collision possibility at its root, rather than
mitigating a specific instance of it.
**Tradeoffs:** Touches every location that hardcodes the old filenames —
the installer, `manifest.json`, `hooks_status.R`, several tests, and
doc-only prose in `log.R`/`state.R`/the development vignette. No
migration path was built for pre-existing installs at the old filenames;
a fresh `install-agent-hooks.sh` run is sufficient.
**Proposed by:** mpadge (problem report), joint (fix design)

### Decision 2: Verified filename-independence on two separate axes before implementing
**Chosen:** Confirmed, before writing any code, that (a) Claude Code
dispatches hooks purely via the `command` string registered in
`settings.json` — no filename-convention-based discovery exists (unlike
git's `.git/hooks/pre-commit` pattern) — and (b) none of askfirst's three
hook scripts derive behavior from their own filename or from a hardcoded
reference to a sibling script's filename; cross-references between
`post_tool_use.sh` and `user_prompt_submit.sh` are documentation comments
only.
**Rationale:** The filenames (`session_start`, `post_tool_use`,
`user_prompt_submit`) suggest a temporal sequence; renaming is only safe
if that sequence is governed by something other than the literal
filename. Point (a) was confirmed against official Claude Code hooks
documentation; point (b) was confirmed by grepping all three scripts for
`$0`/`basename` self-reference and cross-script filename dependencies.
The one `basename` call found (in `post_tool_use.sh`) extracts a package
name from a state-marker file, unrelated to the hook script's own name.
**Tradeoffs:** None — this was verification work, not a design tradeoff.
**Proposed by:** joint

## Integration with Prior Work
Extends stage 014's `agent-hooks/manifest.json`/`hooks_status.R`
version-marker mechanism (updating its `marker_file` value rather than
its structure) and stage 012/018's dev-time generation pattern
(`agent-hooks/generate-install-hooks.sh`, whose own hardcoded source
paths also needed updating to reference the renamed canonical files).
opencode's side is unaffected — `askfirst-plugin.js` was already
namespaced under `.opencode/plugins/`, which auto-discovers by directory
rather than a fixed conventional filename.

## Issues Resolved
- Installer hook-filename collision risk reported via
  `askfirst-advice.md`-style field feedback: closed by namespacing,
  verified with a new regression test that models another tool's
  pre-existing hook scripts at the old generic filenames and confirms
  the installer leaves them untouched while still installing and
  registering askfirst's own (renamed) hooks alongside them.

## Deferred Items
- No migration/cleanup logic for pre-existing installs at the old generic
  filenames — explicitly out of scope; a fresh install is sufficient.

## Process Notes
- The rename's safety was verified on two independent axes (Claude Code's
  dispatch mechanism, and the scripts' own internal logic) before any
  code was written, in direct response to the human's specific question
  about whether the filenames encoded a load-bearing temporal sequence.
- `agent-hooks/generate-install-hooks.sh` itself hardcoded the old
  canonical source paths and needed updating before regeneration would
  succeed — found when the first regeneration attempt failed with a
  missing-file error, not anticipated in the original plan.
