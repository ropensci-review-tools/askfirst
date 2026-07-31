#' Locate a working `bash`, skipping Windows' WSL-launcher stub
#'
#' On Windows, \code{Sys.which("bash")} can resolve to
#' \code{C:\\Windows\\System32\\bash.exe} -- a Microsoft-provided stub that
#' launches WSL, ahead of Git Bash's own \code{bash.exe} on \code{PATH}.
#' Confirmed empirically in CI: that stub errors immediately ("Windows
#' Subsystem for Linux has no installed distributions") when no WSL
#' distribution is installed, so anything invoked through it silently
#' fails. This walks \code{PATH} directly and returns the first
#' \code{bash.exe} found outside a \code{System32} directory, falling back
#' to plain \code{"bash"} (ordinary \code{PATH} resolution) on non-Windows
#' platforms or if nothing else is found.
#' @keywords internal
#' @noRd
askfirst_find_bash <- function() {
  if (.Platform$OS.type != "windows") {
    return("bash")
  }
  path_dirs <- strsplit(Sys.getenv("PATH"), .Platform$path.sep, fixed = TRUE)[[1]]
  for (dir in path_dirs) {
    candidate <- file.path(dir, "bash.exe")
    if (file.exists(candidate) && !grepl("[/\\\\]system32[/\\\\]?$", dir, ignore.case = TRUE)) {
      return(candidate)
    }
  }
  Sys.which("bash")
}

#' Run agent-hooks/install-agent-hooks.sh through an explicit `bash`
#'
#' Never execute the script "directly" (i.e. \code{system2(script, ...)}
#' relying on its `#!/bin/bash` shebang) -- that depends on the OS
#' understanding shebang lines, which Windows does not; this is the same
#' reason \code{install.ps1} locates and shells out to \code{bash} rather
#' than trying to run the downloaded script as if it were a native
#' executable. Explicitly invoking through `bash` here works identically
#' on every OS, `bash` being a hard prerequisite already (Git Bash/WSL, per
#' \code{install.ps1}'s own requirement).
#' @keywords internal
#' @noRd
askfirst_run_installer_script <- function(args, stdout, stderr) {
  script <- system.file("agent-hooks", "install-agent-hooks.sh", package = "askfirst", mustWork = TRUE)
  system2(askfirst_find_bash(), c(script, args), stdout = stdout, stderr = stderr)
}

#' Detect available agent tool(s) for the current project
#'
#' Calls \code{agent-hooks/install-agent-hooks.sh --detect} to check which agent
#' tools have configuration files in the current working directory.
#' Returns a character vector of tool names (e.g. \code{"claude"},
#' \code{"opencode"}), possibly of length zero. Internal only, as of stage
#' 025 -- \code{\link{askfirst_install_agent_hooks}} calls this itself, so
#' callers no longer need to detect a tool before installing.
#' @return A character vector of detected tool names.
#' @keywords internal
#' @noRd
askfirst_detect_agent_tool <- function() {
  out <- askfirst_run_installer_script("--detect", stdout = TRUE, stderr = FALSE)
  if (length(out) == 0 || identical(out, "")) character() else out
}

#' List all agent tools askfirst knows how to install hooks for
#'
#' Calls \code{agent-hooks/install-agent-hooks.sh --list-tools}, which
#' prints the tool names generated from \code{agent-hooks/manifest.json}
#' (spliced into the installer at generation time -- see
#' \code{agent-hooks/generate-install-hooks.sh} -- so this works without a
#' runtime read of that file). This is the same source the shell installer
#' itself uses for its fallback prompt and unknown-tool error text, so R
#' and the shell installer never present a different set of "available
#' tools" to the user.
#' @return A character vector of all known tool names (e.g. \code{"claude"},
#'   \code{"opencode"}).
#' @keywords internal
#' @noRd
askfirst_list_agent_tools <- function() {
  askfirst_run_installer_script("--list-tools", stdout = TRUE, stderr = FALSE)
}

#' Install hooks for a single, already-known tool name
#'
#' Shared by \code{\link{askfirst_install_agent_hooks}} for each tool it
#' installs, whether explicitly requested or auto-detected.
#' @return The shell script's exit status (0 on success).
#' @keywords internal
#' @noRd
askfirst_install_agent_hooks_for_tool <- function(tool, overwrite) {
  stopifnot(
    "`tool` must be a single string" = is.character(tool) && length(tool) == 1
  )

  args <- c("--tool", tool)
  if (isTRUE(overwrite)) {
    args <- c(args, "--overwrite")
  }

  askfirst_run_installer_script(args, stdout = "", stderr = "")
}

#' Install askfirst agent hooks for the current project
#'
#' Installs SessionStart, PostToolUse, and UserPromptSubmit hooks for the
#' specified agent tool -- or, when \code{tool} is omitted, detects and
#' installs hooks for every agent tool found in the current project,
#' reporting which tool(s) were installed. When none are detected, prompts
#' interactively for a tool name (in an interactive session), or errors
#' with the available tool names and instructions to pass \code{tool}
#' explicitly (in a non-interactive session).
#'
#' The shell script is located via \code{system.file("agent-hooks",
#' "install-agent-hooks.sh", package = "askfirst")} -- it lives inside the
#' \code{agent-hooks/} directory, which is symlinked whole into the
#' package's \code{inst/} directory from the repo root (as of stage 018,
#' \code{install-agent-hooks.sh} moved into \code{agent-hooks/} itself,
#' so this one symlink covers it -- no separate symlink is needed).
#'
#' @param tool A single string (\code{"claude"} or \code{"opencode"}), or
#'   \code{NULL} (the default) to auto-detect.
#' @param overwrite If \code{TRUE}, replace existing hook files. Default
#'   \code{FALSE} (skip existing files with a message).
#' @return Invisibly, a named integer vector of exit statuses (0 on
#'   success), one entry per tool installed, named by tool. (Prior to
#'   stage 025, when \code{tool} was a required argument, this returned a
#'   single unnamed integer -- a breaking change, acceptable pre-1.0, at
#'   version \code{0.0.0.9000}.)
#' @export
#' @examples
#' \dontrun{
#' # Detect and install for every agent tool found in this project,
#' # or prompt/error if none are found:
#' askfirst_install_agent_hooks()
#'
#' # Install for one tool explicitly:
#' askfirst_install_agent_hooks("claude")
#' askfirst_install_agent_hooks("opencode", overwrite = TRUE)
#' }
askfirst_install_agent_hooks <- function(tool = NULL, overwrite = FALSE) {
  if (is.null(tool)) {
    detected <- askfirst_detect_agent_tool()
    if (length(detected) > 0) {
      tool <- detected
    } else {
      available <- askfirst_list_agent_tools()
      if (!interactive()) {
        stop(
          sprintf(
            "No agent tool detected in the current directory, and this R session is not interactive.\nAvailable tools: %s\nCall askfirst_install_agent_hooks(tool = \"...\") with one of these explicitly.",
            paste(available, collapse = ", ")
          ),
          call. = FALSE
        )
      }
      choice <- utils::menu(available, title = "No agent tool detected. Which tool should hooks be installed for?")
      if (choice == 0) {
        stop("No tool selected; hooks were not installed.", call. = FALSE)
      }
      tool <- available[choice]
    }
  }

  statuses <- integer(length(tool))
  names(statuses) <- tool
  for (t in tool) {
    if (length(tool) > 1) {
      message("Installing hooks for detected tool: ", t)
    }
    statuses[[t]] <- askfirst_install_agent_hooks_for_tool(t, overwrite)
  }

  invisible(statuses)
}
