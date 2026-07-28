test_that("askfirst_mangle_path() strips a leading slash and replaces remaining slashes", {
  expect_equal(askfirst:::askfirst_mangle_path("/home/user/project"), "home_user_project")
  expect_equal(askfirst:::askfirst_mangle_path("/a/b/c"), "a_b_c")
  expect_equal(askfirst:::askfirst_mangle_path("/"), "")
})

test_that("askfirst_mangle_path() matches the shared behavioral-contract fixture", {
  # Shared with agent-hooks/opencode/askfirst-plugin.test.js's mangling
  # verification -- bash/JS/R can't literally share the mangling
  # function's code, but all three are checked against the same
  # input/output pairs here (stage 018, Design Goal 4).
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )

  fixture_lines <- readLines(file.path(repo_root, "agent-hooks", "askfirst-state-dir-fixture.txt"))
  fixture_lines <- fixture_lines[nzchar(fixture_lines)]

  for (line in fixture_lines) {
    parts <- strsplit(line, "\t", fixed = TRUE)[[1]]
    input <- parts[1]
    expected <- if (length(parts) >= 2) parts[2] else ""
    expect_equal(askfirst:::askfirst_mangle_path(input), expected, info = input)
  }
})

test_that("askfirst_state_dir() derives a tmp path from the current working directory", {
  local_reset_askfirst_state()

  expected <- file.path(
    Sys.getenv("TMPDIR", unset = "/tmp"),
    "askfirst",
    askfirst:::askfirst_mangle_path(getwd())
  )
  expect_equal(askfirst:::askfirst_state_dir(), expected)
})

test_that("askfirst_write_pending() writes and overwrites a per-package/type sentinel", {
  local_reset_askfirst_state()

  askfirst:::askfirst_write_pending("mypkg", "capability_gap", "first message")
  target <- file.path(askfirst:::askfirst_state_dir(), "pending", "mypkg-capability_gap.txt")
  expect_true(file.exists(target))
  expect_match(readLines(target), "first message", fixed = TRUE, all = FALSE)

  askfirst:::askfirst_write_pending("mypkg", "capability_gap", "second message")
  files <- list.files(file.path(askfirst:::askfirst_state_dir(), "pending"))
  expect_length(files, 1)
  expect_match(readLines(target), "second message", fixed = TRUE, all = FALSE)
})

test_that("askfirst_write_unresolved_notice()/askfirst_clear_unresolved_notice() lifecycle", {
  local_reset_askfirst_state()

  target <- file.path(askfirst:::askfirst_state_dir(), "unresolved-notice", "mypkg.txt")
  expect_false(file.exists(target))

  askfirst:::askfirst_write_unresolved_notice("mypkg", "first notice")
  expect_true(file.exists(target))
  expect_match(readLines(target), "first notice", fixed = TRUE, all = FALSE)

  askfirst:::askfirst_write_unresolved_notice("mypkg", "second notice")
  expect_match(readLines(target), "second notice", fixed = TRUE, all = FALSE)

  askfirst:::askfirst_clear_unresolved_notice("mypkg")
  expect_false(file.exists(target))
})

test_that("askfirst_clear_unresolved_notice() is a no-op for a package with no marker", {
  local_reset_askfirst_state()

  expect_no_error(askfirst:::askfirst_clear_unresolved_notice("neverwritten"))
})

test_that("askfirst_silence_notice_active() parses comma-separated values and 'all'", {
  withr::local_envvar(c(ASKFIRST_SILENCE_NOTICE = ""))
  expect_false(askfirst:::askfirst_silence_notice_active("mypkg"))

  withr::local_envvar(c(ASKFIRST_SILENCE_NOTICE = "otherpkg, mypkg"))
  expect_true(askfirst:::askfirst_silence_notice_active("mypkg"))
  expect_false(askfirst:::askfirst_silence_notice_active("thirdpkg"))

  withr::local_envvar(c(ASKFIRST_SILENCE_NOTICE = "all"))
  expect_true(askfirst:::askfirst_silence_notice_active("anypkg"))
})

test_that("notice signals are not logged when ASKFIRST_SILENCE_NOTICE covers pkg", {
  local_reset_askfirst_state()
  withr::local_envvar(c(ASKFIRST_SILENCE_NOTICE = "mypkg"))

  withCallingHandlers(
    askfirst:::askfirst_signal("askfirst_notice", "mypkg", "raw message"),
    askfirst_notice = function(cnd) invokeRestart("muffleMessage")
  )

  expect_false(file.exists(file.path(askfirst:::askfirst_state_dir(), "log")))
  expect_false(file.exists(file.path(askfirst:::askfirst_state_dir(), "unresolved-notice", "mypkg.txt")))
})

test_that("notice signals are logged when not silenced", {
  local_reset_askfirst_state()
  withr::local_envvar(c(ASKFIRST_SILENCE_NOTICE = ""))

  withCallingHandlers(
    askfirst:::askfirst_signal("askfirst_notice", "mypkg", "raw message"),
    askfirst_notice = function(cnd) invokeRestart("muffleMessage")
  )

  log_file <- file.path(askfirst:::askfirst_state_dir(), "log")
  expect_true(file.exists(log_file))
  expect_match(readLines(log_file), "raw message", fixed = TRUE, all = FALSE)
})

test_that("notice signals write an unresolved-notice marker when not silenced", {
  local_reset_askfirst_state()
  withr::local_envvar(c(ASKFIRST_SILENCE_NOTICE = ""))

  withCallingHandlers(
    askfirst:::askfirst_signal("askfirst_notice", "mypkg", "raw message"),
    askfirst_notice = function(cnd) invokeRestart("muffleMessage")
  )

  marker <- file.path(askfirst:::askfirst_state_dir(), "unresolved-notice", "mypkg.txt")
  expect_true(file.exists(marker))
  expect_match(readLines(marker), "raw message", fixed = TRUE, all = FALSE)
})

test_that("stop-and-ask signals write to stdout and a pending sentinel, regardless of ASKFIRST_SILENCE_NOTICE", {
  local_reset_askfirst_state()
  withr::local_envvar(c(ASKFIRST_SILENCE_NOTICE = "all"))

  out <- testthat::capture_output(
    tryCatch(
      askfirst:::askfirst_signal(
        "askfirst_capability_gap", "mypkg", "raw message", call_stop = TRUE
      ),
      askfirst_capability_gap = function(cnd) cnd
    )
  )

  expect_match(out, "raw message", fixed = TRUE)
  expect_match(out, "<<<ASKFIRST:HALT>>>", fixed = TRUE)

  pending_file <- file.path(askfirst:::askfirst_state_dir(), "pending", "mypkg-capability_gap.txt")
  expect_true(file.exists(pending_file))
})

test_that("a stop-and-ask signal clears an existing unresolved-notice marker for the same package", {
  local_reset_askfirst_state()

  askfirst:::askfirst_write_unresolved_notice("mypkg", "earlier notice")
  marker <- file.path(askfirst:::askfirst_state_dir(), "unresolved-notice", "mypkg.txt")
  expect_true(file.exists(marker))

  tryCatch(
    askfirst:::askfirst_signal(
      "askfirst_capability_gap", "mypkg", "raw message", call_stop = TRUE
    ),
    askfirst_capability_gap = function(cnd) cnd
  )

  expect_false(file.exists(marker))
})
