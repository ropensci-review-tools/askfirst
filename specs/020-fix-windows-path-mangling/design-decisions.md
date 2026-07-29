---
created: 2026-07-29T12:12:46Z
agent: claude-sonnet-5
git_hash: a1324382a66f589854de7fadd3c42923c2a5a24d
---

# Design Decisions: fix-windows-path-mangling

## Summary
Fixed a genuine Windows-only `rcmdcheck()` failure — traced, from a
supplied failure log, to `askfirst_mangle_path()` leaving a Windows
drive-letter colon embedded in a mangled directory-name segment — and
separately adopted the `fs` package for path construction throughout
`bindings/r/`, correcting an initial request that had misattributed the
failure to `file.path()` itself.

## New Design Decisions

### Decision 1: Verify failure evidence before accepting a stated root cause
**Chosen:** Traced the actual backtrace from a supplied Windows CI failure
log to `askfirst_mangle_path()` in `bindings/r/R/state.R`, rather than
proceeding on the originally stated premise that `file.path()` was
unreliable on Windows.
**Rationale:** `file.path()` is R's standard cross-platform path
constructor; the real defect was an unhandled input shape (Windows
drive-letter absolute paths) in custom mangling logic that derives a
session-state directory name, leaving an illegal `:` character embedded
in a path component.
**Tradeoffs:** None — this reduced scope to what was actually broken.
**Proposed by:** agent

### Decision 2: Fix ported identically across all three language implementations
**Chosen:** `askfirst_mangle_path()` (R, using `fs::path_split()` to parse
paths correctly regardless of host OS), `agent-hooks/askfirst-state-dir.sh`
(bash), and `agent-hooks/opencode/askfirst-plugin.js`'s
`askfirstMangleTermPath()` (JS) all received the equivalent fix
(normalize backslashes, strip a POSIX leading `/`, replace remaining `/`
with `_`, strip drive-letter colons), verified to produce byte-identical
output across all three, and the shared
`agent-hooks/askfirst-state-dir-fixture.txt` was extended with
Windows-style cases that all three implementations' test suites already
consume.
**Rationale:** Stage 018 established that this mangling scheme must stay
byte-identical across R, bash, and JS, since the R package and
coding-agent hook scripts derive the same session-state directory
independently with no other coordination channel.
**Proposed by:** joint
**Relates to:** Stage 018 (established the shared fixture and
cross-language byte-identity invariant this stage preserves)

### Decision 3: Adopt fs::path() throughout bindings/r/, without leaking its class
**Chosen:** Every `file.path()` call in `bindings/r/R/`, `data-raw/`, and
`tests/testthat/` was replaced with `fs::path(...)`, with every result
immediately wrapped in `as.character()` so the `fs_path` S3 class never
escapes an internal function's return value or a test's expected-value
construction.
**Rationale:** `testthat`'s `waldo`-based `expect_equal()` is
class-sensitive; several existing tests compare state-directory helper
functions' return values directly against plain-character expected
values, so an unwrapped `fs_path` object would have silently broken those
comparisons.
**Tradeoffs:** Larger diff than the minimal bug fix alone required, in
exchange for consistency with the originally requested outcome.
**Proposed by:** git-user

### Decision 4: TMPDIR fallback made portable
**Chosen:** `askfirst_state_dir()`'s `Sys.getenv("TMPDIR", unset = "/tmp")`
fallback (R side only) now uses `tempdir()` instead of a hardcoded
`"/tmp"`, which does not exist on native Windows R. The bash/JS
`${TMPDIR:-/tmp}` fallbacks were left unchanged, since those run under
Git Bash/WSL/a real POSIX shell where `/tmp` genuinely exists.
**Proposed by:** git-user

### Decision 5: Local verification insufficient; real CI confirmation required
**Chosen:** The plan's final step withheld considering this stage resolved
until a real `windows-latest` CI run confirmed the fix, since the bug is
platform-specific and not reproducible on Linux. A follow-up issue was
found this way: the `check-vendor-sync` CI job (unlike the `r-cmd-check`
matrix job) had no dependency-installation step at all, so it broke once
its scripts started calling `fs::path()`. Fixed by adding
`r-lib/actions/setup-r-dependencies@v2` to that job, matching the
convention already used by the sibling `r-cmd-check` job, rather than an
ad hoc package-install step.
**Rationale:** Confirms the value of the explicit wait-for-real-CI step —
it caught a second, related failure that local verification could not
have revealed.
**Proposed by:** git-user

## Integration with Prior Work
Extends stage 018's shared-fixture, byte-identical cross-language mangling
scheme without altering its structure — only the algorithm each side
implements. Independent of stage 019's `agent-content/` work (different
files, no overlap), completed immediately prior in the same package.

## Issues Resolved
- Windows `rcmdcheck()` failures writing session-state files (root cause:
  unhandled drive-letter colon in mangled path) — resolved via the
  cross-language mangling fix.
- `check-vendor-sync` CI job breakage following this stage's own `fs`
  migration — resolved by adding proper dependency installation to that
  job.

## Deferred Items
None — all items raised during planning were resolved and completed
within this stage.

## Process Notes
- The stage's scope was corrected during planning after the agent
  investigated the stated premise against actual source code and found it
  didn't hold; the user then supplied a real failure log that confirmed
  the corrected diagnosis.
- One open question (documentation wording for the Windows-handling
  behavior) was resolved directly during implementation rather than left
  open.
- A second CI failure (the `check-vendor-sync` job lacking dependency
  installation) was discovered only after real Windows CI confirmed the
  primary fix, and was fixed within the same stage rather than deferred.
