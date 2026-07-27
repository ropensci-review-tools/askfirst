#' Build the load-time notice text, folding in scenario guidance
#'
#' Combines the author's own `notice` text with a fixed, generic reminder
#' to call [askfirst_check_scenarios()] before writing a workaround, plus
#' `scenarios` (if any) formatted as a bullet list. Always includes the
#' generic reminder, regardless of whether `scenarios` is empty, so the
#' on-demand tool is discoverable even for packages whose author hasn't
#' registered any scenarios yet.
#' @keywords internal
#' @noRd
askfirst_build_notice <- function(pkg, notice, scenarios) {
  generic <- paste(
    "If you notice yourself writing new code that duplicates, wraps, or",
    "extends {pkg}'s functionality to achieve a result, call",
    "askfirst::askfirst_check_scenarios(\"{pkg}\") first, or ask your user",
    "whether this capability belongs in {pkg} itself."
  )

  parts <- c(notice, generic)
  if (length(scenarios) > 0) {
    bullets <- paste0("- ", scenarios, collapse = "\n")
    parts <- c(parts, paste0("Situations to watch for in {pkg}:\n", bullets))
  }
  paste(parts, collapse = "\n\n")
}

#' Build the message text signalled by askfirst_check_scenarios() at
#' high/medium confidence
#' @keywords internal
#' @noRd
askfirst_build_scenario_check_message <- function(scenarios) {
  header <- paste(
    "Before implementing a workaround, ask your user whether this",
    "capability should be added to {pkg} itself."
  )
  if (length(scenarios) == 0) {
    return(paste(
      header,
      "No specific scenarios have been registered by the maintainer of",
      "{pkg}, but the question still applies generally."
    ))
  }
  bullets <- paste0("- ", scenarios, collapse = "\n")
  paste0(header, "\n\nKnown situations where this applies for {pkg}:\n", bullets)
}

#' Check whether a task matches a known "capability gap" scenario for a package
#'
#' Call this at any point in a session — it doesn't need to be tied to any
#' specific error or event — whenever you notice yourself about to write
#' code that duplicates, wraps, or extends a `askfirst`-adopting package's
#' functionality to achieve a result. There is no reliable way for
#' `askfirst` to detect this situation on its own (the code you'd write
#' typically never touches the package at all), so this function exists to
#' be called *by you*, proactively, as a self-check before implementing a
#' workaround.
#'
#' Unlike [askfirst_capability_gap()] (which requires the package author to
#' have already recognized and instrumented a specific known gap),
#' `askfirst_check_scenarios()` works for gaps the author hasn't
#' anticipated precisely enough to instrument inline — at the cost of
#' being a self-check the calling agent has to remember to perform, rather
#' than something the package can force.
#'
#' @param pkg The name of a package that has already called
#'   [askfirst_init()] in this session (a single string).
#' @return Invisibly, the character vector of scenarios registered for
#'   `pkg` via [askfirst_init()]'s `scenarios` argument (possibly empty).
#'   At `"high"`/`"medium"` session confidence, also signals a non-fatal
#'   `askfirst_scenario_check` condition carrying the scenario list and a
#'   reminder to ask the human before implementing a workaround. At
#'   `"low"` confidence (a human caller), no condition is signalled — a
#'   human calling this deliberately doesn't need to be told to ask
#'   themselves.
#' @examples
#' \dontrun{
#' # From within an AI agent's own reasoning, before writing a workaround:
#' askfirst::askfirst_check_scenarios("mypackage")
#'
#' # A package with no registered scenarios still returns an (empty) vector
#' # and still reminds the agent to ask, generically.
#' }
#' @export
askfirst_check_scenarios <- function(pkg) {
  stopifnot("pkg must be a single string" = is.character(pkg) && length(pkg) == 1)

  info <- .askfirst_state$packages[[pkg]]
  if (is.null(info)) {
    stop(
      sprintf("'%s' has not called askfirst_init() in this session.", pkg),
      call. = FALSE
    )
  }
  scenarios <- info$scenarios

  confidence <- askfirst_ensure_detection()
  if (confidence %in% c("high", "medium")) {
    message_text <- askfirst_build_scenario_check_message(scenarios)
    askfirst_signal("askfirst_scenario_check", pkg = pkg, message = message_text)
  }

  invisible(scenarios)
}
