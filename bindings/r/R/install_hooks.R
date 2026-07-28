#' Detect available agent tool(s) for the current project
#'
#' Calls \code{tools/install-agent-hooks.sh --detect} to check which agent
#' tools have configuration files in the current working directory.
#' Returns a character vector of tool names (e.g. \code{"claude"},
#' \code{"opencode"}), possibly of length zero.
#'
#' @return A character vector of detected tool names.
#' @export
#' @examples
#' \dontrun{
#' askfirst_detect_agent_tool()
#' }
askfirst_detect_agent_tool <- function() {
  script <- system.file("install-agent-hooks.sh", package = "askfirst", mustWork = TRUE)
  out <- system2(script, "--detect", stdout = TRUE, stderr = FALSE)
  if (length(out) == 0 || identical(out, "")) character() else out
}

#' Install askfirst agent hooks for the current project
#'
#' Installs SessionStart, PostToolUse, and UserPromptSubmit hooks for the
#' specified agent tool. Call \code{\link{askfirst_detect_agent_tool}} first
#' if you are unsure which tool to use.
#'
#' The shell script is located via \code{system.file("install-agent-hooks.sh",
#' package = "askfirst")} -- it is symlinked into the package's \code{inst/}
#' directory from the shared \code{tools/} at the repo root.
#'
#' @param tool A single string: \code{"claude"} or \code{"opencode"}.
#'   Required -- use \code{\link{askfirst_detect_agent_tool}} to discover
#'   available tools, then pass the result here.
#' @param overwrite If \code{TRUE}, replace existing hook files. Default
#'   \code{FALSE} (skip existing files with a message).
#' @return Invisibly, the exit status of the shell script (0 on success).
#' @export
#' @examples
#' \dontrun{
#' askfirst_install_agent_hooks("claude")
#' askfirst_install_agent_hooks("opencode", overwrite = TRUE)
#' }
askfirst_install_agent_hooks <- function(tool, overwrite = FALSE) {
  stopifnot(
    "`tool` is required -- call askfirst_detect_agent_tool() first if unsure" = !missing(tool),
    "`tool` must be a single string" = is.character(tool) && length(tool) == 1
  )

  script <- system.file("install-agent-hooks.sh", package = "askfirst", mustWork = TRUE)

  args <- c("--tool", tool)
  if (isTRUE(overwrite)) {
    args <- c(args, "--overwrite")
  }

  status <- system2(script, args, stdout = "", stderr = "")

  invisible(status)
}
