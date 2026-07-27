#' Flag a capability gap to a potential LLM/AI-agent caller
#'
#' Call this inline, from your own package's code, at the exact point you
#' recognize a known limitation or unimplemented capability has been hit —
#' a case where nothing errors (the call otherwise "succeeds") but does not
#' meet the caller's actual need. See
#' `specs/002-design-agnostic-spec/design.md` (T002-4/T002-5) for why this
#' requires explicit author instrumentation rather than mechanical
#' detection.
#'
#' A no-op for human/low-confidence sessions (per the "no false positives
#' for humans" constraint). For `"high"` confidence sessions,
#' halts execution with a `askfirst_capability_gap` condition attributed to
#' `pkg`, since — unlike the load-time notice or error-time redirect —
#' halting is the deliberate intent here.
#'
#' @param pkg The name of the calling package (a single string). Passed
#'   explicitly, not auto-detected, so the emitted condition is
#'   attributable to a specific package even when several packages have
#'   adopted `askfirst` in the same session.
#' @param message Message text describing the capability gap, using
#'   cli/glue-style `{}` interpolation.
#' @return Invisibly, `NULL`, for human/low-confidence sessions. Does not
#'   return otherwise (halts via `rlang::abort()`).
#' @examples
#' \dontrun{
#' # Inside an adopting package's own function body, at a known-limitation
#' # branch:
#' my_function <- function(x, grouped = FALSE) {
#'   if (grouped) {
#'     askfirst::askfirst_capability_gap(
#'       "mypackage",
#'       "grouped input is not yet supported; falls back to ungrouped behavior"
#'     )
#'   }
#'   # ... rest of the function
#' }
#' }
#' @export
askfirst_capability_gap <- function(pkg, message) {
  stopifnot(
    "pkg must be a single string" = is.character(pkg) && length(pkg) == 1,
    "message must be a single string" = is.character(message) && length(message) == 1
  )

  confidence <- askfirst_ensure_detection()

  if (!identical(confidence, "high")) {
    return(invisible(NULL))
  }

  askfirst_signal(
    "askfirst_capability_gap",
    pkg = pkg,
    message = message,
    call_stop = TRUE,
    .envir = parent.frame()
  )
}
