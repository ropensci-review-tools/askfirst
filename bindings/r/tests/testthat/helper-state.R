# Resets askfirst's internal session-state environment for the duration of
# a test, so tests don't leak detection/registry state into one another.
# Auto-sourced by testthat before running tests (files matching helper-*.R).
local_reset_askfirst_state <- function(env = parent.frame()) {
  old <- list(
    confidence = .askfirst_state$confidence,
    tool = .askfirst_state$tool,
    packages = .askfirst_state$packages,
    error_handler_installed = .askfirst_state$error_handler_installed,
    previous_error_option = .askfirst_state$previous_error_option
  )
  old_error_option <- getOption("error")

  .askfirst_state$confidence <- NULL
  .askfirst_state$tool <- NULL
  .askfirst_state$packages <- list()
  .askfirst_state$error_handler_installed <- FALSE
  .askfirst_state$previous_error_option <- NULL

  withr::defer({
    .askfirst_state$confidence <- old$confidence
    .askfirst_state$tool <- old$tool
    .askfirst_state$packages <- old$packages
    .askfirst_state$error_handler_installed <- old$error_handler_installed
    .askfirst_state$previous_error_option <- old$previous_error_option
    options(error = old_error_option)
  }, envir = env)

  invisible(NULL)
}
