test_that("pkghooks_init signals a pkghooks_notice under high confidence, attributed to pkg", {
  local_reset_pkghooks_state()
  withr::local_envvar(c(CLAUDECODE = "1"))

  caught <- NULL
  withCallingHandlers(
    pkghooks_init("mypkg", "Tell your user to contact the maintainer, {.pkg mypkg}."),
    pkghooks_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  expect_s3_class(caught, "pkghooks_notice")
  expect_s3_class(caught, "pkghooks_condition")
  expect_equal(caught$pkg, "mypkg")
  expect_match(conditionMessage(caught), "mypkg")
})

test_that("pkghooks_init signals a pkghooks_notice under medium confidence", {
  local_reset_pkghooks_state()
  known_vars <- all_known_signal_env_vars()
  na_list <- stats::setNames(rep(NA, length(known_vars)), known_vars)
  withr::local_envvar(na_list)
  # non-interactive test runner: no TTY -> medium, so no further mocking needed

  caught <- NULL
  withCallingHandlers(
    pkghooks_init("mypkg", "notice text"),
    pkghooks_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  expect_s3_class(caught, "pkghooks_notice")
})

test_that("pkghooks_init does not signal a notice under low confidence", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "low"

  fired <- FALSE
  withCallingHandlers(
    pkghooks_init("mypkg", "notice text"),
    pkghooks_notice = function(cnd) {
      fired <<- TRUE
      invokeRestart("muffleMessage")
    }
  )

  expect_false(fired)
})

test_that("pkghooks_init registers pkg's notice and on_error setting", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "low"

  suppressMessages(pkghooks_init("mypkg", "some notice", on_error = FALSE))

  expect_equal(.pkghooks_state$packages[["mypkg"]]$notice, "some notice")
  expect_false(.pkghooks_state$packages[["mypkg"]]$on_error)
})

test_that("pkghooks_install_error_handler is idempotent", {
  local_reset_pkghooks_state()
  withr::local_options(error = function() NULL)

  pkghooks:::pkghooks_install_error_handler()
  first_option <- getOption("error")
  pkghooks:::pkghooks_install_error_handler()
  second_option <- getOption("error")

  expect_identical(first_option, second_option)
  expect_false(is.null(getOption("error")))
})

test_that("pkghooks_install_error_handler chains to a pre-existing options(error=)", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "low" # so pkghooks_error_handler() itself is a no-op here
  sentinel_called <- FALSE
  withr::local_options(error = function() sentinel_called <<- TRUE)

  pkghooks:::pkghooks_install_error_handler()
  # options(error = <function>) is stored by base R as a call (so eval()-ing
  # it invokes the function), not as a raw function object -- confirmed
  # against base R directly, not specific to pkghooks.
  eval(getOption("error"))

  expect_true(sentinel_called)
})

test_that("pkghooks_error_handler signals pkghooks_error_redirect for a matching, on_error-registered package", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "high"
  .pkghooks_state$packages[["mypkg"]] <- list(notice = "redirect text", on_error = TRUE)

  caught <- NULL
  withCallingHandlers(
    pkghooks:::pkghooks_error_handler(originates_from = function(pkg) identical(pkg, "mypkg")),
    pkghooks_error_redirect = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  expect_s3_class(caught, "pkghooks_error_redirect")
  expect_equal(caught$pkg, "mypkg")
})

test_that("pkghooks_error_handler does not signal for packages with on_error = FALSE", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "high"
  .pkghooks_state$packages[["mypkg"]] <- list(notice = "redirect text", on_error = FALSE)

  fired <- FALSE
  withCallingHandlers(
    pkghooks:::pkghooks_error_handler(originates_from = function(pkg) TRUE),
    pkghooks_error_redirect = function(cnd) {
      fired <<- TRUE
      invokeRestart("muffleMessage")
    }
  )

  expect_false(fired)
})

test_that("pkghooks_error_handler is a no-op under low confidence", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "low"
  .pkghooks_state$packages[["mypkg"]] <- list(notice = "redirect text", on_error = TRUE)

  fired <- FALSE
  withCallingHandlers(
    pkghooks:::pkghooks_error_handler(originates_from = function(pkg) TRUE),
    pkghooks_error_redirect = function(cnd) {
      fired <<- TRUE
      invokeRestart("muffleMessage")
    }
  )

  expect_false(fired)
})
