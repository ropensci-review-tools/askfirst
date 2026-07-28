test_that("askfirst_write_pending() writes and overwrites a per-package/type sentinel", {
  withr::local_dir(withr::local_tempdir())

  askfirst:::askfirst_write_pending("mypkg", "capability_gap", "first message")
  target <- file.path(".askfirst", "pending", "mypkg-capability_gap.txt")
  expect_true(file.exists(target))
  expect_match(readLines(target), "first message", fixed = TRUE, all = FALSE)

  askfirst:::askfirst_write_pending("mypkg", "capability_gap", "second message")
  files <- list.files(file.path(".askfirst", "pending"))
  expect_length(files, 1)
  expect_match(readLines(target), "second message", fixed = TRUE, all = FALSE)
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

  expect_false(file.exists(file.path(".askfirst", "log")))
})

test_that("notice signals are logged when not silenced", {
  local_reset_askfirst_state()
  withr::local_envvar(c(ASKFIRST_SILENCE_NOTICE = ""))

  withCallingHandlers(
    askfirst:::askfirst_signal("askfirst_notice", "mypkg", "raw message"),
    askfirst_notice = function(cnd) invokeRestart("muffleMessage")
  )

  log_file <- file.path(".askfirst", "log")
  expect_true(file.exists(log_file))
  expect_match(readLines(log_file), "raw message", fixed = TRUE, all = FALSE)
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

  pending_file <- file.path(".askfirst", "pending", "mypkg-capability_gap.txt")
  expect_true(file.exists(pending_file))
})
