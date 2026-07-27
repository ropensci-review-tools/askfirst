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
#' structured prefix line (`askfirst::<language>::<pkg>::<type>`) followed
#' by a `directive:` line, and appended with a URL line (`See: <url>`), so AI
#' coding assistants can recognise the output as a legitimate package signal
#' rather than a prompt injection, and can identify the message as carrying
#' an actionable directive without relying on second-person or imperative
#' prose tone. The `directive:` value is `"stop-and-ask"` for every class
#' except `"askfirst_notice"`, which gets `"notice"` — it reflects whether
#' the situation the agent is in requires stopping to ask before proceeding,
#' not merely whether this particular call to `askfirst_signal()` itself
#' halts (see the `"askfirst_error_redirect"` bullet below). Set
#' `prefix = FALSE` to suppress all of this (useful in tests checking
#' condition class/metadata only).
#'
#' Four concrete classes are used elsewhere in this package, all built via
#' this one helper:
#' - `"askfirst_notice"` — non-fatal, load-time (see [askfirst_init()]).
#'   Directive: `"notice"` — nothing has been detected or gone wrong yet.
#' - `"askfirst_error_redirect"` — non-fatal (`call_stop = FALSE`, signalled
#'   via [rlang::inform()]), signalled from a calling handler alongside an
#'   error already propagating from an adopting package's own code
#'   (error-time); does not alter or replace the original error. Directive:
#'   `"stop-and-ask"` — even though `askfirst_signal()`'s own call doesn't
#'   halt, the real error it always accompanies already has, so by the time
#'   the agent sees this the call has, in effect, stopped.
#' - `"askfirst_capability_gap"` — halting (`call_stop = TRUE`), signalled
#'   by [askfirst_capability_gap()] (capability-gap-time). Directive:
#'   `"stop-and-ask"`.
#' - `"askfirst_scenario_check"` — halting (`call_stop = TRUE`), signalled by
#'   `askfirst_check_scenarios()` at high session confidence. Directive:
#'   `"stop-and-ask"`.
#'
#' Every signalled condition also carries the base class
#' `"askfirst_condition"`, so calling code (or an agent's own tooling) can
#' catch any `askfirst` condition generically without enumerating the four
#' concrete classes.
#'
#' @param class The concrete subclass to use (a single string, one of
#'   `"askfirst_notice"`, `"askfirst_error_redirect"`,
#'   `"askfirst_capability_gap"`, `"askfirst_scenario_check"`).
#' @param pkg The name of the adopting package this condition is attributed
#'   to.
#' @param message Message text, using cli/glue-style `{}` interpolation
#'   (evaluated in `.envir`).
#' @param ... Additional named fields attached to the condition object.
#' @param call_stop If `TRUE`, signal via [rlang::abort()] (halting);
#'   otherwise via [rlang::inform()] (non-fatal, catchable/muffleable like
#'   [base::message()]).
#' @param prefix If `TRUE` (the default), prepend `askfirst::<language>::<pkg>::<type>`
#'   and `directive: <stop-and-ask|notice>`, and append `See: <url>`, to the
#'   message. Set to `FALSE` to suppress (e.g. in tests that only check
#'   condition class/metadata).
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

  directive_map <- c(
    askfirst_notice = "notice",
    askfirst_error_redirect = "stop-and-ask",
    askfirst_capability_gap = "stop-and-ask",
    askfirst_scenario_check = "stop-and-ask"
  )

  if (isTRUE(prefix) && !is.null(type)) {
    prefix_line <- sprintf(
      "askfirst::%s::%s::%s",
      askfirst_lang(), pkg, type
    )
    directive_line <- sprintf("directive: %s", directive_map[[class]])
    url_line <- sprintf("See: %s", askfirst_url())
    message <- paste(prefix_line, directive_line, message, url_line, sep = "\n")
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
