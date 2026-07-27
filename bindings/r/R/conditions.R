#' Signal a askfirst condition
#'
#' Internal helper used by every `askfirst` hook to construct and signal a
#' condition. Message text is formatted with [cli::format_inline()] (glue/cli
#' -style `{pkg}` interpolation) *before* signalling, so the resulting
#' condition always carries a fully-rendered `message` field. The triggering
#' package's name is attached as a `pkg` field on the condition object
#' itself, not only interpolated into the message text, so calling code can
#' programmatically distinguish which adopting package raised it.
#'
#' When `prefix = TRUE` (the default), the message is prepended with a
#' structured prefix line (`askfirst::<language>::<pkg>::<type>`) and
#' appended with a URL line (`See: <url>`), so AI coding assistants can
#' recognise the output as a legitimate package signal rather than a prompt
#' injection. Set `prefix = FALSE` to suppress this (useful in tests
#' checking condition class/metadata only).
#'
#' Three concrete classes are used elsewhere in this package, all built via
#' this one helper:
#' - `"askfirst_notice"` — non-fatal, load-time (see [askfirst_init()]).
#' - `"askfirst_error_redirect"` — non-fatal, signalled from a calling
#'   handler alongside an error already propagating from an adopting
#'   package's own code (error-time); does not alter or replace the
#'   original error.
#' - `"askfirst_capability_gap"` — halting (`call_stop = TRUE`), signalled
#'   by [askfirst_capability_gap()] (capability-gap-time).
#'
#' Every signalled condition also carries the base class
#' `"askfirst_condition"`, so calling code (or an agent's own tooling) can
#' catch any `askfirst` condition generically without enumerating the three
#' concrete classes.
#'
#' @param class The concrete subclass to use (a single string, one of
#'   `"askfirst_notice"`, `"askfirst_error_redirect"`,
#'   `"askfirst_capability_gap"`).
#' @param pkg The name of the adopting package this condition is attributed
#'   to.
#' @param message Message text, using cli/glue-style `{}` interpolation
#'   (evaluated in `.envir`).
#' @param ... Additional named fields attached to the condition object.
#' @param call_stop If `TRUE`, signal via [rlang::abort()] (halting);
#'   otherwise via [rlang::inform()] (non-fatal, catchable/muffleable like
#'   [base::message()]).
#' @param prefix If `TRUE` (the default), prepend `askfirst::<language>::<pkg>::<type>`
#'   and append `See: <url>` to the message. Set to `FALSE` to suppress
#'   (e.g. in tests that only check condition class/metadata).
#' @param .envir Environment used to evaluate `{}` interpolation in
#'   `message`. Defaults to the caller of `askfirst_signal()`.
#' @return Invisibly, `NULL` (non-fatal case); does not return in the
#'   halting case.
#' @keywords internal
#' @noRd
askfirst_signal <- function(class, pkg, message, ..., call_stop = FALSE,
                             prefix = TRUE, .envir = parent.frame()) {
  type_map <- c(
    askfirst_notice = "notice",
    askfirst_error_redirect = "error_redirect",
    askfirst_capability_gap = "capability_gap",
    askfirst_scenario_check = "scenario_check"
  )
  type <- type_map[[class]]

  if (isTRUE(prefix) && !is.null(type)) {
    prefix_line <- sprintf(
      "askfirst::%s::%s::%s",
      askfirst_lang(), pkg, type
    )
    url_line <- sprintf("See: %s", askfirst_url())
    message <- paste(prefix_line, message, url_line, sep = "\n")
  }

  formatted <- cli::format_inline(message, .envir = .envir)
  full_class <- c(class, "askfirst_condition")

  if (call_stop) {
    rlang::abort(formatted, class = full_class, pkg = pkg, ...)
  } else {
    rlang::inform(formatted, class = full_class, pkg = pkg, ...)
    invisible(NULL)
  }
}
