#' Compute the session's LLM/AI-agent-caller confidence tier
#'
#' Implements the mapping rules from `specs/002-design-agnostic-spec/design.md`
#' (T002-4): `"high"` on any vendored-data match; `"medium"` on no match but
#' no TTY attached to stdin/stdout (ambiguous non-interactive automation);
#' `"low"` otherwise. The `"cooperative"` tier is part of the enum but has no
#' code path producing it in this version — reserved for a future
#' tool-initiated signal (e.g. a hypothetical `btw` MCP-server marker).
#'
#' @param tool The result of `askfirst_detect_tool()` (a list with `key`/
#'   `name`, or `NULL`).
#' @param no_tty Whether stdin or stdout is not a TTY. Exposed as a
#'   parameter (rather than always computed internally) so tests can
#'   exercise all three tiers deterministically without needing to mock
#'   [isatty()].
#' @return A single string: one of `"high"`, `"medium"`, `"low"`.
#' @keywords internal
#' @noRd
askfirst_detect_confidence <- function(tool = askfirst_detect_tool(),
                                        no_tty = !isatty(stdin()) || !isatty(stdout())) {
  if (!is.null(tool)) {
    return("high")
  }
  if (no_tty) {
    return("medium")
  }
  "low"
}
