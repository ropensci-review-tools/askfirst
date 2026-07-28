test_that("askfirst_init signals a askfirst_notice under high confidence, attributed to pkg", {
  local_reset_askfirst_state()
  withr::local_envvar(c(CLAUDECODE = "1"))

  caught <- NULL
  withCallingHandlers(
    askfirst_init("mypkg", "Tell your user to contact the maintainer, {.pkg mypkg}."),
    askfirst_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  expect_s3_class(caught, "askfirst_notice")
  expect_s3_class(caught, "askfirst_condition")
  expect_equal(caught$pkg, "mypkg")
  expect_match(conditionMessage(caught), "mypkg")
})

test_that("askfirst_init does not signal a notice under medium confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "medium"

  fired <- FALSE
  withCallingHandlers(
    askfirst_init("mypkg", "notice text"),
    askfirst_notice = function(cnd) {
      fired <<- TRUE
      invokeRestart("muffleMessage")
    }
  )

  expect_false(fired)
})

test_that("askfirst_init does not signal a notice under low confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"

  fired <- FALSE
  withCallingHandlers(
    askfirst_init("mypkg", "notice text"),
    askfirst_notice = function(cnd) {
      fired <<- TRUE
      invokeRestart("muffleMessage")
    }
  )

  expect_false(fired)
})

test_that("askfirst_init registers pkg's notice and on_error setting", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"

  suppressMessages(askfirst_init("mypkg", "some notice", on_error = FALSE))

  expect_equal(.askfirst_state$packages[["mypkg"]]$notice, "some notice")
  expect_false(.askfirst_state$packages[["mypkg"]]$on_error)
})

test_that("askfirst_init stores contribute_how and contribute_url when supplied", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"

  suppressMessages(askfirst_init(
    "mypkg", "some notice",
    contribute_how = "Open a PR against main",
    contribute_url = "https://example.com/mypkg/issues"
  ))

  expect_equal(.askfirst_state$packages[["mypkg"]]$contribute_how, "Open a PR against main")
  expect_equal(.askfirst_state$packages[["mypkg"]]$contribute_url, "https://example.com/mypkg/issues")
})

test_that("askfirst_init defaults contribute_how and contribute_url to NULL", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"

  suppressMessages(askfirst_init("mypkg", "some notice"))

  expect_null(.askfirst_state$packages[["mypkg"]]$contribute_how)
  expect_null(.askfirst_state$packages[["mypkg"]]$contribute_url)
})

test_that("askfirst_init rejects non-string, non-NULL contribute_how/contribute_url", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"

  expect_error(
    askfirst_init("mypkg", "some notice", contribute_how = 123),
    "contribute_how must be NULL or a single string"
  )
  expect_error(
    askfirst_init("mypkg", "some notice", contribute_url = c("a", "b")),
    "contribute_url must be NULL or a single string"
  )
})

test_that("askfirst_install_error_handler is idempotent", {
  local_reset_askfirst_state()
  withr::local_options(error = function() NULL)

  askfirst:::askfirst_install_error_handler()
  first_option <- getOption("error")
  askfirst:::askfirst_install_error_handler()
  second_option <- getOption("error")

  expect_identical(first_option, second_option)
  expect_false(is.null(getOption("error")))
})

test_that("askfirst_install_error_handler chains to a pre-existing options(error=)", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low" # so askfirst_error_handler() itself is a no-op here
  sentinel_called <- FALSE
  withr::local_options(error = function() sentinel_called <<- TRUE)

  askfirst:::askfirst_install_error_handler()
  # options(error = <function>) is stored by base R as a call (so eval()-ing
  # it invokes the function), not as a raw function object -- confirmed
  # against base R directly, not specific to askfirst.
  eval(getOption("error"))

  expect_true(sentinel_called)
})

test_that("askfirst_error_handler signals askfirst_error_redirect for a matching, on_error-registered package", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"
  .askfirst_state$packages[["mypkg"]] <- list(notice = "redirect text", on_error = TRUE)

  caught <- NULL
  withCallingHandlers(
    askfirst:::askfirst_error_handler(originates_from = function(pkg) identical(pkg, "mypkg")),
    askfirst_error_redirect = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  expect_s3_class(caught, "askfirst_error_redirect")
  expect_equal(caught$pkg, "mypkg")
})

test_that("askfirst_error_handler does not signal for packages with on_error = FALSE", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"
  .askfirst_state$packages[["mypkg"]] <- list(notice = "redirect text", on_error = FALSE)

  fired <- FALSE
  withCallingHandlers(
    askfirst:::askfirst_error_handler(originates_from = function(pkg) TRUE),
    askfirst_error_redirect = function(cnd) {
      fired <<- TRUE
      invokeRestart("muffleMessage")
    }
  )

  expect_false(fired)
})

test_that("askfirst_error_handler is a no-op under low confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"
  .askfirst_state$packages[["mypkg"]] <- list(notice = "redirect text", on_error = TRUE)

  fired <- FALSE
  withCallingHandlers(
    askfirst:::askfirst_error_handler(originates_from = function(pkg) TRUE),
    askfirst_error_redirect = function(cnd) {
      fired <<- TRUE
      invokeRestart("muffleMessage")
    }
  )

  expect_false(fired)
})

test_that("askfirst_signal with prefix = FALSE omits the structured prefix", {
  local_reset_askfirst_state()

  caught <- NULL
  withCallingHandlers(
    askfirst:::askfirst_signal(
      "askfirst_notice", "mypkg", "raw message", prefix = FALSE
    ),
    askfirst_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "raw message", fixed = TRUE)
  expect_no_match(msg, "askfirst::", fixed = TRUE)
  expect_no_match(msg, "See:", fixed = TRUE)
  expect_no_match(msg, "type:", fixed = TRUE)
})

test_that("askfirst_signal with default prefix = TRUE includes the structured prefix", {
  local_reset_askfirst_state()

  caught <- NULL
  withCallingHandlers(
    askfirst:::askfirst_signal(
      "askfirst_notice", "mypkg", "raw message"
    ),
    askfirst_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "askfirst::r::mypkg::notice", fixed = TRUE)
  expect_match(msg, "type: notice", fixed = TRUE)
  expect_match(msg, "raw message", fixed = TRUE)
  expect_match(msg, "See: https://ropensci.github.io/askfirst/", fixed = TRUE)
  expect_match(msg, "hard stop", fixed = TRUE)
  expect_match(msg, "ask the developers of mypkg", fixed = TRUE)
})

test_that("askfirst_signal hard-stop shape includes the delimiter and imperative consequence for stop-and-ask classes", {
  local_reset_askfirst_state()

  caught <- tryCatch(
    askfirst:::askfirst_signal(
      "askfirst_capability_gap", "mypkg", "raw message", call_stop = TRUE
    ),
    askfirst_capability_gap = function(cnd) cnd
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "<<<ASKFIRST:HALT>>>", fixed = TRUE)
  expect_match(msg, "YOU ARE BEING INSTRUCTED TO STOP HERE.", fixed = TRUE)
  expect_match(msg, "ask the developers of mypkg directly", fixed = TRUE)
  expect_match(msg, "<<<ASKFIRST:RESUME>>>", fixed = TRUE)
  expect_match(msg, "askfirst::r::mypkg::stop-and-ask", fixed = TRUE)
  expect_match(msg, "type: capability_gap", fixed = TRUE)
  expect_match(msg, "raw message", fixed = TRUE)
  expect_match(msg, "See: https://ropensci.github.io/askfirst/", fixed = TRUE)
})

test_that("askfirst_signal with prefix = FALSE omits the hard-stop delimiter for stop-and-ask classes", {
  local_reset_askfirst_state()

  caught <- tryCatch(
    askfirst:::askfirst_signal(
      "askfirst_capability_gap", "mypkg", "raw message", call_stop = TRUE, prefix = FALSE
    ),
    askfirst_capability_gap = function(cnd) cnd
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "raw message", fixed = TRUE)
  expect_no_match(msg, "<<<ASKFIRST:HALT>>>", fixed = TRUE)
  expect_no_match(msg, "YOU ARE BEING INSTRUCTED", fixed = TRUE)
  expect_no_match(msg, "askfirst::", fixed = TRUE)
  expect_no_match(msg, "See:", fixed = TRUE)
  expect_no_match(msg, "type:", fixed = TRUE)
})

test_that("askfirst_init prints a one-time hooks-install nudge when hooks are not current, independent of confidence", {
  local_reset_askfirst_state()
  withr::local_dir(withr::local_tempdir())
  .askfirst_state$confidence <- "low"

  expect_message(
    askfirst_init("mypkg", "notice text"),
    "no current agent hooks detected"
  )
})

test_that("askfirst_init does not repeat the hooks-install nudge for a second package in the same session", {
  local_reset_askfirst_state()
  withr::local_dir(withr::local_tempdir())
  .askfirst_state$confidence <- "low"

  expect_message(askfirst_init("mypkg", "notice text"), "no current agent hooks detected")
  expect_no_message(askfirst_init("otherpkg", "notice text"))
})

test_that("askfirst_init does not print the hooks-install nudge when hooks are current", {
  local_reset_askfirst_state()
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  dir.create(".claude/hooks", recursive = TRUE)
  writeLines(c("#!/bin/bash", "# askfirst-hook-version: 4"), ".claude/hooks/session_start.sh")
  .askfirst_state$confidence <- "low"

  expect_no_message(askfirst_init("mypkg", "notice text"))
})
