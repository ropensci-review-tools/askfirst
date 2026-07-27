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

test_that("the load-time notice includes the generic instruction and scenario bullets", {
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
  expect_match(msg, "writing a custom date parser", fixed = TRUE)
  expect_match(msg, "re-implementing grouping logic", fixed = TRUE)
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

test_that("askfirst_check_scenarios signals askfirst_scenario_check at high confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"
  .askfirst_state$packages[["mypkg"]] <- list(
    notice = "n", on_error = FALSE, scenarios = c("scenario A")
  )

  caught <- NULL
  withCallingHandlers(
    result <- askfirst_check_scenarios("mypkg"),
    askfirst_scenario_check = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  expect_s3_class(caught, "askfirst_scenario_check")
  expect_s3_class(caught, "askfirst_condition")
  expect_equal(caught$pkg, "mypkg")
  expect_match(conditionMessage(caught), "scenario A", fixed = TRUE)
  expect_match(conditionMessage(caught), "should be asked", fixed = TRUE)
  expect_equal(result, "scenario A")
})

test_that("askfirst_check_scenarios signals askfirst_scenario_check at medium confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "medium"
  .askfirst_state$packages[["mypkg"]] <- list(
    notice = "n", on_error = FALSE, scenarios = character()
  )

  caught <- NULL
  withCallingHandlers(
    askfirst_check_scenarios("mypkg"),
    askfirst_scenario_check = function(cnd) {
      caught <<- cnd
      invokeRestart("muffleMessage")
    }
  )

  expect_s3_class(caught, "askfirst_scenario_check")
  expect_match(conditionMessage(caught), "No specific scenarios", fixed = TRUE)
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
    "has not called askfirst_init"
  )
})
