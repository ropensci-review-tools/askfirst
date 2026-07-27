test_that("askfirst_capability_gap is a no-op under low confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "low"

  result <- askfirst_capability_gap("mypkg", "grouped input is not supported yet")
  expect_null(result)
})

test_that("askfirst_capability_gap halts with a askfirst_capability_gap condition under high confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"

  caught <- tryCatch(
    askfirst_capability_gap("mypkg", "grouped input is not supported yet"),
    askfirst_capability_gap = function(cnd) cnd
  )

  expect_s3_class(caught, "askfirst_capability_gap")
  expect_s3_class(caught, "askfirst_condition")
  expect_s3_class(caught, "error")
  expect_equal(caught$pkg, "mypkg")
  expect_match(conditionMessage(caught), "grouped input")
})

test_that("askfirst_capability_gap does not halt under medium confidence", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "medium"

  result <- askfirst_capability_gap("mypkg", "gap message")

  expect_null(result)
})

test_that("askfirst_capability_gap supports cli/glue-style interpolation from the caller's frame", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"

  my_function <- function(x) {
    askfirst_capability_gap("mypkg", "value was {x}")
  }

  caught <- tryCatch(
    my_function("grouped"),
    askfirst_capability_gap = function(cnd) cnd
  )

  expect_match(conditionMessage(caught), "value was grouped")
})
