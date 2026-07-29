---
created: 2026-07-29T11:34:33Z
agent: claude-sonnet-5
git_hash: 0b9799c2ee2da5f14cb0011f286ae36d356e445c
---

# Tasks: fix-windows-path-mangling

## T020-1: Add `fs` to `DESCRIPTION`'s Imports

- [x] T020-1: Add `fs` to the `Imports:` field of `bindings/r/DESCRIPTION`
  (alphabetically among the existing `cli`, `jsonlite`, `rlang` entries).
  No `NAMESPACE` changes needed — this codebase calls dependencies via
  fully-qualified `pkg::fn()`, not `@importFrom`.

## T020-2: Fix `askfirst_mangle_path()` and the `TMPDIR` fallback in `state.R`

- [x] T020-2: In `bindings/r/R/state.R`, replace `askfirst_mangle_path()`'s
  body with the `fs::path_split()`-based implementation:
  ```r
  askfirst_mangle_path <- function(path) {
    parts <- fs::path_split(path)[[1]]
    parts <- parts[parts != "/"]
    parts <- gsub("[:\\\\]", "", parts)
    as.character(paste(parts, collapse = "_"))
  }
  ```
  Update its roxygen `@keywords internal`/`@noRd` doc comment to
  explicitly document that it also strips Windows drive-letter colons and
  backslashes (not just the POSIX leading `/`), resolving this stage's
  open question in favor of making the Windows-handling explicit rather
  than leaving it implicit in the fixture alone. Also change
  `askfirst_state_dir()`'s `Sys.getenv("TMPDIR", unset = "/tmp")` to
  `Sys.getenv("TMPDIR", unset = tempdir())`, and update its own doc
  comment to note the fallback is now portable to native Windows R (where
  `/tmp` does not exist). Replace `askfirst_state_dir()`'s `file.path()`
  call with `as.character(fs::path(...))`, matching this stage's broader
  `fs` migration.

## T020-3: Extend the shared fixture with Windows-style cases

- [x] T020-3: Add new lines to `agent-hooks/askfirst-state-dir-fixture.txt`
  (tab-separated `input\texpected`, matching the existing format) covering
  both a forward-slash and a backslash Windows-style absolute path
  mapping to the same expected mangled output, e.g.:
  ```
  C:/Users/runner/AppData/Local/Temp/foo	C_Users_runner_AppData_Local_Temp_foo
  C:\Users\runner\AppData\Local\Temp\foo	C_Users_runner_AppData_Local_Temp_foo
  ```
  Verify both the R (`bindings/r/tests/testthat/test-log.R`) and JS
  (`agent-hooks/opencode/askfirst-plugin.test.js`) fixture-driven tests
  already iterate this file generically (confirmed during planning), so
  no test-code changes are needed for the fixture-driven test itself —
  only the fixture file changes.

## T020-4: Fix the bash mangling function

- [x] T020-4: In `agent-hooks/askfirst-state-dir.sh`, replace
  `askfirst_state_dir()`'s `mangled=$(...)` line with:
  ```bash
  mangled=$(printf '%s' "$cwd" | sed 's#\\#/#g; s#^/##; s#/#_#g; s#:##g')
  ```
  Leave the `${TMPDIR:-/tmp}` fallback on the following line unchanged
  (verified during planning to be correct for this script's actual
  runtime environment — Git Bash/WSL/POSIX shell — unlike the native
  Windows R case `askfirst_state_dir()`'s R-side fallback addresses).
  Update the function's surrounding comment if it describes the old
  strip-slash-only behavior, to mention the new colon/backslash handling.

## T020-5: Fix the JS mangling function

- [x] T020-5: In `agent-hooks/opencode/askfirst-plugin.js`, update
  `askfirstMangleTermPath()` to replace backslashes with forward slashes,
  strip a leading slash, replace remaining slashes with `_`, and strip
  colons — the same sequence as T020-2/T020-4, ported to JS string/regex
  methods (e.g. `p.replace(/\\/g, "/").replace(/^\//, "").replace(/\//g,
  "_").replace(/:/g, "")`). Leave `askfirstStateDir()`'s
  `process.env.TMPDIR || "/tmp"` fallback unchanged, for the same reason
  as the bash side.

## T020-6: Regenerate the spliced Claude Code hook scripts

- [x] T020-6: Run `bash agent-hooks/generate-install-hooks.sh` after
  completing T020-4 (the bash canonical source it splices from). Confirm
  the diff to `agent-hooks/claude/post_tool_use.sh`,
  `agent-hooks/claude/user_prompt_submit.sh`, and
  `agent-hooks/install-agent-hooks.sh` contains only the expected mangling
  logic change (no unrelated drift), and commit all regenerated files
  together per the script's own documented convention.

## T020-7: Add explicit Windows-style unit tests in `test-log.R`

- [x] T020-7: In `bindings/r/tests/testthat/test-log.R`, add a new,
  separate `test_that()` block (not appended to the existing
  cross-platform `"askfirst_mangle_path() strips a leading slash and
  replaces remaining slashes"` test) with explicit assertions for
  Windows-style input, gated with `testthat::skip_on_os()` to run only on
  Windows:
  ```r
  test_that("askfirst_mangle_path() strips drive-letter colons and backslashes on Windows", {
    testthat::skip_on_os(c("mac", "linux", "solaris"))

    expect_equal(
      askfirst:::askfirst_mangle_path("C:/Users/runner/AppData/Local/Temp/foo"),
      "C_Users_runner_AppData_Local_Temp_foo"
    )
    expect_equal(
      askfirst:::askfirst_mangle_path("C:\\Users\\runner\\AppData\\Local\\Temp\\foo"),
      "C_Users_runner_AppData_Local_Temp_foo"
    )
  })
  ```
  This is in addition to (not a replacement for) the existing
  fixture-driven test, which is not OS-gated and will automatically pick
  up T020-3's new fixture lines on every platform (verified during
  planning that `fs::path_split()` parses Windows-style input correctly
  regardless of host OS) — this new block exists specifically to give the
  real Windows CI run (T020-13) its own direct, explicit assertions in
  addition to that cross-platform fixture coverage.

## T020-8: Migrate `file.path()` to `fs::path()` in `R/log.R` and `R/hooks_status.R`

- [x] T020-8: In `bindings/r/R/log.R`, replace every `file.path(...)` call
  (the `log` file path, `pending_dir`/target, `notice_dir`/target) with
  `as.character(fs::path(...))`. In `bindings/r/R/hooks_status.R`, replace
  `target <- file.path(hooks_dir, marker_file)` the same way. Re-run the
  full test suite after this change to confirm no test that compares
  these functions' return values against a plain-character expected value
  (via `expect_equal()`) regressed due to an escaped `fs_path` class.

## T020-9: Migrate `file.path()` to `fs::path()` in `data-raw/` scripts

- [x] T020-9: In `bindings/r/data-raw/sync-vendor.R`,
  `check-vendor-sync.R`, `sync-agent-content.R`, and
  `check-agent-content-sync.R`, replace every `file.path(...)` call with
  `as.character(fs::path(...))`. Re-run `sync-agent-content.R` and
  `check-agent-content-sync.R` (and equivalently for the vendor pair)
  after the change to confirm they still produce the same
  `bindings/r/inst/` output as before (no path-string regressions).

## T020-10: Migrate `file.path()` to `fs::path()` in test files

- [x] T020-10: In `bindings/r/tests/testthat/test-install-agent-hooks.R`,
  `test-capability-gap.R`, `test-scenarios.R`, `test-log.R`, and
  `helper-repo-root.R`, replace every `file.path(...)` call with
  `as.character(fs::path(...))`, for consistency with the source-code
  migration. Since these calls only build paths to read existing files or
  construct expected comparison values (not returned from any package
  function), this is a pure style migration with no behavioral risk, but
  run the full test suite afterward to confirm.

## T020-11: Regenerate roxygen docs if needed

- [x] T020-11: Run `devtools::document()` in `bindings/r/` after T020-2's
  doc-comment changes, and commit any regenerated `man/*.Rd` files.

## T020-12: Full local verification

- [x] T020-12: Run the full `testthat` suite
  (`testthat::test_dir("tests/testthat")`) and confirm 0 failures/warnings
  (matching or exceeding the 183 passing as of stage 019, plus the new
  Windows-style test cases from T020-3/T020-7). Run
  `rcmdcheck::rcmdcheck()` on `bindings/r/` and confirm 0 errors, 0
  warnings, 0 notes. This confirms the fix is logically sound on Linux but
  cannot itself reproduce the Windows-specific failure — do not treat this
  step alone as sufficient confirmation of the fix.

## T020-13: Commit, then wait for a real Windows CI run

- [x] T020-13: Commit all changes from this stage. Then stop and
  explicitly tell the user to push to GitHub and run CI, and wait for
  their confirmation that the `windows-latest` job in
  `r-cmd-check.yml`'s matrix passes before treating this stage as
  resolved. If the user reports the Windows job still fails (the same way
  or differently), treat that as evidence of a second, independent root
  cause requiring further investigation, not as this fix being wrong.
