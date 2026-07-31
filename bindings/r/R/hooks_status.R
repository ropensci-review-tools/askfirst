#' Compiled-in copy of `agent-hooks/manifest.json`
#'
#' The installed R package does not ship the repo-relative `agent-hooks/`
#' directory, so this is a hand-maintained copy of the same data --
#' `hooks_dir` and `marker_file` per supported coding-agent tool, plus the
#' current `hook_version` -- kept in sync manually whenever
#' `agent-hooks/manifest.json` changes. `hooks_dir` is a fixed,
#' askfirst-controlled location where `agent-hooks/install-agent-hooks.sh` places
#' its own hook/plugin file(s), independent of each tool's own config-file
#' search path -- Claude Code's config lives at a fixed project-relative
#' path (`.claude/settings.json`), but opencode's config file
#' (`opencode.json`) is discovered via a precedence order across several
#' possible locations (see
#' <https://opencode.ai/docs/config#precedence-order>), not a single fixed
#' path, so no config path is recorded here at all; only `hooks_dir` is
#' checked. `marker_file` is the specific file within `hooks_dir` whose
#' version marker is authoritative for that tool -- as of stage 017 this
#' differs by tool in both name and comment style (Claude Code:
#' `askfirst-session-start.sh`, a `# askfirst-hook-version: <N>` shell
#' comment; opencode: `askfirst-plugin.js`, a `// askfirst-hook-version: <N>`
#' JS comment, since opencode's mechanism is a real JS plugin rather than a
#' shell-script family -- see `agent-hooks/opencode/askfirst-plugin.js`).
#' As of stage 023, Claude Code's hook filenames are askfirst-namespaced
#' (`askfirst-session-start.sh`/`askfirst-post-tool-use.sh`/
#' `askfirst-user-prompt-submit.sh`) rather than the prior generic
#' `session_start.sh`/`post_tool_use.sh`/`user_prompt_submit.sh`, to avoid
#' colliding with another tool's own hook scripts occupying the same
#' conventional filename in a shared `.claude/hooks/` directory.
#'
#' The `hook_version` below must be the same as in `agent-hooks/manifest.json`.
#' This is the only other place that it is hard-coded (see specs/028).
#'
#' @keywords internal
#' @noRd
askfirst_hooks_manifest <- function() {
  list(
    hook_version = 1L,
    tools = list(
      claude = list(hooks_dir = ".claude/hooks", marker_file = "askfirst-session-start.sh"),
      opencode = list(hooks_dir = ".opencode/plugins", marker_file = "askfirst-plugin.js")
    )
  )
}

#' Extract the `askfirst-hook-version: <N>` marker from a hook/plugin file
#'
#' Recognises both the `# askfirst-hook-version: <N>` shell-comment form
#' (Claude Code's hook scripts) and the `// askfirst-hook-version: <N>`
#' JS-comment form (opencode's plugin file, since stage 017).
#' @return An integer version, or `NA_integer_` if the file has no marker
#'   line (e.g. hooks installed before this stage introduced versioning).
#' @keywords internal
#' @noRd
askfirst_hook_version_from_file <- function(path) {
  lines <- tryCatch(readLines(path, warn = FALSE), error = function(e) character())
  marker <- grep("^(#|//)\\s*askfirst-hook-version:\\s*[0-9]+", lines, value = TRUE)
  if (length(marker) == 0) {
    return(NA_integer_)
  }
  as.integer(sub("^(#|//)\\s*askfirst-hook-version:\\s*([0-9]+).*$", "\\2", marker[[1]]))
}

#' Hooks-installation status for a single tool, relative to `getwd()`
#' @return One of `"not_installed"`, `"stale"`, `"current"`.
#' @keywords internal
#' @noRd
askfirst_hooks_status_for_tool <- function(tool, manifest = askfirst_hooks_manifest()) {
  hooks_dir <- manifest$tools[[tool]]$hooks_dir
  marker_file <- manifest$tools[[tool]]$marker_file
  target <- as.character(fs::path(hooks_dir, marker_file))
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
#' current working directory, for an `askfirst-session-start.sh` carrying a
#' current `# askfirst-hook-version:` marker. Reports the best status found
#' across
#' all known tools: `"current"` if any one tool's hooks are current, else
#' `"stale"` if any tool's hooks exist but are out of date, else
#' `"not_installed"` if no known tool's hooks directory exists at all.
#'
#' Kept pure/side-effect-free (no printing) so it can be unit tested
#' directly; see [askfirst_init()] for where its result drives a one-time,
#' human-directed nudge to install/update hooks via
#' `agent-hooks/install-agent-hooks.sh`.
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

#' Print a one-time, human-directed nudge to install/update askfirst hooks,
#' plus (stage 019) a confidence-gated agent-directed nudge
#'
#' Called from [askfirst_init()], with two independent channels:
#'
#' - A **human-directed** `cli::cli_inform()` console message, printed
#'   independent of the session's `confidence` tier -- unlike
#'   `askfirst_signal()`'s agent-directed conditions, this message is for
#'   the human running the session: the whole reason to show it is that
#'   hooks context can't be relied on to reach an agent at all while hooks
#'   are missing or stale, so it isn't gated on agent detection. This
#'   channel is unchanged since stage 014.
#' - An **agent-directed** `askfirst_hooks_nudge` condition (stage 019),
#'   signalled via `askfirst_signal()` only when `.askfirst_state$confidence`
#'   is `"high"` -- unlike the hooks themselves, `askfirst_signal()`'s
#'   condition-based channel does not depend on any hooks being installed,
#'   so it can reach an agent-driven session even while hooks are missing.
#'   This is additive to, not a replacement for, the human-directed nudge
#'   above.
#'
#' Both channels are gated by the same `not_installed`/`stale` status check
#' and the same once-per-session flag (`.askfirst_state$hooks_nudge_shown`):
#' they fire together (or not at all) as two deliveries of the same
#' underlying event, regardless of how many adopting packages call
#' `askfirst_init()`.
#' @param pkg The name of the adopting package that triggered this check
#'   (attributed on the `askfirst_hooks_nudge` condition, if signalled).
#' @keywords internal
#' @noRd
askfirst_maybe_nudge_hooks_install <- function(pkg) {
  if (isTRUE(.askfirst_state$hooks_nudge_shown)) {
    return(invisible(NULL))
  }
  status <- askfirst_ensure_hooks_status()
  if (status %in% c("not_installed", "stale")) {
    cli::cli_inform(paste(
      "askfirst: no current agent hooks detected for this project.",
      "Run {.code agent-hooks/install-agent-hooks.sh} (from the askfirst",
      "repository) to install or update hooks that help AI coding",
      "assistants recognise askfirst's structured signals."
    ))
    if (identical(.askfirst_state$confidence, "high")) {
      message <- gsub("{{PKG}}", pkg, askfirst_read_content("askfirst-hooks-nudge.txt"), fixed = TRUE)
      askfirst_signal("askfirst_hooks_nudge", pkg = pkg, message = message)
    }
  }
  .askfirst_state$hooks_nudge_shown <- TRUE
  invisible(NULL)
}
