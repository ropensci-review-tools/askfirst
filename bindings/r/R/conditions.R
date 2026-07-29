#' Read a canonical, binding-agnostic template file from `agent-content/`
#'
#' `agent-content/` (repo root) holds the fixed condition/notice text
#' askfirst signals emit, factored out (stage 019) so a future non-R
#' binding can port it verbatim instead of reverse-engineering it from R
#' source. The installed package ships a synced copy under
#' `inst/agent-content/` -- a real copy, not a symlink, kept in sync with
#' the repo-root canonical source via `data-raw/sync-agent-content.R` /
#' `data-raw/check-agent-content-sync.R` -- following the same pattern
#' already used for `agent-detect-spec/vendor/` (see `detect.R`), rather
#' than `agent-hooks/`'s symlink (which escapes the `bindings/r/` subtree
#' and can't survive being packaged into a distributable tarball -- see
#' `askfirst_hooks_manifest()`'s own comment on this).
#' @return The file's contents as a single string (lines joined with `\n`).
#' @keywords internal
#' @noRd
askfirst_read_content <- function(file) {
  path <- system.file("agent-content", file, package = "askfirst")
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

#' Extract a named `--- NAME ---` section's content line from
#' `agent-content/askfirst-markers.txt`
#'
#' Mirrors `agent-hooks/generate-install-hooks.sh`'s
#' `extract_reminder_raw()` bash logic (same `--- LEVELn ---`-style
#' section-marker format used by `askfirst-reminder-messages.txt`), ported
#' to R for `conditions.R`'s own runtime use.
#' @keywords internal
#' @noRd
askfirst_load_marker <- function(name) {
  path <- system.file("agent-content", "askfirst-markers.txt", package = "askfirst")
  lines <- readLines(path, warn = FALSE)
  idx <- which(lines == sprintf("--- %s ---", name))
  lines[[idx + 1]]
}

#' Fixed, non-package-authored text for the hard-stop message shape
#'
#' These strings are deliberately **not** package-authored and **not**
#' glue/cli-interpolated against a caller-supplied environment -- unlike the
#' body `message` passed to `askfirst_signal()`, which is written by the
#' adopting package and may reference that package's own local variables via
#' `{}` syntax resolved in `.envir`. The hard-stop block instead interpolates
#' `pkg` directly via a `{{PKG}}` placeholder substituted with `gsub()`,
#' using the `pkg` argument `askfirst_signal()` itself always receives,
#' rather than `{pkg}` glue syntax -- glue interpolation for
#' `askfirst_capability_gap()` resolves against the *adopting function's own
#' frame* (so package authors can reference their own local variables),
#' which usually has no variable literally named `pkg`, so `{pkg}` there
#' would error rather than resolve. The `{{PKG}}` substitution inside these
#' functions sidesteps that entirely.
#'
#' This keeps the boundary from stage 007/011 intact in spirit -- the
#' package-authored body still cannot inject or override the instructional
#' text around it -- while reopening it for the structural/instructional part
#' itself, per this stage's design decision: the message must be
#' self-sufficient even when no `agent-hooks/` context is loaded to interpret
#' it, so the imperative framing that stage 007 confined to hooks now lives in
#' the message text directly, for `stop-and-ask` signals only.
#'
#' As of stage 019, the literal text/tokens below are no longer R string
#' literals -- they are read at runtime from `agent-content/` (see
#' `askfirst_read_content()`/`askfirst_load_marker()`), so a future non-R
#' binding can consume the exact same canonical source rather than
#' hand-porting these R functions.
#'
#' **On trailing backtraces**: confirmed empirically (Rscript, non-interactive)
#' that an uncaught `rlang::abort()` from a `call_stop = TRUE` signal *does*
#' print a backtrace afterward -- this is rlang's own `rlang_backtrace_on_error`
#' default ("full" when `!interactive()`), not something askfirst adds or
#' controls. It always trails strictly *after* the fully assembled message
#' (i.e. after `askfirst_stop_end_delimiter()` and the `See:` line), never
#' interleaved within the block, so the hard-stop block itself stays intact
#' and un-interrupted regardless of calling context. No suppression is
#' attempted here -- overriding `options(rlang_backtrace_on_error = ...)`
#' globally would affect the calling session's other, unrelated errors too,
#' which is out of scope for a single package's condition signalling.
#' @keywords internal
#' @noRd
askfirst_stop_start_delimiter <- function() {
  askfirst_load_marker("HALT")
}

#' @rdname askfirst_stop_start_delimiter
#' @keywords internal
#' @noRd
askfirst_stop_end_delimiter <- function() {
  askfirst_load_marker("RESUME")
}

#' @rdname askfirst_stop_start_delimiter
#' @keywords internal
#' @noRd
askfirst_stop_consequence <- function(pkg) {
  gsub("{{PKG}}", pkg, askfirst_read_content("askfirst-stop-consequence.txt"), fixed = TRUE)
}

#' @rdname askfirst_stop_start_delimiter
#' @keywords internal
#' @noRd
askfirst_tell_user_start_delimiter <- function() {
  askfirst_load_marker("TELL-USER")
}

#' @rdname askfirst_stop_start_delimiter
#' @keywords internal
#' @noRd
askfirst_tell_user_end_delimiter <- function() {
  askfirst_load_marker("END-TELL-USER")
}

#' @rdname askfirst_stop_start_delimiter
#' @keywords internal
#' @noRd
askfirst_notice_prime <- function(pkg) {
  text <- askfirst_read_content("askfirst-notice-prime.txt")
  text <- gsub("{{PKG}}", pkg, text, fixed = TRUE)
  text <- gsub("{{HALT_MARKER}}", askfirst_stop_start_delimiter(), text, fixed = TRUE)
  gsub("{{RESUME_MARKER}}", askfirst_stop_end_delimiter(), text, fixed = TRUE)
}

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
#' When `prefix = TRUE` (the default), the message is assembled into one of
#' three structural shapes, all gated entirely by `prefix` (i.e. `prefix =
#' FALSE` suppresses all of the apparatus described below, leaving only the
#' raw `message` text -- useful in tests checking condition class/metadata
#' only):
#'
#' - **Hard-stop shape**, used whenever `directive_map[[class]]` is
#'   `"stop-and-ask"` (every class except `"askfirst_notice"` and
#'   `"askfirst_hooks_nudge"`): the message is bounded by
#'   `askfirst_stop_start_delimiter` and `askfirst_stop_end_delimiter`,
#'   with `askfirst_stop_consequence()`'s fixed, first-person-to-agent
#'   imperative text placed immediately after the start delimiter -- before
#'   the structured `askfirst::<language>::<pkg>::stop-and-ask` / `type:`
#'   line pair, the (package-authored) body `message`, and, after the end
#'   delimiter, the `See: <url>` line. This shape is self-sufficient: it does
#'   not depend on `agent-hooks/` context being loaded to read as an
#'   instruction to the agent rather than as content to reason over or an
#'   error to work around. The directive (`stop-and-ask`/`notice`) is folded
#'   into the last segment of the prefix line itself, rather than a separate
#'   `directive:` line, so a prefix-anchored regex catches severity
#'   immediately; the finer-grained signal class (e.g. `capability_gap`)
#'   moves to the `type:` line that follows. If
#'   `.askfirst_state$hooks_nudge_pending_relay` is `TRUE` (i.e. an
#'   `askfirst_hooks_nudge` fired earlier this session and hasn't yet been
#'   folded into a halt), the stashed `.askfirst_state$hooks_nudge_relay_text`
#'   -- a bare `TELL-USER`-bounded block with no `See:` line of its own -- is
#'   prepended before this hard-stop block (stage 021), so a must-relay
#'   nudge and a later halt reach the agent as one message rather than two
#'   separately-styled ones that summarization could independently keep or
#'   drop. The flag is cleared immediately after, so only the first halt
#'   following a fresh nudge absorbs it.
#' - **Notice shape**, used only for `"askfirst_notice"`: keeps the same
#'   `askfirst::<language>::<pkg>::notice` / `type: notice` / body layout,
#'   with `askfirst_notice_prime()`'s short, fixed forward-reference
#'   sentence appended after the body (before the URL) -- priming the agent
#'   for what a later hard-stop block from this package means, without
#'   itself being a hard stop (nothing has gone wrong yet at notice time).
#' - **Tell-user shape** (stage 021), used only for `"askfirst_hooks_nudge"`:
#'   the header/body are bounded by `askfirst_tell_user_start_delimiter()` /
#'   `askfirst_tell_user_end_delimiter()` instead of the plain notice shape's
#'   unbounded layout, since this notice carries an explicit must-relay-to-
#'   human directive ("tell your human user...") rather than merely priming
#'   the agent for a later signal -- the same self-sufficiency argument that
#'   motivated the hard-stop shape applies here, just for a *relay*
#'   consequence instead of an *execution* one. No `askfirst_notice_prime()`
#'   text is appended (that sentence primes for a later hard stop, which
#'   doesn't apply to this class). The undecorated block (no trailing `See:`
#'   line) is also stashed into `.askfirst_state$hooks_nudge_relay_text`,
#'   with `.askfirst_state$hooks_nudge_pending_relay` set `TRUE`, for the
#'   hard-stop shape to potentially fold in later (see above).
#'
#' See `askfirst_stop_start_delimiter` for why the hard-stop shape's fixed
#' text is interpolated via a `{{PKG}}` placeholder substituted directly,
#' rather than via `{pkg}` glue syntax resolved in `.envir`.
#'
#' Five concrete classes are used elsewhere in this package, all built via
#' this one helper:
#' - `"askfirst_notice"` — non-fatal, load-time (see [askfirst_init()]).
#'   Directive: `"notice"` — nothing has been detected or gone wrong yet.
#'   Uses the notice shape.
#' - `"askfirst_error_redirect"` — non-fatal (`call_stop = FALSE`, signalled
#'   via [rlang::inform()]), signalled from a calling handler alongside an
#'   error already propagating from an adopting package's own code
#'   (error-time); does not alter or replace the original error. Directive:
#'   `"stop-and-ask"` — even though `askfirst_signal()`'s own call doesn't
#'   halt, the real error it always accompanies already has, so by the time
#'   the agent sees this the call has, in effect, stopped. Uses the hard-stop
#'   shape.
#' - `"askfirst_capability_gap"` — halting (`call_stop = TRUE`), signalled
#'   by [askfirst_capability_gap()] (capability-gap-time). Directive:
#'   `"stop-and-ask"`. Uses the hard-stop shape.
#' - `"askfirst_scenario_check"` — halting (`call_stop = TRUE`), signalled by
#'   `askfirst_check_scenarios()` at high session confidence. Directive:
#'   `"stop-and-ask"`. Uses the hard-stop shape.
#' - `"askfirst_hooks_nudge"` — non-fatal, load-time (see
#'   `askfirst_maybe_nudge_hooks_install()`, stage 019). Directive:
#'   `"notice"`. Uses the tell-user shape (stage 021), not the plain notice
#'   shape. Unlike the other four classes, it is not attributable to a
#'   specific adopting package's own capability gap or scenario check -- it
#'   reports a project-wide askfirst-agent-hooks installation state
#'   (missing/stale), attributed to whichever `pkg` happened to trigger
#'   `askfirst_init()` first in the session, and only fires under high
#'   AI-agent confidence, alongside (not instead of) an unconditional,
#'   human-directed console nudge printed independently of confidence.
#'
#' Every signalled condition also carries the base class
#' `"askfirst_condition"`, so calling code (or an agent's own tooling) can
#' catch any `askfirst` condition generically without enumerating the five
#' concrete classes.
#'
#' @param class The concrete subclass to use (a single string, one of
#'   `"askfirst_notice"`, `"askfirst_error_redirect"`,
#'   `"askfirst_capability_gap"`, `"askfirst_scenario_check"`,
#'   `"askfirst_hooks_nudge"`).
#' @param pkg The name of the adopting package this condition is attributed
#'   to.
#' @param message Message text, using cli/glue-style `{}` interpolation
#'   (evaluated in `.envir`).
#' @param ... Additional named fields attached to the condition object.
#' @param call_stop If `TRUE`, signal via [rlang::abort()] (halting);
#'   otherwise via [rlang::inform()] (non-fatal, catchable/muffleable like
#'   [base::message()]).
#' @param prefix If `TRUE` (the default), assemble the full hard-stop or
#'   notice shape described above around `message`. Set to `FALSE` to
#'   suppress (e.g. in tests that only check condition class/metadata).
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
    askfirst_scenario_check = "scenario_check",
    askfirst_hooks_nudge = "hooks_nudge"
  )
  type <- type_map[[class]]

  directive_map <- c(
    askfirst_notice = "notice",
    askfirst_error_redirect = "stop-and-ask",
    askfirst_capability_gap = "stop-and-ask",
    askfirst_scenario_check = "stop-and-ask",
    askfirst_hooks_nudge = "notice"
  )

  if (isTRUE(prefix) && !is.null(type)) {
    prefix_line <- sprintf(
      "askfirst::%s::%s::%s",
      askfirst_lang(), pkg, directive_map[[class]]
    )
    type_line <- sprintf("type: %s", type)
    url_line <- sprintf("See: %s", askfirst_url())
    header <- paste(prefix_line, type_line, sep = "\n")

    if (identical(class, "askfirst_hooks_nudge")) {
      tell_user_block <- paste(
        askfirst_tell_user_start_delimiter(),
        header,
        message,
        askfirst_tell_user_end_delimiter(),
        sep = "\n\n"
      )
      .askfirst_state$hooks_nudge_relay_text <- tell_user_block
      .askfirst_state$hooks_nudge_pending_relay <- TRUE
      message <- paste(tell_user_block, url_line, sep = "\n\n")
    } else if (identical(directive_map[[class]], "stop-and-ask")) {
      message <- paste(
        askfirst_stop_start_delimiter(),
        askfirst_stop_consequence(pkg),
        header,
        message,
        askfirst_stop_end_delimiter(),
        url_line,
        sep = "\n\n"
      )
      if (isTRUE(.askfirst_state$hooks_nudge_pending_relay)) {
        message <- paste(.askfirst_state$hooks_nudge_relay_text, message, sep = "\n\n")
        .askfirst_state$hooks_nudge_pending_relay <- FALSE
      }
    } else {
      message <- paste(
        header,
        message,
        askfirst_notice_prime(pkg),
        url_line,
        sep = "\n\n"
      )
    }
  }

  formatted <- cli::format_inline(message, .envir = .envir)
  full_class <- c(class, "askfirst_condition")

  if (isTRUE(prefix)) {
    if (identical(directive_map[[class]], "stop-and-ask")) {
      cat(formatted, "\n\n", sep = "", file = stdout())
      askfirst_write_pending(pkg, type, formatted)
      askfirst_clear_unresolved_notice(pkg)
    } else if (!askfirst_silence_notice_active(pkg)) {
      askfirst_log_notice(pkg, formatted)
      askfirst_write_unresolved_notice(pkg, formatted)
    }
  }

  if (call_stop) {
    rlang::abort(formatted, class = full_class, pkg = pkg, ...)
  } else {
    rlang::inform(formatted, class = full_class, pkg = pkg, ...)
    invisible(NULL)
  }
}
