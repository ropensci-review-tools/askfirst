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

test_that("askfirst_capability_gap clears an existing unresolved-notice marker for the same package", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"
  askfirst:::askfirst_write_unresolved_notice("mypkg", "earlier notice")
  marker <- as.character(fs::path(askfirst:::askfirst_state_dir(), "unresolved-notice", "mypkg.txt"))
  expect_true(file.exists(marker))

  tryCatch(
    askfirst_capability_gap("mypkg", "grouped input is not supported yet"),
    askfirst_capability_gap = function(cnd) cnd
  )

  expect_false(file.exists(marker))
})

test_that("askfirst_capability_gap folds in a pending askfirst_hooks_nudge from earlier in the same session", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"
  suppressMessages(askfirst_init("mypkg", "notice text"))

  caught <- tryCatch(
    askfirst_capability_gap("mypkg", "grouped input is not supported yet"),
    askfirst_capability_gap = function(cnd) cnd
  )

  msg <- conditionMessage(caught)
  expect_match(msg, "<<<ASKFIRST:TELL-USER>>>", fixed = TRUE)
  expect_match(msg, "<<<ASKFIRST:END-TELL-USER>>>", fixed = TRUE)
  expect_match(msg, "<<<ASKFIRST:HALT>>>", fixed = TRUE)
  expect_match(msg, "<<<ASKFIRST:RESUME>>>", fixed = TRUE)

  tell_user_pos <- regexpr("<<<ASKFIRST:TELL-USER>>>", msg, fixed = TRUE)
  halt_pos <- regexpr("<<<ASKFIRST:HALT>>>", msg, fixed = TRUE)
  expect_true(tell_user_pos < halt_pos)

  see_positions <- gregexpr("See:", msg, fixed = TRUE)[[1]]
  expect_equal(length(see_positions), 1)
})

test_that("a second askfirst_capability_gap halt in the same session does not repeat the pending nudge", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"
  suppressMessages(askfirst_init("mypkg", "notice text"))

  tryCatch(
    askfirst_capability_gap("mypkg", "first gap"),
    askfirst_capability_gap = function(cnd) cnd
  )
  caught2 <- tryCatch(
    askfirst_capability_gap("mypkg", "second gap"),
    askfirst_capability_gap = function(cnd) cnd
  )

  expect_no_match(conditionMessage(caught2), "<<<ASKFIRST:TELL-USER>>>", fixed = TRUE)
})

test_that("askfirst_capability_gap has no TELL-USER block when no hooks_nudge preceded it this session", {
  local_reset_askfirst_state()
  .askfirst_state$confidence <- "high"

  caught <- tryCatch(
    askfirst_capability_gap("mypkg", "grouped input is not supported yet"),
    askfirst_capability_gap = function(cnd) cnd
  )

  expect_no_match(conditionMessage(caught), "<<<ASKFIRST:TELL-USER>>>", fixed = TRUE)
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
