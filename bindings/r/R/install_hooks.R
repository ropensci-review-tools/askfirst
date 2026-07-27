#' Install askfirst agent hooks for the current project
#'
#' Calls the shared \code{tools/install-agent-hooks.sh} script to detect the
#' active agent tool (Claude Code or opencode) and install the askfirst
#' SessionStart and PostToolUse hooks into the project's tool configuration.
#'
#' The shell script is located via \code{system.file("install-agent-hooks.sh",
#' package = "askfirst")} — it is symlinked into the package's \code{inst/}
#' directory from the shared \code{tools/} at the repo root.
#'
#' @param overwrite If \code{TRUE}, replace existing hook files. Default
#'   \code{FALSE} (skip existing files with a message).
#' @param tool Optional tool name override (\code{"claude"} or
#'   \code{"opencode"}). If \code{NULL} (the default), auto-detect.
#' @return Invisibly, the exit status of the shell script (0 on success).
#' @export
#' @examples
#' \dontrun{
#' askfirst_install_agent_hooks()
#' askfirst_install_agent_hooks(overwrite = TRUE)
#' askfirst_install_agent_hooks(tool = "opencode")
#' }
askfirst_install_agent_hooks <- function(overwrite = FALSE, tool = NULL) {
  script <- system.file("install-agent-hooks.sh", package = "askfirst", mustWork = TRUE)

  args <- character()
  if (isTRUE(overwrite)) {
    args <- c(args, "--overwrite")
  }
  if (!is.null(tool)) {
    args <- c(args, "--tool", tool)
  }

  status <- system2(script, args, stdout = "", stderr = "")

  invisible(status)
}
