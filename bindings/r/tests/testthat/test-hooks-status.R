test_that("askfirst_hooks_status returns not_installed when no hooks directory exists", {
  withr::local_dir(withr::local_tempdir())

  expect_equal(askfirst_hooks_status(), "not_installed")
})

test_that("askfirst_hooks_status returns stale when a hook file has no version marker", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  dir.create(".claude/hooks", recursive = TRUE)
  writeLines(
    c("#!/bin/bash", "# askfirst SessionStart hook, pre-versioning", "echo hi"),
    ".claude/hooks/session_start.sh"
  )

  expect_equal(askfirst_hooks_status(), "stale")
})

test_that("askfirst_hooks_status returns stale when a hook file has an outdated version marker", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  dir.create(".opencode/hooks", recursive = TRUE)
  writeLines(
    c("#!/bin/bash", "# askfirst-hook-version: 0", "echo hi"),
    ".opencode/hooks/session_start.sh"
  )

  expect_equal(askfirst_hooks_status(), "stale")
})

test_that("askfirst_hooks_status returns current when a hook file has a current version marker", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  dir.create(".claude/hooks", recursive = TRUE)
  writeLines(
    c("#!/bin/bash", "# askfirst-hook-version: 2", "echo hi"),
    ".claude/hooks/session_start.sh"
  )

  expect_equal(askfirst_hooks_status(), "current")
})

test_that("askfirst_hooks_status reports current if any one known tool is current, even if another is stale", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  dir.create(".claude/hooks", recursive = TRUE)
  writeLines(c("#!/bin/bash", "# askfirst-hook-version: 2"), ".claude/hooks/session_start.sh")
  dir.create(".opencode/hooks", recursive = TRUE)
  writeLines(c("#!/bin/bash", "no marker here"), ".opencode/hooks/session_start.sh")

  expect_equal(askfirst_hooks_status(), "current")
})
