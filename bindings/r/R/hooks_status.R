#' Compiled-in copy of `agent-hooks/manifest.json`
#'
#' The installed R package does not ship the repo-relative `agent-hooks/`
#' directory, so this is a hand-maintained copy of the same data --
#' `hooks_dir` per supported coding-agent tool, plus the current
#' `hook_version` -- kept in sync manually whenever
#' `agent-hooks/manifest.json` changes. `hooks_dir` is a fixed,
#' askfirst-controlled location where `tools/install-agent-hooks.sh` places
#' its own hook scripts, independent of each tool's own config-file search
#' path -- Claude Code's config lives at a fixed project-relative path
#' (`.claude/settings.json`), but opencode's config file (`opencode.json`)
#' is discovered via a precedence order across several possible locations
#' (see <https://opencode.ai/docs/config#precedence-order>), not a single
#' fixed path, so no config path is recorded here at all; only `hooks_dir`
#' is checked. The path/version-marker convention this represents is
#' deliberately language-agnostic in shape (same relative paths, same
#' `# askfirst-hook-version: <N>` marker format), so a future Python/Julia/
#' Rust binding can implement the equivalent check without redesigning the
#' underlying scheme.
#' @keywords internal
#' @noRd
askfirst_hooks_manifest <- function() {
  list(
    hook_version = 2L,
    tools = list(
      claude = list(hooks_dir = ".claude/hooks"),
      opencode = list(hooks_dir = ".opencode/hooks")
    )
  )
}

#' Extract the `# askfirst-hook-version: <N>` marker from a hook script
#' @return An integer version, or `NA_integer_` if the file has no marker
#'   line (e.g. hooks installed before this stage introduced versioning).
#' @keywords internal
#' @noRd
askfirst_hook_version_from_file <- function(path) {
  lines <- tryCatch(readLines(path, warn = FALSE), error = function(e) character())
  marker <- grep("^#\\s*askfirst-hook-version:\\s*[0-9]+", lines, value = TRUE)
  if (length(marker) == 0) {
    return(NA_integer_)
  }
  as.integer(sub("^#\\s*askfirst-hook-version:\\s*([0-9]+).*$", "\\1", marker[[1]]))
}

#' Hooks-installation status for a single tool, relative to `getwd()`
#' @return One of `"not_installed"`, `"stale"`, `"current"`.
#' @keywords internal
#' @noRd
askfirst_hooks_status_for_tool <- function(tool, manifest = askfirst_hooks_manifest()) {
  hooks_dir <- manifest$tools[[tool]]$hooks_dir
  target <- file.path(hooks_dir, "session_start.sh")
  if (!file.exists(target)) {
    return("not_installed")
  }
  version <- askfirst_hook_version_from_file(target)
  if (is.na(version) || version < manifest$hook_version) {
    return("stale")
  }
  "current"
}

#' Overall askfirst-hooks installation status for the current project
#'
#' Checks each known coding-agent tool's hooks directory, relative to the
#' current working directory, for a `session_start.sh` carrying a current
#' `# askfirst-hook-version:` marker. Reports the best status found across
#' all known tools: `"current"` if any one tool's hooks are current, else
#' `"stale"` if any tool's hooks exist but are out of date, else
#' `"not_installed"` if no known tool's hooks directory exists at all.
#'
#' Kept pure/side-effect-free (no printing) so it can be unit tested
#' directly; see [askfirst_init()] for where its result drives a one-time,
#' human-directed nudge to install/update hooks via
#' `tools/install-agent-hooks.sh`.
#' @return A single string: one of `"not_installed"`, `"stale"`, `"current"`.
#' @keywords internal
#' @noRd
askfirst_hooks_status <- function() {
  manifest <- askfirst_hooks_manifest()
  statuses <- vapply(
    names(manifest$tools),
    askfirst_hooks_status_for_tool,
    character(1),
    manifest = manifest
  )
  if (any(statuses == "current")) {
    return("current")
  }
  if (any(statuses == "stale")) {
    return("stale")
  }
  "not_installed"
}

#' Print a one-time, human-directed nudge to install/update askfirst hooks
#'
#' Called from [askfirst_init()], independent of the session's `confidence`
#' tier -- unlike [askfirst_signal()]'s agent-directed conditions, this
#' message is for the human running the session: the whole reason to show
#' it is that hooks context can't be relied on to reach an agent at all
#' while hooks are missing or stale, so it isn't gated on agent detection.
#' Only ever prints once per session (tracked via
#' `.askfirst_state$hooks_nudge_shown`), regardless of how many adopting
#' packages call `askfirst_init()`.
#' @keywords internal
#' @noRd
askfirst_maybe_nudge_hooks_install <- function() {
  if (isTRUE(.askfirst_state$hooks_nudge_shown)) {
    return(invisible(NULL))
  }
  status <- askfirst_ensure_hooks_status()
  if (status %in% c("not_installed", "stale")) {
    cli::cli_inform(paste(
      "askfirst: no current agent hooks detected for this project.",
      "Run {.code tools/install-agent-hooks.sh} (from the askfirst",
      "repository) to install or update hooks that help AI coding",
      "assistants recognise askfirst's structured signals."
    ))
  }
  .askfirst_state$hooks_nudge_shown <- TRUE
  invisible(NULL)
}
