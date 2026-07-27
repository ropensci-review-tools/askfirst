#' Session-level pkghooks state
#'
#' A package-private environment holding the one, global, session-cached
#' detection/confidence result (computed at most once, on the first call to
#' [pkghooks_init()] from *any* adopting package), plus a per-package
#' registry of each adopting package's `notice` text and `on_error` setting.
#' @keywords internal
#' @noRd
.pkghooks_state <- new.env(parent = emptyenv())
.pkghooks_state$confidence <- NULL
.pkghooks_state$tool <- NULL
.pkghooks_state$packages <- list()
.pkghooks_state$error_handler_installed <- FALSE
.pkghooks_state$previous_error_option <- NULL

#' Compute (once) and return the session's confidence tier
#' @keywords internal
#' @noRd
pkghooks_ensure_detection <- function() {
  if (is.null(.pkghooks_state$confidence)) {
    tool <- pkghooks_detect_tool()
    .pkghooks_state$tool <- tool
    .pkghooks_state$confidence <- pkghooks_detect_confidence(tool)
  }
  .pkghooks_state$confidence
}
