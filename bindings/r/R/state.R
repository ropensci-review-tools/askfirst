#' Session-level askfirst state
#'
#' A package-private environment holding the one, global, session-cached
#' detection/confidence result (computed at most once, on the first call to
#' [askfirst_init()] from *any* adopting package), plus a per-package
#' registry of each adopting package's `notice` text and `on_error` setting.
#' @keywords internal
#' @noRd
.askfirst_state <- new.env(parent = emptyenv())
.askfirst_state$confidence <- NULL
.askfirst_state$tool <- NULL
.askfirst_state$packages <- list()
.askfirst_state$error_handler_installed <- FALSE
.askfirst_state$previous_error_option <- NULL
.askfirst_state$hooks_status <- NULL
.askfirst_state$hooks_nudge_shown <- FALSE
.askfirst_state$hooks_nudge_pending_relay <- FALSE
.askfirst_state$hooks_nudge_relay_text <- NULL

#' Compute (once) and return the session's confidence tier
#' @keywords internal
#' @noRd
askfirst_ensure_detection <- function() {
  if (is.null(.askfirst_state$confidence)) {
    tool <- askfirst_detect_tool()
    .askfirst_state$tool <- tool
    .askfirst_state$confidence <- askfirst_detect_confidence(tool)
  }
  .askfirst_state$confidence
}

#' Compute (once) and return the session's hooks-installation status
#' @keywords internal
#' @noRd
askfirst_ensure_hooks_status <- function() {
  if (is.null(.askfirst_state$hooks_status)) {
    .askfirst_state$hooks_status <- askfirst_hooks_status()
  }
  .askfirst_state$hooks_status
}

#' Mangle an absolute path into a directory-name-safe string
#'
#' Strips a leading `/` (the POSIX root marker) and replaces every
#' remaining `/` with `_`. As of stage 020, also strips Windows
#' drive-letter colons and normalizes backslashes to `/` first, so a
#' Windows-style absolute path (e.g. `C:/Users/...` or `C:\Users\...`)
#' mangles to a filesystem-safe directory-name segment instead of leaving
#' a literal `:` embedded in it (illegal in a Windows path component
#' outside the drive prefix, and the direct cause of the
#' `writeLines()`/`file()` "Invalid argument" failures this stage fixes).
#' Uses `fs::path_split()` to decompose the path into components --
#' correctly recognising both the POSIX `/` root marker and a Windows
#' drive-letter component regardless of the *host* OS actually running
#' this code, which is what let this fix be verified and tested on Linux
#' rather than only on an actual Windows machine.
#'
#' Used to derive a stable, deterministic directory name from a project's
#' working directory, shared independently (with no other coordination)
#' between this R package and the separate `agent-hooks/*/post_tool_use.sh`
#' / `user_prompt_submit.sh` processes (and `agent-hooks/opencode/`'s JS
#' plugin), which implement the identical transformation against the `cwd`
#' field of their own hook payload -- verified byte-identical against a
#' shared fixture, `agent-hooks/askfirst-state-dir-fixture.txt`. Deliberately
#' not a hash: the maintainer's explicit choice was a literal,
#' human-debuggable mangling (a maintainer can `ls` their way to the right
#' directory from the project path alone) over hiding the path from other
#' users on a shared multi-user `/tmp`. Deliberately does not call
#' `normalizePath()` or otherwise resolve symlinks -- the bash/JS sides
#' have no equivalent resolution step available to them, and asymmetric
#' normalization would make the sides silently diverge for any project
#' path involving a symlink.
#' @keywords internal
#' @noRd
askfirst_mangle_path <- function(path) {
  parts <- fs::path_split(path)[[1]]
  parts <- parts[parts != "/"]
  parts <- gsub("[:\\\\]", "", parts)
  as.character(paste(parts, collapse = "_"))
}

#' Root directory for this session's askfirst runtime state
#'
#' All askfirst runtime state (`log`, `pending/`, `unresolved-notice/`) is
#' session-scoped and has no meaning beyond the current coding-agent
#' session, so none of it is written under the project's own working tree
#' (which would risk it appearing in `git status` or being committed).
#' Instead it lives under `${TMPDIR:-<fallback>}/askfirst/<mangled cwd>/`, a
#' path computed independently and identically by this function and by each
#' hook script in `agent-hooks/*/post_tool_use.sh` /
#' `user_prompt_submit.sh` (which have no way to discover R's own
#' `tempdir()`, since that is randomized per R session) -- the project's
#' working directory is the only value both processes already share. The
#' fallback (when `TMPDIR` is unset) is `tempdir()`, not a hardcoded
#' `"/tmp"` -- as of stage 020, since `/tmp` does not exist on native
#' Windows R, while `tempdir()` always resolves to a real, writable,
#' platform-appropriate directory. Not cached: recomputed from the current
#' `getwd()` on every call, matching the pre-existing (pre-relocation)
#' behavior of writing relative to whatever the working directory happens
#' to be at call time.
#' @keywords internal
#' @noRd
askfirst_state_dir <- function() {
  as.character(fs::path(
    Sys.getenv("TMPDIR", unset = tempdir()),
    "askfirst",
    askfirst_mangle_path(getwd())
  ))
}
