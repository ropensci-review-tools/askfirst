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

  session_canonical <- readLines(as.character(fs::path(repo_root, "agent-hooks", "claude", "session_start.sh")))
  post_canonical <- readLines(as.character(fs::path(repo_root, "agent-hooks", "claude", "post_tool_use.sh")))
  user_prompt_canonical <- readLines(as.character(fs::path(repo_root, "agent-hooks", "claude", "user_prompt_submit.sh")))

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

test_that("the installed post_tool_use.sh carries the current version marker and the relocated tmp-root paths", {
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
