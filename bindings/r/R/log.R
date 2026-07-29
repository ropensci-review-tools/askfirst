#' Append a rendered notice-directive signal to the one-shot notice log
#'
#' Ephemeral, informational-only record of `directive: notice` signals,
#' under `askfirst_state_dir()` (a session-scoped tmp location, not the
#' project's working tree -- see that function's docs). Consumed and
#' cleared passively by the calling agent tool's `PostToolUse` hook (see
#' `agent-hooks/*/post_tool_use.sh`) -- unlike `askfirst_write_pending()`,
#' nothing about this log is blocking.
#' @keywords internal
#' @noRd
askfirst_log_notice <- function(pkg, formatted) {
  state_dir <- askfirst_state_dir()
  dir.create(state_dir, recursive = TRUE, showWarnings = FALSE)
  cat(formatted, "\n\n", sep = "", file = as.character(fs::path(state_dir, "log")), append = TRUE)
  invisible(NULL)
}

#' Write a persistent, per-package/type pending sentinel for a stop-and-ask signal
#'
#' One file per `{pkg}-{type}` combination under `pending/`, under
#' `askfirst_state_dir()` (a session-scoped tmp location, not the
#' project's working tree -- see that function's docs) -- the filename
#' doubles as natural de-duplication: a repeat signal of the same type
#' from the same package overwrites its own pending file rather than
#' accumulating duplicates. Unlike `askfirst_log_notice()`'s one-shot log,
#' files written here are *not* cleared by the next tool call -- only a
#' new user turn clears them (see `agent-hooks/*/user_prompt_submit.sh`),
#' and every subsequent tool call until then is meant to be actively
#' blocked by `agent-hooks/*/post_tool_use.sh` while any pending file
#' exists.
#' @keywords internal
#' @noRd
askfirst_write_pending <- function(pkg, type, formatted) {
  pending_dir <- as.character(fs::path(askfirst_state_dir(), "pending"))
  dir.create(pending_dir, recursive = TRUE, showWarnings = FALSE)
  target <- as.character(fs::path(pending_dir, sprintf("%s-%s.txt", pkg, type)))
  writeLines(formatted, target)
  invisible(NULL)
}

#' Write/refresh the "unresolved notice" marker for `pkg`
#'
#' A third state category, distinct from both `askfirst_log_notice()`'s
#' one-shot log (cleared by the very next tool call) and
#' `askfirst_write_pending()`'s blocking sentinel (cleared only by a new
#' user turn): this marker persists across multiple tool calls *and* turns,
#' cleared only by an explicit resolution --
#' `askfirst_clear_unresolved_notice()`, called either from
#' `askfirst_check_scenarios()` (any confidence tier) or from the
#' stop-and-ask branch of `askfirst_signal()`. Written whenever a `notice`
#' fires for `pkg` (idempotent -- overwriting an already-open marker is a
#' no-op in effect), so `agent-hooks/*/post_tool_use.sh` can detect, on any
#' subsequent file-modifying tool call, that a notice for `pkg` was never
#' followed up with a scenario check.
#' @keywords internal
#' @noRd
askfirst_write_unresolved_notice <- function(pkg, formatted) {
  notice_dir <- as.character(fs::path(askfirst_state_dir(), "unresolved-notice"))
  dir.create(notice_dir, recursive = TRUE, showWarnings = FALSE)
  target <- as.character(fs::path(notice_dir, paste0(pkg, ".txt")))
  writeLines(formatted, target)
  invisible(NULL)
}

#' Clear the "unresolved notice" marker for `pkg`, if any
#'
#' A no-op (not an error) if no marker exists for `pkg`. See
#' `askfirst_write_unresolved_notice()` for what this clears and why.
#' @keywords internal
#' @noRd
askfirst_clear_unresolved_notice <- function(pkg) {
  target <- as.character(fs::path(askfirst_state_dir(), "unresolved-notice", paste0(pkg, ".txt")))
  if (file.exists(target)) {
    unlink(target)
  }
  invisible(NULL)
}

#' Whether `ASKFIRST_SILENCE_NOTICE` suppresses notices for `pkg`
#'
#' Checks the comma-separated `ASKFIRST_SILENCE_NOTICE` environment
#' variable for `pkg` or the literal `"all"`. Applies only to
#' `directive: notice` signals -- `stop-and-ask` signals are never
#' silenceable this way, so this is only ever consulted from the notice
#' branch of `askfirst_signal()`.
#' @keywords internal
#' @noRd
askfirst_silence_notice_active <- function(pkg) {
  raw <- Sys.getenv("ASKFIRST_SILENCE_NOTICE", unset = "")
  if (identical(raw, "")) {
    return(FALSE)
  }
  silenced <- trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
  pkg %in% silenced || "all" %in% silenced
}
