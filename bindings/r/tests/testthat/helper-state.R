# Resets askfirst's internal session-state environment for the duration of
# a test, so tests don't leak detection/registry state into one another.
# Also sandboxes the working directory to a fresh tempdir, since
# askfirst_signal() now writes real files under askfirst_state_dir()'s
# session-scoped tmp location (log, pending/, unresolved-notice/) as a
# side effect of any stop-and-ask or un-silenced notice signal -- without
# this, tests calling askfirst_init()/askfirst_capability_gap()/etc at high
# confidence would derive that location from the real repo checkout's own
# path. Also removes that tmp-root directory on exit: since it's a path
# under the *real* system tmp root (derived from the tempdir this function
# itself just created for `getwd()`, not nested inside it), it is a real
# filesystem write that would otherwise accumulate stray directories under
# /tmp across repeated test runs.
# Auto-sourced by testthat before running tests (files matching helper-*.R).
local_reset_askfirst_state <- function(env = parent.frame()) {
  withr::local_dir(withr::local_tempdir(.local_envir = env), .local_envir = env)
  withr::defer(
    {
      state_dir <- askfirst:::askfirst_state_dir()
      unlink(state_dir, recursive = TRUE)
      # Also prune the now-empty `${TMPDIR}/askfirst` parent, if nothing
      # else is using it -- R CMD check's "detritus in the temp directory"
      # check scans all of TMPDIR, not just R's own tempdir() subdir, so an
      # empty leftover parent directory is enough to trip a NOTE.
      parent_dir <- dirname(state_dir)
      if (dir.exists(parent_dir) && length(list.files(parent_dir, all.files = TRUE, no.. = TRUE)) == 0) {
        unlink(parent_dir, recursive = TRUE)
      }
    },
    envir = env
  )

  old <- list(
    confidence = .askfirst_state$confidence,
    tool = .askfirst_state$tool,
    packages = .askfirst_state$packages,
    error_handler_installed = .askfirst_state$error_handler_installed,
    previous_error_option = .askfirst_state$previous_error_option,
    hooks_status = .askfirst_state$hooks_status,
    hooks_nudge_shown = .askfirst_state$hooks_nudge_shown
  )
  old_error_option <- getOption("error")

  .askfirst_state$confidence <- NULL
  .askfirst_state$tool <- NULL
  .askfirst_state$packages <- list()
  .askfirst_state$error_handler_installed <- FALSE
  .askfirst_state$previous_error_option <- NULL
  .askfirst_state$hooks_status <- NULL
  .askfirst_state$hooks_nudge_shown <- FALSE

  withr::defer({
    .askfirst_state$confidence <- old$confidence
    .askfirst_state$tool <- old$tool
    .askfirst_state$packages <- old$packages
    .askfirst_state$error_handler_installed <- old$error_handler_installed
    .askfirst_state$previous_error_option <- old$previous_error_option
    .askfirst_state$hooks_status <- old$hooks_status
    .askfirst_state$hooks_nudge_shown <- old$hooks_nudge_shown
    options(error = old_error_option)
  }, envir = env)

  invisible(NULL)
}
