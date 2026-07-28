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
#' Strips a leading `/` and replaces every remaining `/` with `_`. Used to
#' derive a stable, deterministic directory name from a project's working
#' directory, shared independently (with no other coordination) between
#' this R package and the separate `agent-hooks/*/post_tool_use.sh` /
#' `user_prompt_submit.sh` processes, which implement the identical
#' transformation in bash against the `cwd` field of their own hook
#' payload. Deliberately not a hash: the maintainer's explicit choice was a
#' literal, human-debuggable mangling (a maintainer can `ls` their way to
#' the right directory from the project path alone) over hiding the path
#' from other users on a shared multi-user `/tmp`. Deliberately does not
#' call `normalizePath()` or otherwise resolve symlinks -- the bash side
#' has no equivalent resolution step available to it, and asymmetric
#' normalization would make the two sides silently diverge for any project
#' path involving a symlink.
#' @keywords internal
#' @noRd
askfirst_mangle_path <- function(path) {
  gsub("/", "_", sub("^/", "", path))
}

#' Root directory for this session's askfirst runtime state
#'
#' All askfirst runtime state (`log`, `pending/`, `unresolved-notice/`) is
#' session-scoped and has no meaning beyond the current coding-agent
#' session, so none of it is written under the project's own working tree
#' (which would risk it appearing in `git status` or being committed).
#' Instead it lives under `${TMPDIR:-/tmp}/askfirst/<mangled cwd>/`, a path
#' computed independently and identically by this function and by each
#' hook script in `agent-hooks/*/post_tool_use.sh` /
#' `user_prompt_submit.sh` (which have no way to discover R's own
#' `tempdir()`, since that is randomized per R session) -- the project's
#' working directory is the only value both processes already share. Not
#' cached: recomputed from the current `getwd()` on every call, matching
#' the pre-existing (pre-relocation) behavior of writing relative to
#' whatever the working directory happens to be at call time.
#' @keywords internal
#' @noRd
askfirst_state_dir <- function() {
  file.path(
    Sys.getenv("TMPDIR", unset = "/tmp"),
    "askfirst",
    askfirst_mangle_path(getwd())
  )
}
