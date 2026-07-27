test_that("confidence is high when a tool is detected", {
  expect_equal(
    askfirst:::askfirst_detect_confidence(tool = list(key = "CLAUDE", name = "claude")),
    "high"
  )
})

test_that("confidence is medium when no tool matches but there's no TTY", {
  expect_equal(
    askfirst:::askfirst_detect_confidence(tool = NULL, no_tty = TRUE),
    "medium"
  )
})

test_that("confidence is low when no tool matches and a TTY is attached", {
  expect_equal(
    askfirst:::askfirst_detect_confidence(tool = NULL, no_tty = FALSE),
    "low"
  )
})

test_that("a tool match takes precedence over TTY state", {
  expect_equal(
    askfirst:::askfirst_detect_confidence(tool = list(key = "CLAUDE"), no_tty = FALSE),
    "high"
  )
})
