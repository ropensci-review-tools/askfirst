# Resets pkghooks's internal session-state environment for the duration of
# a test, so tests don't leak detection/registry state into one another.
# Auto-sourced by testthat before running tests (files matching helper-*.R).
local_reset_pkghooks_state <- function(env = parent.frame()) {
  old <- list(
    confidence = .pkghooks_state$confidence,
    tool = .pkghooks_state$tool,
    packages = .pkghooks_state$packages,
    error_handler_installed = .pkghooks_state$error_handler_installed,
    previous_error_option = .pkghooks_state$previous_error_option
  )
  old_error_option <- getOption("error")

  .pkghooks_state$confidence <- NULL
  .pkghooks_state$tool <- NULL
  .pkghooks_state$packages <- list()
  .pkghooks_state$error_handler_installed <- FALSE
  .pkghooks_state$previous_error_option <- NULL

  withr::defer({
    .pkghooks_state$confidence <- old$confidence
    .pkghooks_state$tool <- old$tool
    .pkghooks_state$packages <- old$packages
    .pkghooks_state$error_handler_installed <- old$error_handler_installed
    .pkghooks_state$previous_error_option <- old$previous_error_option
    options(error = old_error_option)
  }, envir = env)

  invisible(NULL)
}
