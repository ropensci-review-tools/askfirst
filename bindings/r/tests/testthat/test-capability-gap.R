test_that("flag_capability_gap is a no-op under low confidence", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "low"

  result <- flag_capability_gap("mypkg", "grouped input is not supported yet")
  expect_null(result)
})

test_that("flag_capability_gap halts with a pkghooks_capability_gap condition under high confidence", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "high"

  caught <- tryCatch(
    flag_capability_gap("mypkg", "grouped input is not supported yet"),
    pkghooks_capability_gap = function(cnd) cnd
  )

  expect_s3_class(caught, "pkghooks_capability_gap")
  expect_s3_class(caught, "pkghooks_condition")
  expect_s3_class(caught, "error")
  expect_equal(caught$pkg, "mypkg")
  expect_match(conditionMessage(caught), "grouped input")
})

test_that("flag_capability_gap halts under medium confidence too", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "medium"

  caught <- tryCatch(
    flag_capability_gap("mypkg", "gap message"),
    pkghooks_capability_gap = function(cnd) cnd
  )

  expect_s3_class(caught, "pkghooks_capability_gap")
})

test_that("flag_capability_gap supports cli/glue-style interpolation from the caller's frame", {
  local_reset_pkghooks_state()
  .pkghooks_state$confidence <- "high"

  my_function <- function(x) {
    flag_capability_gap("mypkg", "value was {x}")
  }

  caught <- tryCatch(
    my_function("grouped"),
    pkghooks_capability_gap = function(cnd) cnd
  )

  expect_match(conditionMessage(caught), "value was grouped")
})
