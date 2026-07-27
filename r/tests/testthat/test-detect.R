test_that("pkghooks_detect_tool matches a simple env_set signature", {
  withr::local_envvar(c(CLAUDECODE = "1"))
  result <- pkghooks:::pkghooks_detect_tool()
  expect_equal(result$key, "CLAUDE")
})

test_that("pkghooks_detect_tool matches an env_value signature", {
  withr::local_envvar(c(CURSOR_EXTENSION_HOST_ROLE = "agent-exec"))
  result <- pkghooks:::pkghooks_detect_tool()
  expect_equal(result$key, "CURSOR_CLI")
})

test_that("pkghooks_detect_tool matches an env_matches (regex) signature", {
  withr::local_envvar(c(PATH = "/home/user/.pi/agent/bin:/usr/bin"))
  result <- pkghooks:::pkghooks_detect_tool()
  expect_equal(result$key, "PI")
})

test_that("first-match-wins: COWORK (allOf) is matched ahead of plain CLAUDE", {
  withr::local_envvar(c(CLAUDE_CODE_IS_COWORK = "1", CLAUDECODE = "1"))
  result <- pkghooks:::pkghooks_detect_tool()
  expect_equal(result$key, "COWORK")
})

test_that("plain CLAUDE still matches without the Cowork marker", {
  withr::local_envvar(c(CLAUDE_CODE_IS_COWORK = NA, CLAUDECODE = "1"))
  result <- pkghooks:::pkghooks_detect_tool()
  expect_equal(result$key, "CLAUDE")
})

test_that("pkghooks_detect_tool returns NULL with no known signals present", {
  known_vars <- all_known_signal_env_vars()
  na_list <- stats::setNames(rep(NA, length(known_vars)), known_vars)
  withr::local_envvar(na_list)
  result <- pkghooks:::pkghooks_detect_tool()
  expect_null(result)
})
