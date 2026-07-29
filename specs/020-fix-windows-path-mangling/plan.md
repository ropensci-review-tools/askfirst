---
created: 2026-07-29T11:34:33Z
agent: claude-sonnet-5
git_hash: 0b9799c2ee2da5f14cb0011f286ae36d356e445c
---

# Plan: fix-windows-path-mangling

## Overview
Fix R CMD check failures on Windows CI runners: askfirst_mangle_path() (bindings/r/R/state.R) strips a leading POSIX / and replaces remaining / with _, but does not handle Windows drive-letter absolute paths (e.g. C:/Users/...), leaving the drive-letter colon embedded in a directory-name path segment -- illegal on Windows filesystems, causing every writeLines()/file() call under askfirst_state_dir() to fail with 'Invalid argument' (observed in test-capability-gap.R and hundreds of similar cases across the test suite on windows-latest runners). Fix askfirst_mangle_path() using fs::path_split() to robustly decompose the path (correctly recognizing Windows drive-letter and POSIX root components regardless of host OS), drop the POSIX root marker, strip ':' and backslash characters from remaining components, and join with '_' -- verified to produce byte-identical output to the existing POSIX fixture cases and correct output for Windows-style paths. Apply the equivalent algorithmic fix to the two other independently-maintained ports of this same mangling logic: agent-hooks/askfirst-state-dir.sh (bash, spliced into Claude Code's post_tool_use.sh/user_prompt_submit.sh) and agent-hooks/opencode/askfirst-plugin.js's askfirstMangleTermPath() (JS), keeping all three byte-identical per the existing documented invariant and shared askfirst-state-dir-fixture.txt cross-check; add new Windows-style fixture cases. Also fix askfirst_state_dir()'s TMPDIR-fallback default (currently hardcoded /tmp, fragile on native Windows R) to use base R's tempdir() instead. Additionally, adopt the fs package for path construction throughout bindings/r/ (R/, data-raw/, tests/testthat/) in place of file.path(), for consistency -- wrapping every fs::path() result in as.character() so no fs_path-classed value escapes an internal function's return value, preserving exact behavioral/type compatibility with existing tests (testthat's waldo-based expect_equal() is class-sensitive) and the public API surface.

## Context

**Original request vs. verified root cause:** this stage was requested as
"replace all path operations with `fs` because `file.path()` is unreliable
on Windows CI runners." `file.path()` is R's standard, well-tested,
cross-platform path constructor; it was not, on inspection, the actual
cause. The user supplied a real failure log from a Windows `rcmdcheck()`
run:

```
cannot open file 'C:\Users\RUNNER~1\...\pending\mypkg-capability_gap.txt':
Invalid argument
```

Tracing the backtrace (`askfirst_capability_gap()` →
`askfirst:::askfirst_signal()` → `askfirst_write_pending()` →
`base::writeLines()` → `base::file()`) leads to
`bindings/r/R/state.R`'s `askfirst_mangle_path()`:

```r
askfirst_mangle_path <- function(path) {
  gsub("/", "_", sub("^/", "", path))
}
```

On Windows, `getwd()` returns paths like
`C:/Users/RUNNER~1/AppData/Local/Temp/.../file1cfc1a0616af` (R normalizes
backslashes to forward slashes, but the drive letter's colon is untouched).
`sub("^/", "", path)` does nothing (no leading `/`), and `gsub("/", "_",
...)` leaves the colon in place, producing a directory-name segment
containing a literal `:` — illegal in a Windows path component outside the
drive prefix. Every `stop-and-ask` signal writes a pending file under
`askfirst_state_dir()` (via `askfirst_write_pending()` in `log.R`), so this
single bug explains "hundreds of" failures across the suite on
`windows-latest`, not a `file.path()` problem anywhere.

**The mangling function is deliberately triplicated, not shared, across
three languages** (`bindings/r/R/state.R`'s `askfirst_mangle_path()`;
`agent-hooks/askfirst-state-dir.sh`'s `askfirst_state_dir()` bash function,
spliced by `generate-install-hooks.sh` into
`agent-hooks/claude/post_tool_use.sh`/`user_prompt_submit.sh`;
`agent-hooks/opencode/askfirst-plugin.js`'s `askfirstMangleTermPath()`),
documented as needing to produce **byte-identical output** for a given
`cwd`/path input across all three, since the R package and the coding-agent
hook scripts derive the *same* session-state directory independently, with
no other coordination channel. A shared fixture,
`agent-hooks/askfirst-state-dir-fixture.txt`, cross-checks all three
implementations (`bindings/r/tests/testthat/test-log.R`,
`agent-hooks/opencode/askfirst-plugin.test.js`) against the same
input/output pairs (stage 018, Design Goal 4). Fixing only the R side would
silently break this invariant for opencode/Claude-Code sessions running
under Windows-flavored shells (e.g. Git Bash, WSL), even though this
stage's triggering failure is specifically `rcmdcheck()` on native Windows
R.

**Resolved during requirements gathering:** given the real root cause, the
stage was rescoped from a blanket "replace `file.path()` with `fs`
everywhere" to two combined parts — (1) a targeted, verified fix to the
mangling algorithm across all three language ports plus the shared
fixture, and (2) adopting the `fs` package specifically for how the R side
implements that fix and for path construction generally across
`bindings/r/`, in place of `file.path()`, for consistency (the user's
originally requested outcome), now correctly scoped to what actually needs
to change.

## Design Goals

- Fix the verified root cause: `askfirst_mangle_path()` (and its bash/JS
  ports) must produce a filesystem-safe directory-name segment for
  Windows-style drive-letter absolute paths, not just POSIX absolute
  paths.
- Preserve the existing, documented cross-language invariant: all three
  implementations must keep producing byte-identical output for the same
  input, verified against a single shared fixture file extended with new
  Windows-style cases.
- Preserve exact backward-compatible output for every existing (POSIX)
  fixture case — this is a bug fix for an unhandled input shape, not a
  change to the existing, working mangling scheme.
- Use `fs::path_split()` on the R side specifically because it correctly
  parses Windows drive-letter and POSIX root components regardless of the
  *host* OS running the code (verified empirically: running on Linux,
  `fs::path_split("C:/Users/...")` still correctly isolates `"C:"` as its
  own component) — this lets the fix be verified and tested on any
  developer/CI machine, not only on an actual Windows runner.
- Adopt `fs::path()` for path construction throughout `bindings/r/` (`R/`,
  `data-raw/`, `tests/testthat/`), replacing `file.path()`, per the
  original request — without letting `fs`'s `fs_path` S3 class leak into
  any function's observable return value, since `testthat`'s
  `waldo`-based `expect_equal()` is class-sensitive and several existing
  tests compare `askfirst_state_dir()`'s return value directly against a
  plain-character expected value.
- Also fix `askfirst_state_dir()`'s `Sys.getenv("TMPDIR", unset = "/tmp")`
  fallback, which is separately fragile on native Windows R (no `/tmp`
  exists there) — not implicated in the observed failure (CI already had
  `TMPDIR` set to a real path), but directly adjacent to the code this
  stage is already touching, and an equally clear Windows-portability gap.

## Proposed Approach

**Fix `askfirst_mangle_path()` (`bindings/r/R/state.R`)** using
`fs::path_split()`:

```r
askfirst_mangle_path <- function(path) {
  parts <- fs::path_split(path)[[1]]
  parts <- parts[parts != "/"]
  parts <- gsub("[:\\\\]", "", parts)
  as.character(paste(parts, collapse = "_"))
}
```

Verified empirically against every existing fixture case
(`/home/user/project` → `home_user_project`, `/a/b/c` → `a_b_c`, `/` →
`""`) plus new Windows-style cases
(`C:/Users/RUNNER~1/AppData/Local/Temp/foo` →
`C_Users_RUNNER~1_AppData_Local_Temp_foo`), with byte-identical results to
the corrected bash implementation below.

**Fix `askfirst_state_dir()`'s `TMPDIR` fallback** (`bindings/r/R/state.R`)
to use `tempdir()` instead of a hardcoded `"/tmp"`:
```r
Sys.getenv("TMPDIR", unset = tempdir())
```

**Apply the equivalent fix to `agent-hooks/askfirst-state-dir.sh`**
(the canonical bash source, spliced into the two Claude Code hook
scripts by `generate-install-hooks.sh`):
```bash
askfirst_state_dir() {
  local cwd="$1"
  local mangled
  mangled=$(printf '%s' "$cwd" | sed 's#\\#/#g; s#^/##; s#/#_#g; s#:##g')
  printf '%s/askfirst/%s' "${TMPDIR:-/tmp}" "$mangled"
}
```
Verified empirically to produce byte-identical output to the R fix above
for every fixture case, including both forward- and backward-slash
Windows-style inputs. The `${TMPDIR:-/tmp}` fallback here is *not* changed
— it runs under Git Bash/WSL/a real POSIX shell in practice, where `/tmp`
genuinely exists, unlike the native-Windows-R case the R-side fallback
fix addresses.

**Apply the equivalent fix to `askfirstMangleTermPath()`**
(`agent-hooks/opencode/askfirst-plugin.js`), porting the same
strip-backslash/strip-leading-slash/replace-slash/strip-colon sequence to
JS regex operations, keeping `askfirstStateDir()`'s own `process.env.TMPDIR
|| "/tmp"` fallback unchanged for the same reason as the bash side.

**Regenerate the spliced Claude Code hook scripts** by re-running
`agent-hooks/generate-install-hooks.sh` after editing the canonical bash
source, and commit every file it touches together (per that script's own
documented convention).

**Extend the shared fixture** `agent-hooks/askfirst-state-dir-fixture.txt`
with Windows-style cases (forward-slash and backslash input forms mapping
to the same expected output), so all three implementations
(`bindings/r/tests/testthat/test-log.R`,
`agent-hooks/opencode/askfirst-plugin.test.js`) are cross-verified against
them automatically, the same way the existing POSIX cases already are.

**Adopt `fs::path()` for path construction elsewhere in `bindings/r/`**,
replacing `file.path()` call sites in:
- `bindings/r/R/log.R` (pending/unresolved-notice/log paths)
- `bindings/r/R/hooks_status.R` (`hooks_dir`/`marker_file` join)
- `bindings/r/data-raw/sync-vendor.R`, `check-vendor-sync.R`,
  `sync-agent-content.R`, `check-agent-content-sync.R`
- `bindings/r/tests/testthat/test-install-agent-hooks.R`,
  `test-capability-gap.R`, `test-scenarios.R`, `test-log.R`,
  `helper-repo-root.R`

Every `fs::path(...)` call whose result is returned from an internal
function (most notably `askfirst_state_dir()`) is wrapped in
`as.character()`, so no `fs_path`-classed value ever escapes into the rest
of the codebase or into test assertions — `fs::path()` is used purely as a
more robust path-joining implementation, not as a new path-value type
flowing through the package. `system.file()` calls are left as-is (`fs`
has no equivalent for package-internal file lookup; that is a distinct
concern from path construction).

**Add `fs` to `DESCRIPTION`'s `Imports`**, following this codebase's
existing convention of fully-qualified `pkg::fn()` calls (as already used
for `cli::`, `rlang::`, `jsonlite::`) rather than `@importFrom` — no
`NAMESPACE` changes needed beyond the `Imports` line, and no CI workflow
changes needed since `r-lib/actions/setup-r-dependencies@v2` already
installs everything listed in `DESCRIPTION`.

**Verify via `rcmdcheck::rcmdcheck()`** locally (Linux) and confirm the
full existing test suite (183 tests as of stage 019) still passes
unchanged, plus new tests for the Windows-style mangling cases. This
confirms the fix is logically sound and hasn't regressed anything
reachable on Linux, but cannot itself reproduce or confirm the
Windows-specific failure, since the bug is inherently platform-specific.

**Final step: wait for a real Windows CI run before considering this
stage resolved.** Local/Linux verification cannot reproduce the actual
failure mode, so it is not sufficient evidence of a fix on its own. Once
the above changes are implemented and committed, stop and wait for the
user to push to GitHub and run CI; treat `windows-latest` passing in
`r-cmd-check.yml`'s matrix as the authoritative confirmation that this
class of failure is resolved, and treat a persisting or new
Windows-specific failure as a sign that a second, independent root cause
remains to be found rather than assuming this fix was sufficient.

## Open Questions

- Whether to keep `askfirst_mangle_path()`'s doc comment's existing
  cross-reference to the bash/JS ports verbatim or expand it to explicitly
  call out the Windows drive-letter handling as a documented, intentional
  part of the contract (currently only implicit in the fixture) — a
  wording decision left to implementation.
