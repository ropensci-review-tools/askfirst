#' Session-level askfirst state
#'
#' A package-private environment holding the one, global, session-cached
#' detection/confidence result (computed at most once, on the first call to
#' [askfirst_init()] from *any* adopting package), plus a per-package
#' registry of each adopting package's `notice` text and `on_error` setting.
#' @keywords internal
#' @noRd
.askfirst_state <- new.env(parent = emptyenv())
.askfirst_state$confidence <- NULL
.askfirst_state$tool <- NULL
.askfirst_state$packages <- list()
.askfirst_state$error_handler_installed <- FALSE
.askfirst_state$previous_error_option <- NULL

#' Compute (once) and return the session's confidence tier
#' @keywords internal
#' @noRd
askfirst_ensure_detection <- function() {
  if (is.null(.askfirst_state$confidence)) {
    tool <- askfirst_detect_tool()
    .askfirst_state$tool <- tool
    .askfirst_state$confidence <- askfirst_detect_confidence(tool)
  }
  .askfirst_state$confidence
}
