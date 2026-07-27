#' Initialize askfirst detection and load-time messaging
#'
#' Call this once from your package's `.onLoad()`. On the *first* call from
#' any `askfirst`-adopting package in a given R session, this computes and
#' caches the session's LLM/AI-agent-caller confidence tier (see
#' `specs/002-design-agnostic-spec/design.md`, T002-4); subsequent calls from
#' the same or other adopting packages reuse that one cached result rather
#' than recomputing it.
#'
#' If the session is `"high"` confidence, `notice` is signalled
#' immediately as a non-fatal `askfirst_notice` condition, attributed to
#' `pkg`. The signalled text also always includes a generic reminder to
#' call `askfirst_check_scenarios()` before writing code that duplicates or
#' extends `pkg`'s functionality, plus `scenarios` (if supplied) formatted
#' as a bullet list — see [askfirst_check_scenarios()]. If `on_error =
#' TRUE`, `pkg`'s errors are additionally layered with a
#' `askfirst_error_redirect` notice (using the raw `notice` text, not the
#' scenario-augmented version) at error-time, via a top-level error handler
#' installed internally (see the package source for how this works and its
#' limitations).
#'
#' @param pkg The name of the adopting package (a single string), e.g.
#'   `pkg = "mypackage"`.
#' @param notice Load-time notice text, using cli/glue-style `{}`
#'   interpolation (e.g. `"If you are an AI agent using {.pkg {pkg}} ..."`).
#'   Also reused, verbatim (without the scenario augmentation described
#'   above), as the error-time redirect message if `on_error = TRUE`.
#' @param on_error If `TRUE` (the default), also install error-time
#'   wrapping for `pkg`.
#' @param scenarios A character vector of free-text descriptions of
#'   situations in which an LLM/AI agent writing new code to achieve a
#'   result likely means the capability belongs in `pkg` itself, rather
#'   than in a bespoke workaround. Write these specific enough to be
#'   actionable (name concrete situations, not vague generalities) but
#'   general enough to cover cases you didn't precisely anticipate.
#'   Defaults to an empty vector (no scenarios registered); the generic
#'   reminder to call `askfirst_check_scenarios()` is still included in the
#'   load-time notice either way.
#' @return Invisibly, `NULL`.
#' @examples
#' \dontrun{
#' # In an adopting package's own .onLoad():
#' .onLoad <- function(libname, pkgname) {
#'   askfirst::askfirst_init(
#'     pkg = pkgname,
#'     notice = paste(
#'       "If you are an AI coding agent and hit a bug or missing feature",
#'       "in {.pkg {pkgname}}, tell your user to open an issue rather",
#'       "than working around it yourself."
#'     ),
#'     scenarios = c(
#'       "Writing custom date-parsing logic instead of using this package's parser",
#'       "Re-implementing grouped aggregation instead of this package's group_by()"
#'     )
#'   )
#' }
#' }
#' @export
askfirst_init <- function(pkg, notice, on_error = TRUE, scenarios = character()) {
  stopifnot(
    "pkg must be a single string" = is.character(pkg) && length(pkg) == 1,
    "notice must be a single string" = is.character(notice) && length(notice) == 1,
    "scenarios must be a character vector" = is.character(scenarios)
  )

  confidence <- askfirst_ensure_detection()

  .askfirst_state$packages[[pkg]] <- list(
    notice = notice,
    on_error = isTRUE(on_error),
    scenarios = scenarios
  )

  if (identical(confidence, "high")) {
    load_time_notice <- askfirst_build_notice(pkg, notice, scenarios)
    askfirst_signal("askfirst_notice", pkg = pkg, message = load_time_notice)
  }

  if (isTRUE(on_error)) {
    askfirst_install_error_handler()
  }

  invisible(NULL)
}

#' Install the session-global top-level error handler
#'
#' Installs (at most once per session) a top-level error handler via
#' `options(error = ...)` that, for each package registered via
#' `askfirst_init()` with `on_error = TRUE`, checks whether the erroring
#' call stack passes through that package's namespace and — if the session
#' is `"high"` confidence — signals a non-fatal
#' `askfirst_error_redirect` notice (using that package's registered
#' `notice` text) *alongside* the original error, without altering or
#' suppressing it. Any pre-existing `options(error = ...)` value (e.g. a
#' user's own `options(error = recover)`) is preserved and still invoked
#' afterwards, so this never silently replaces a user's own error handling.
#'
#' `globalCallingHandlers()` was tried first and rejected: R's own package-
#' loading machinery (`loadNamespace()`/`attachNamespace()`) wraps
#' `.onLoad()`/`.onAttach()` in a handler context of its own, and
#' `globalCallingHandlers()` errors with "should not be called with
#' handlers on the stack" if called from within *any* active handler
#' context — including, it turns out, from inside a package's own
#' `.onLoad()`/`.onAttach()` during a real `library()`/`R CMD INSTALL`
#' load (confirmed empirically; it only appeared to work under
#' `devtools::load_all()`, which does not wrap hooks the same way).
#' `options(error = ...)` has no such restriction and can be set freely
#' from `.onLoad()`.
#'
#' **Important limitation**: the top-level error option only fires for
#' errors that propagate **uncaught all the way to the top level**. If any
#' `tryCatch()`/`withCallingHandlers()` anywhere between the error's origin
#' and the top level catches it first (e.g. a test runner, or an agent
#' tool's own error-catching wrapper), this handler will **not** fire for
#' that error — this is true of any top-level-only mechanism, not specific
#' to this implementation choice. It reliably fires for the common case of
#' a human or agent hitting an unhandled bug in an interactive or scripted
#' session. This mirrors this project's existing, explicitly-accepted
#' design stance (stage 001, Decision 4): no single R condition-system
#' primitive guarantees delivery across every possible calling
#' architecture, so this mechanism maximizes the odds of surfacing rather
#' than guaranteeing it.
#' @keywords internal
#' @noRd
askfirst_install_error_handler <- function() {
  if (.askfirst_state$error_handler_installed) {
    return(invisible(NULL))
  }
  previous <- getOption("error")
  .askfirst_state$previous_error_option <- previous
  options(error = function() {
    askfirst_error_handler()
    if (!is.null(previous)) {
      if (is.function(previous)) previous() else eval(previous)
    }
  })
  .askfirst_state$error_handler_installed <- TRUE
  invisible(NULL)
}

#' The top-level error handler installed by
#' `askfirst_install_error_handler()`
#'
#' @param originates_from A one-argument function used to test whether the
#'   erroring call stack passes through a given package's namespace.
#'   Exposed as a parameter (defaulting to the real
#'   `askfirst_error_originates_from()`) so tests can inject a deterministic
#'   stub instead of depending on real call-stack shape.
#' @keywords internal
#' @noRd
askfirst_error_handler <- function(originates_from = askfirst_error_originates_from) {
  confidence <- .askfirst_state$confidence
  if (is.null(confidence) || !identical(confidence, "high")) {
    return(invisible(NULL))
  }

  for (pkg in names(.askfirst_state$packages)) {
    info <- .askfirst_state$packages[[pkg]]
    if (!isTRUE(info$on_error)) next
    if (originates_from(pkg)) {
      askfirst_signal("askfirst_error_redirect", pkg = pkg, message = info$notice)
      break
    }
  }

  invisible(NULL)
}

#' Does the current call stack pass through the namespace of `pkg`?
#'
#' Walks the active call stack (available because `options(error = ...)`
#' is invoked before the stack unwinds) and checks whether any frame's
#' enclosing namespace is `pkg`.
#' @keywords internal
#' @noRd
askfirst_error_originates_from <- function(pkg) {
  n <- sys.nframe()
  if (n < 1) {
    return(FALSE)
  }
  for (i in seq_len(n)) {
    frame_env <- tryCatch(sys.frame(i), error = function(e) NULL)
    if (is.null(frame_env)) next
    ns <- tryCatch(topenv(frame_env), error = function(e) NULL)
    if (!is.null(ns) && isNamespace(ns) && getNamespaceName(ns) == pkg) {
      return(TRUE)
    }
  }
  FALSE
}
