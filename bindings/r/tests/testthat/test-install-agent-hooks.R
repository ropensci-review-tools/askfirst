# Repo-structure check: tools/install-agent-hooks.sh embeds hook content
# generated from agent-hooks/claude/*.sh (see tools/generate-install-hooks.sh).
# These tests catch the shipped installer silently drifting out of sync with
# its canonical source again. They only make sense inside a full checkout of
# the askfirst repo (agent-hooks/ and tools/ live at the repo root, outside
# any single language binding), so they skip gracefully when that structure
# isn't present -- e.g. when tests run against an installed/tarball copy of
# just the R package.

find_repo_root <- function(start = getwd(), max_up = 6) {
  dir <- normalizePath(start, mustWork = FALSE)
  for (i in seq_len(max_up)) {
    if (dir.exists(file.path(dir, "agent-hooks", "claude")) &&
      file.exists(file.path(dir, "tools", "install-agent-hooks.sh"))) {
      return(dir)
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      return(NULL)
    }
    dir <- parent
  }
  NULL
}

extract_heredoc_body <- function(lines, marker) {
  start_idx <- which(grepl(sprintf("<<'%s'$", marker), lines))[1]
  stopifnot(!is.na(start_idx))
  rest <- lines[(start_idx + 1):length(lines)]
  end_offset <- which(rest == marker)[1]
  stopifnot(!is.na(end_offset))
  rest[seq_len(end_offset - 1)]
}

test_that("tools/install-agent-hooks.sh's embedded hooks match agent-hooks/claude/ exactly", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ or tools/ not found)"
  )

  installer_lines <- readLines(file.path(repo_root, "tools", "install-agent-hooks.sh"))

  session_embedded <- extract_heredoc_body(installer_lines, "SESSION_HOOK")
  post_embedded <- extract_heredoc_body(installer_lines, "POST_HOOK")

  session_canonical <- readLines(file.path(repo_root, "agent-hooks", "claude", "session_start.sh"))
  post_canonical <- readLines(file.path(repo_root, "agent-hooks", "claude", "post_tool_use.sh"))

  expect_identical(session_embedded, session_canonical)
  expect_identical(post_embedded, post_canonical)
})

test_that("agent-hooks/claude/ and agent-hooks/opencode/ stay byte-identical", {
  repo_root <- find_repo_root()
  skip_if(
    is.null(repo_root),
    "not running inside a full askfirst repo checkout (agent-hooks/ or tools/ not found)"
  )

  expect_identical(
    readLines(file.path(repo_root, "agent-hooks", "claude", "session_start.sh")),
    readLines(file.path(repo_root, "agent-hooks", "opencode", "session_start.sh"))
  )
  expect_identical(
    readLines(file.path(repo_root, "agent-hooks", "claude", "post_tool_use.sh")),
    readLines(file.path(repo_root, "agent-hooks", "opencode", "post_tool_use.sh"))
  )
})
