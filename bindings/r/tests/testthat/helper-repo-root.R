# Locates the askfirst monorepo root from within a test run, so tests can
# reach repo-root-level files (agent-hooks/, tools/) that live outside any
# single language binding. Returns NULL when not running inside a full
# repo checkout (e.g. against an installed/tarball copy of just the R
# package), so callers should skip gracefully rather than error.
# Auto-sourced by testthat before running tests (files matching helper-*.R).
find_repo_root <- function(start = getwd(), max_up = 6) {
  dir <- normalizePath(start, mustWork = FALSE)
  for (i in seq_len(max_up)) {
    if (file.exists(as.character(fs::path(dir, "agent-hooks", "install-agent-hooks.sh")))) {
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
