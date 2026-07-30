# Repo-structure check: agent-hooks/install-agent-hooks.sh embeds hook content
# generated from agent-hooks/claude/*.sh (see agent-hooks/generate-install-hooks.sh).
# These tests catch the shipped installer silently drifting out of sync with
# its canonical source again. They only make sense inside a full checkout of
# the askfirst repo (agent-hooks/ lives at the repo root, outside any single
# language binding), so they skip gracefully when that structure isn't present
# -- e.g. when tests run against an installed/tarball copy of just the R
# package.
#
# find_repo_root() now lives in helper-repo-root.R (shared with
# test-log.R's fixture-driven mangling test, stage 018).

extract_heredoc_body <- function(lines, marker) {
  start_idx <- which(grepl(sprintf("<<'%s'$", marker), lines))[1]
  stopifnot(!is.na(start_idx))
  rest <- lines[(start_idx + 1):length(lines)]
  end_offset <- which(rest == marker)[1]
  stopifnot(!is.na(end_offset))
  rest[seq_len(end_offset - 1)]
}

test_that("agent-hooks/install-agent-hooks.sh's embedded hooks match agent-hooks/claude/ exactly", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )

  installer_lines <- readLines(as.character(fs::path(repo_root, "agent-hooks", "install-agent-hooks.sh")))

  session_embedded <- extract_heredoc_body(installer_lines, "SESSION_HOOK")
  post_embedded <- extract_heredoc_body(installer_lines, "POST_HOOK")
  user_prompt_embedded <- extract_heredoc_body(installer_lines, "USER_PROMPT_HOOK")

  session_canonical <- readLines(as.character(fs::path(repo_root, "agent-hooks", "claude", "askfirst-session-start.sh")))
  post_canonical <- readLines(as.character(fs::path(repo_root, "agent-hooks", "claude", "askfirst-post-tool-use.sh")))
  user_prompt_canonical <- readLines(as.character(fs::path(repo_root, "agent-hooks", "claude", "askfirst-user-prompt-submit.sh")))

  expect_identical(session_embedded, session_canonical)
  expect_identical(post_embedded, post_canonical)
  expect_identical(user_prompt_embedded, user_prompt_canonical)
})

test_that("agent-hooks/install-agent-hooks.sh's embedded plugin matches agent-hooks/opencode/askfirst-plugin.js exactly", {
  # As of stage 017, agent-hooks/claude/ and agent-hooks/opencode/ are no
  # longer byte-identical shell-script families -- opencode's real
  # mechanism is a JS plugin, spliced from its own independent source (see
  # agent-hooks/generate-install-hooks.sh). This test replaces the old
  # byte-identity check with the equivalent regression coverage for the
  # plugin file.
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )

  installer_lines <- readLines(as.character(fs::path(repo_root, "agent-hooks", "install-agent-hooks.sh")))
  plugin_embedded <- extract_heredoc_body(installer_lines, "PLUGIN_HOOK")
  plugin_canonical <- readLines(as.character(fs::path(repo_root, "agent-hooks", "opencode", "askfirst-plugin.js")))

  expect_identical(plugin_embedded, plugin_canonical)
})

test_that("the installed askfirst-post-tool-use.sh carries the current version marker and the relocated tmp-root paths", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )

  installer_lines <- readLines(as.character(fs::path(repo_root, "agent-hooks", "install-agent-hooks.sh")))
  post_embedded <- extract_heredoc_body(installer_lines, "POST_HOOK")

  expect_match(
    post_embedded,
    sprintf("askfirst-hook-version: %d", askfirst:::askfirst_hooks_manifest()$hook_version),
    all = FALSE
  )
  expect_match(post_embedded, "askfirst_state_dir", all = FALSE)
  expect_match(post_embedded, "unresolved-notice", all = FALSE)
  expect_no_match(post_embedded, "\\.askfirst/pending", fixed = FALSE)
  expect_no_match(post_embedded, "\\.askfirst/log", fixed = FALSE)
})

test_that("the Claude Code PostToolUse matcher includes file-modifying tool calls", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )

  installer_text <- paste(
    readLines(as.character(fs::path(repo_root, "agent-hooks", "install-agent-hooks.sh"))),
    collapse = "\n"
  )

  expect_match(installer_text, "Bash\\|R\\|Rscript\\|Edit\\|Write\\|NotebookEdit")
})

test_that("install-agent-hooks.sh creates .claude/settings.json and registers hooks when absent", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )
  skip_if(!nzchar(Sys.which("jq")), "jq not installed")

  installer <- as.character(fs::path(repo_root, "agent-hooks", "install-agent-hooks.sh"))

  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  result <- system2(
    "bash", c(shQuote(installer), "--tool", "claude"),
    stdout = TRUE, stderr = TRUE
  )

  expect_true(file.exists(".claude/settings.json"))
  expect_false(any(grepl("skip:", result, fixed = TRUE)))
  expect_true(any(grepl("register:.*hooks added", result)))

  config <- jsonlite::fromJSON(".claude/settings.json", simplifyVector = FALSE)
  session_cmds <- vapply(
    config$hooks$SessionStart[[1]]$hooks, function(h) h$command, character(1)
  )
  post_cmds <- unlist(lapply(config$hooks$PostToolUse, function(x) {
    vapply(x$hooks, function(h) h$command, character(1))
  }))
  prompt_cmds <- unlist(lapply(config$hooks$UserPromptSubmit, function(x) {
    vapply(x$hooks, function(h) h$command, character(1))
  }))

  expect_true(any(grepl("askfirst-session-start\\.sh$", session_cmds)))
  expect_true(any(grepl("askfirst-post-tool-use\\.sh$", post_cmds)))
  expect_true(any(grepl("askfirst-user-prompt-submit\\.sh$", prompt_cmds)))
})

test_that("install-agent-hooks.sh still registers hooks correctly when .claude/settings.json already exists", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )
  skip_if(!nzchar(Sys.which("jq")), "jq not installed")

  installer <- as.character(fs::path(repo_root, "agent-hooks", "install-agent-hooks.sh"))

  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  dir.create(".claude", showWarnings = FALSE)
  writeLines('{"unrelatedSetting": true}', ".claude/settings.json")

  result <- system2(
    "bash", c(shQuote(installer), "--tool", "claude"),
    stdout = TRUE, stderr = TRUE
  )

  expect_false(any(grepl("skip:", result, fixed = TRUE)))
  expect_true(any(grepl("register:.*hooks added", result)))

  config <- jsonlite::fromJSON(".claude/settings.json", simplifyVector = FALSE)
  expect_true(isTRUE(config$unrelatedSetting))
  session_cmds <- vapply(
    config$hooks$SessionStart[[1]]$hooks, function(h) h$command, character(1)
  )
  expect_true(any(grepl("askfirst-session-start\\.sh$", session_cmds)))
})

test_that("install-agent-hooks.sh never touches a pre-existing, non-askfirst file at the old generic hook filenames", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ not found)"
  )
  skip_if(!nzchar(Sys.which("jq")), "jq not installed")

  installer <- as.character(fs::path(repo_root, "agent-hooks", "install-agent-hooks.sh"))

  dir <- withr::local_tempdir()
  withr::local_dir(dir)

  # Models another tool (e.g. designlens) already occupying these generic,
  # conventional filenames in a shared .claude/hooks/ directory -- the exact
  # collision this stage's rename is meant to prevent.
  dir.create(".claude/hooks", recursive = TRUE)
  other_tool_session_start <- c("#!/bin/bash", "# some other tool's SessionStart hook", "echo other-tool")
  other_tool_post_tool_use <- c("#!/bin/bash", "# some other tool's PostToolUse hook", "echo other-tool")
  writeLines(other_tool_session_start, ".claude/hooks/session_start.sh")
  writeLines(other_tool_post_tool_use, ".claude/hooks/post_tool_use.sh")

  result <- system2(
    "bash", c(shQuote(installer), "--tool", "claude"),
    stdout = TRUE, stderr = TRUE
  )

  expect_identical(readLines(".claude/hooks/session_start.sh"), other_tool_session_start)
  expect_identical(readLines(".claude/hooks/post_tool_use.sh"), other_tool_post_tool_use)

  expect_true(file.exists(".claude/hooks/askfirst-session-start.sh"))
  expect_true(file.exists(".claude/hooks/askfirst-post-tool-use.sh"))
  expect_true(file.exists(".claude/hooks/askfirst-user-prompt-submit.sh"))
  expect_true(any(grepl("register:.*hooks added", result)))

  config <- jsonlite::fromJSON(".claude/settings.json", simplifyVector = FALSE)
  session_cmds <- vapply(
    config$hooks$SessionStart[[1]]$hooks, function(h) h$command, character(1)
  )
  expect_true(any(grepl("askfirst-session-start\\.sh$", session_cmds)))
})
