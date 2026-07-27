#' Build the load-time notice text
#'
#' Combines the author's own `notice` text with a fixed, generic reminder
#' to call [askfirst_check_scenarios()] before writing a workaround. Scenario
#' details are not included here -- they are shown exactly once, at
#' scenario_check time, via `askfirst_build_scenario_check_message()`, so
#' there is nothing left for an agent to reconcile between the two.
#' @keywords internal
#' @noRd
askfirst_build_notice <- function(pkg, notice) {
  generic <- paste(
    "Writing new code that duplicates, wraps, or extends",
    "{pkg}'s functionality to achieve a result should be preceded by",
    "askfirst::askfirst_check_scenarios(\"{pkg}\") -- the capability",
    "may belong in {pkg} itself."
  )

  paste(c(notice, generic), collapse = "\n\n")
}

#' Build the message text signalled by askfirst_check_scenarios() at
#' high confidence
#' @keywords internal
#' @noRd
askfirst_build_scenario_check_message <- function(scenarios) {
  header <- paste(
    "Before implementing a workaround, the user should be asked whether this",
    "capability should be added to {pkg} itself -- this applies to any",
    "missing or buggy capability, not just situations matching a listed",
    "example below."
  )
  if (length(scenarios) == 0) {
    return(paste(
      header,
      "No specific scenarios have been registered by the maintainer of",
      "{pkg}, but the question still applies generally."
    ))
  }
  bullets <- paste0("- ", scenarios, collapse = "\n")
  paste0(
    header,
    "\n\nSituations where this applies for {pkg}, including but not limited to:\n",
    bullets
  )
}

#' Try to load a package namespace, returning TRUE/FALSE (never errors)
#' @keywords internal
#' @noRd
askfirst_try_load_namespace <- function(pkg) {
  tryCatch(
    requireNamespace(pkg, quietly = TRUE),
    error = function(e) FALSE
  )
}

#' Check whether a task matches a known "capability gap" scenario for a package
#'
#' Call this at any point in a session -- it doesn't need to be tied to any
#' specific error or event -- whenever you notice yourself about to write
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
#' anticipated precisely enough to instrument inline -- at the cost of
#' being a self-check the calling agent has to remember to perform, rather
#' than something the package can force.
#'
#' @param pkg The name of a package that adopts askfirst (a single string).
#'   If the package has not yet called [askfirst_init()] in this session, its
#'   namespace is loaded automatically to trigger the init call from the
#'   package's `.onLoad()`.
#' @return At `"low"`/`"medium"` session confidence (a human caller, or an
#'   agent not yet confidently detected), invisibly returns the character
#'   vector of scenarios registered for `pkg` via [askfirst_init()]'s
#'   `scenarios` argument (possibly empty) -- no condition is signalled, since
#'   a human calling this deliberately doesn't need to be told to ask
#'   themselves. At `"high"` confidence, does not return: halts with an
#'   `askfirst_scenario_check` condition carrying the scenario list and a
#'   reminder to ask the human before implementing a workaround. Unlike the
#'   load-time notice or error-time redirect, halting is the deliberate
#'   intent here -- this is a self-check the calling agent performs before
#'   writing a workaround, so it must actually stop rather than merely
#'   print advice the agent could read past.
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
    askfirst_try_load_namespace(pkg)
    info <- .askfirst_state$packages[[pkg]]
    if (is.null(info)) {
      stop(
        sprintf(
          "'%s' does not appear to adopt askfirst (no askfirst_init() call found after loading its namespace).",
          pkg
        ),
        call. = FALSE
      )
    }
  }
  scenarios <- info$scenarios

  confidence <- askfirst_ensure_detection()
  if (identical(confidence, "high")) {
    message_text <- askfirst_build_scenario_check_message(scenarios)
    askfirst_signal(
      "askfirst_scenario_check",
      pkg = pkg,
      message = message_text,
      scenarios = scenarios,
      call_stop = TRUE
    )
  }

  invisible(scenarios)
}
