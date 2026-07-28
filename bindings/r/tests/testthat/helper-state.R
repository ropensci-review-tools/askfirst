# Resets askfirst's internal session-state environment for the duration of
# a test, so tests don't leak detection/registry state into one another.
# Also sandboxes the working directory to a fresh tempdir, since
# askfirst_signal() now writes real files under .askfirst/ (log, pending/)
# as a side effect of any stop-and-ask or un-silenced notice signal --
# without this, tests calling askfirst_init()/askfirst_capability_gap()/etc
# at high confidence would write those files into the real repo checkout.
# Auto-sourced by testthat before running tests (files matching helper-*.R).
local_reset_askfirst_state <- function(env = parent.frame()) {
  withr::local_dir(withr::local_tempdir(.local_envir = env), .local_envir = env)

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
