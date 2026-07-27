test_that("askfirst_init stores scenarios in the registry", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"

  suppressMessages(askfirst_init(
    "mypkg", "some notice",
    scenarios = c("scenario A", "scenario B")
  ))

  expect_equal(
    .askfirst_state$packages[["mypkg"]]$scenarios,
    c("scenario A", "scenario B")
  )
})

test_that("askfirst_init defaults scenarios to an empty character vector", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"

  suppressMessages(askfirst_init("mypkg", "some notice"))

  expect_equal(.askfirst_state$packages[["mypkg"]]$scenarios, character())
})

test_that("the load-time notice includes the generic instruction but not scenario bullets", {
  local_reset_askfirst_state()
  withr::local_envvar(c(CLAUDECODE = "1"))

  caught <- NULL
  withCallingHandlers(
    askfirst_init(
      "mypkg", "author notice text",
      scenarios = c("writing a custom date parser", "re-implementing grouping logic")
    ),
    askfirst_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "author notice text", fixed = TRUE)
  expect_match(msg, "askfirst_check_scenarios", fixed = TRUE)
  expect_no_match(msg, "writing a custom date parser", fixed = TRUE)
  expect_no_match(msg, "re-implementing grouping logic", fixed = TRUE)
})

test_that("the load-time notice still includes the generic instruction with no scenarios", {
  local_reset_askfirst_state()
  withr::local_envvar(c(CLAUDECODE = "1"))

  caught <- NULL
  withCallingHandlers(
    askfirst_init("mypkg", "author notice text"),
    askfirst_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "author notice text", fixed = TRUE)
  expect_match(msg, "askfirst_check_scenarios", fixed = TRUE)
  expect_no_match(msg, "Situations to watch for")
})

test_that("the load-time notice includes both contribute sentences when both fields are registered", {
  local_reset_askfirst_state()
  withr::local_envvar(c(CLAUDECODE = "1"))

  caught <- NULL
  withCallingHandlers(
    askfirst_init(
      "mypkg", "author notice text",
      contribute_how = "Open a PR against main",
      contribute_url = "https://example.com/mypkg/issues"
    ),
    askfirst_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "The developers of mypkg use the 'askfirst' system", fixed = TRUE)
  expect_match(msg, "invited to contribute a fix: Open a PR against main", fixed = TRUE)
  expect_match(msg, "Contribution guide: https://example.com/mypkg/issues", fixed = TRUE)
  expect_no_match(msg, "You are invited", fixed = TRUE)
})

test_that("the load-time notice includes only the how sentence when only contribute_how is registered", {
  local_reset_askfirst_state()
  withr::local_envvar(c(CLAUDECODE = "1"))

  caught <- NULL
  withCallingHandlers(
    askfirst_init("mypkg", "author notice text", contribute_how = "Open a PR against main"),
    askfirst_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "invited to contribute a fix: Open a PR against main", fixed = TRUE)
  expect_no_match(msg, "Contribution guide:", fixed = TRUE)
})

test_that("the load-time notice includes only the url sentence when only contribute_url is registered", {
  local_reset_askfirst_state()
  withr::local_envvar(c(CLAUDECODE = "1"))

  caught <- NULL
  withCallingHandlers(
    askfirst_init("mypkg", "author notice text", contribute_url = "https://example.com/mypkg/issues"),
    askfirst_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "Contribution guide: https://example.com/mypkg/issues", fixed = TRUE)
  expect_no_match(msg, "invited to contribute a fix", fixed = TRUE)
})

test_that("the load-time notice still names askfirst when neither contribute field is registered", {
  local_reset_askfirst_state()
  withr::local_envvar(c(CLAUDECODE = "1"))

  caught <- NULL
  withCallingHandlers(
    askfirst_init("mypkg", "author notice text"),
    askfirst_notice = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "The developers of mypkg use the 'askfirst' system", fixed = TRUE)
  expect_no_match(msg, "invited to contribute a fix", fixed = TRUE)
  expect_no_match(msg, "Contribution guide:", fixed = TRUE)
})

test_that("askfirst_check_scenarios halts with a askfirst_scenario_check condition under high confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"
  .askfirst_state$packages[["mypkg"]] <- list(
    notice = "n", on_error = FALSE, scenarios = c("scenario A")
  )

  caught <- tryCatch(
    askfirst_check_scenarios("mypkg"),
    askfirst_scenario_check = function(cnd) cnd
  )

  expect_s3_class(caught, "askfirst_scenario_check")
  expect_s3_class(caught, "askfirst_condition")
  expect_s3_class(caught, "error")
  expect_equal(caught$pkg, "mypkg")
  expect_equal(caught$scenarios, "scenario A")
  expect_match(conditionMessage(caught), "scenario A", fixed = TRUE)
  expect_match(conditionMessage(caught), "should be asked", fixed = TRUE)
  expect_match(conditionMessage(caught), "not limited to", fixed = TRUE)
})

test_that("askfirst_check_scenarios message includes both contribute sentences when both fields are registered", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"
  .askfirst_state$packages[["mypkg"]] <- list(
    notice = "n", on_error = FALSE, scenarios = c("scenario A"),
    contribute_how = "Open a PR against main",
    contribute_url = "https://example.com/mypkg/issues"
  )

  caught <- tryCatch(
    askfirst_check_scenarios("mypkg"),
    askfirst_scenario_check = function(cnd) cnd
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "The developers of mypkg use the 'askfirst' system", fixed = TRUE)
  expect_match(msg, "invited to contribute a fix: Open a PR against main", fixed = TRUE)
  expect_match(msg, "Contribution guide: https://example.com/mypkg/issues", fixed = TRUE)
  expect_no_match(msg, "You are invited", fixed = TRUE)
})

test_that("askfirst_check_scenarios message still names askfirst when neither contribute field is registered", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"
  .askfirst_state$packages[["mypkg"]] <- list(
    notice = "n", on_error = FALSE, scenarios = c("scenario A")
  )

  caught <- tryCatch(
    askfirst_check_scenarios("mypkg"),
    askfirst_scenario_check = function(cnd) cnd
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "The developers of mypkg use the 'askfirst' system", fixed = TRUE)
  expect_no_match(msg, "invited to contribute a fix", fixed = TRUE)
  expect_no_match(msg, "Contribution guide:", fixed = TRUE)
})

test_that("askfirst_check_scenarios does not signal at medium confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "medium"
  .askfirst_state$packages[["mypkg"]] <- list(
    notice = "n", on_error = FALSE, scenarios = character()
  )

  fired <- FALSE
  withCallingHandlers(
    askfirst_check_scenarios("mypkg"),
    askfirst_scenario_check = function(cnd) {
      fired <<- TRUE
      invokeRestart("muffleMessage")
    }
  )

  expect_false(fired)
})

test_that("askfirst_check_scenarios returns plain vector with no condition at low confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"
  .askfirst_state$packages[["mypkg"]] <- list(
    notice = "n", on_error = FALSE, scenarios = c("scenario A", "scenario B")
  )

  fired <- FALSE
  result <- withCallingHandlers(
    askfirst_check_scenarios("mypkg"),
    askfirst_scenario_check = function(cnd) {
      fired <<- TRUE
      invokeRestart("muffleMessage")
    }
  )

  expect_false(fired)
  expect_equal(result, c("scenario A", "scenario B"))
})

test_that("askfirst_check_scenarios errors informatively for an unregistered package", {
  local_reset_askfirst_state()

  expect_error(
    askfirst_check_scenarios("neverregistered"),
    "does not appear to adopt askfirst"
  )
})

test_that("askfirst_check_scenarios auto-loads namespace for unregistered package", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"

  local_mocked_bindings(
    askfirst_try_load_namespace = function(pkg) {
      suppressMessages(
        askfirst_init(pkg, "auto-loaded notice", scenarios = c("scenario A"))
      )
      TRUE
    }
  )

  caught <- tryCatch(
    askfirst_check_scenarios("autopkg"),
    askfirst_scenario_check = function(cnd) cnd
  )

  expect_s3_class(caught, "askfirst_scenario_check")
  expect_match(conditionMessage(caught), "scenario A", fixed = TRUE)
  expect_equal(caught$scenarios, "scenario A")
})
