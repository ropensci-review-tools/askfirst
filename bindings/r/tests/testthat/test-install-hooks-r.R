# Tests for install_hooks.R's exported/internal R functions directly (as
# opposed to test-install-agent-hooks.R, which exercises the underlying
# shell script via system2()). Skips gracefully outside a full repo
# checkout, same as test-install-agent-hooks.R, since system.file()'s
# agent-hooks/ lookup depends on the repo-root symlink into inst/.

test_that("askfirst_detect_agent_tool is no longer part of the public API", {
  expect_false("askfirst_detect_agent_tool" %in% getNamespaceExports("askfirst"))
  # Still present and callable internally:
  expect_true(is.function(askfirst:::askfirst_detect_agent_tool))
})

test_that("askfirst_install_agent_hooks(tool = NULL) errors clearly when nothing is detected and the session is non-interactive", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )

  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  expect_error(
    askfirst::askfirst_install_agent_hooks(),
    "No agent tool detected.*claude.*opencode"
  )
})

test_that("askfirst_install_agent_hooks(tool = NULL) installs for every detected tool and returns named exit statuses", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )
  skip_if(!nzchar(Sys.which("jq")), "jq not installed")

  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  dir.create(".claude", showWarnings = FALSE)
  writeLines("{}", ".claude/settings.json")
  dir.create(".opencode", showWarnings = FALSE)

  statuses <- withr::with_options(
    list(),
    suppressMessages(askfirst::askfirst_install_agent_hooks())
  )

  expect_named(statuses, c("claude", "opencode"), ignore.order = TRUE)
  expect_true(all(statuses == 0))

  expect_true(file.exists(".claude/hooks/askfirst-session-start.sh"))
  expect_true(file.exists(".opencode/plugins/askfirst-plugin.js"))
})

test_that("askfirst_install_agent_hooks(tool = 'claude') still installs for a single explicit tool", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )
  skip_if(!nzchar(Sys.which("jq")), "jq not installed")

  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  status <- askfirst::askfirst_install_agent_hooks("claude")

  expect_named(status, "claude")
  expect_equal(unname(status), 0L)
  expect_true(file.exists(".claude/hooks/askfirst-session-start.sh"))
})
