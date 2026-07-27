---
created: 2026-07-27T13:59:00Z
agent: claude
git_hash: dc7265dc1a9c4e896580955e332468faa902c1a4
---

# Tasks: auto-init-scenarios

## T009-1: Update `askfirst_check_scenarios()` to auto-load unregistered package namespace

- [ ] T009-1: In `bindings/r/R/scenarios.R`, modify the `askfirst_check_scenarios()` function so that when `.askfirst_state$packages[[pkg]]` is NULL, it attempts to load the package namespace via `requireNamespace(pkg, quietly = TRUE)`, then re-checks the registry. If the package is still not registered after loading, error with a message indicating the package does not appear to adopt askfirst (or is not installed). Wrap the `requireNamespace` call in `tryCatch()` to handle the case where the package is not installed at all.

## T009-2: Update existing test for unregistered packages

- [ ] T009-2: In `bindings/r/tests/testthat/test-scenarios.R`, update the test "askfirst_check_scenarios errors informatively for an unregistered package" to pass with the new behaviour — the error should still fire (the test package is never installed, so `requireNamespace` will fail), but the error message will now come from the new fallback branch rather than the immediate NULL check.

## T009-3: Add test for auto-init scenarios from namespace loading

- [ ] T009-3: In `bindings/r/tests/testthat/test-scenarios.R`, add a new test that simulates an askfirst-adopting package being loaded via namespace load. The test should verify that calling `askfirst_check_scenarios("pkgname")` on an as-yet-unregistered package triggers namespace loading and the scenarios become available.

## T009-4: Run tests to confirm all pass

- [ ] T009-4: Run `devtools::test("bindings/r")` to confirm all existing and new tests pass.
