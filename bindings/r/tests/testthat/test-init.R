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
  expect_no_match(msg, "directive:", fixed = TRUE)
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
  expect_match(msg, "directive: ask-before-proceeding", fixed = TRUE)
  expect_match(msg, "raw message", fixed = TRUE)
  expect_match(msg, "See: https://ropensci.github.io/askfirst/", fixed = TRUE)
})
