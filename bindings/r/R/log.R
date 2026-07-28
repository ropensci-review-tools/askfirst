#' Append a rendered notice-directive signal to the one-shot notice log
#'
#' Ephemeral, informational-only record of `directive: notice` signals,
#' relative to `getwd()`. Consumed and cleared passively by the calling
#' agent tool's `PostToolUse` hook (see `agent-hooks/*/post_tool_use.sh`) --
#' unlike [askfirst_write_pending()], nothing about this log is blocking.
#' @keywords internal
#' @noRd
askfirst_log_notice <- function(pkg, formatted) {
  dir.create(".askfirst", recursive = TRUE, showWarnings = FALSE)
  cat(formatted, "\n\n", sep = "", file = file.path(".askfirst", "log"), append = TRUE)
  invisible(NULL)
}

#' Write a persistent, per-package/type pending sentinel for a stop-and-ask signal
#'
#' One file per `{pkg}-{type}` combination under `.askfirst/pending/`,
#' relative to `getwd()` -- the filename doubles as natural de-duplication:
#' a repeat signal of the same type from the same package overwrites its
#' own pending file rather than accumulating duplicates. Unlike
#' [askfirst_log_notice()]'s one-shot log, files written here are *not*
#' cleared by the next tool call -- only a new user turn clears them (see
#' `agent-hooks/*/user_prompt_submit.sh`), and every subsequent tool call
#' until then is meant to be actively blocked by `agent-hooks/*/post_tool_use.sh`
#' while any pending file exists.
#' @keywords internal
#' @noRd
askfirst_write_pending <- function(pkg, type, formatted) {
  pending_dir <- file.path(".askfirst", "pending")
  dir.create(pending_dir, recursive = TRUE, showWarnings = FALSE)
  target <- file.path(pending_dir, sprintf("%s-%s.txt", pkg, type))
  writeLines(formatted, target)
  invisible(NULL)
}

#' Whether `ASKFIRST_SILENCE_NOTICE` suppresses notices for `pkg`
#'
#' Checks the comma-separated `ASKFIRST_SILENCE_NOTICE` environment
#' variable for `pkg` or the literal `"all"`. Applies only to
#' `directive: notice` signals -- `stop-and-ask` signals are never
#' silenceable this way, so this is only ever consulted from the notice
#' branch of [askfirst_signal()].
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
