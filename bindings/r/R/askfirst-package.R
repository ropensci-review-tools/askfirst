#' askfirst: Detect and Redirect LLM/AI-Agent Callers
#'
#' Lets R package maintainers detect when their package's functions are
#' being called by an LLM/AI coding agent rather than a human, and issue a
#' message redirecting the agent to tell the human user to contact the
#' maintainer directly instead of silently working around a bug or missing
#' capability.
#'
#' Call [askfirst_init()] once from your own package's `.onLoad()`, and
#' call [askfirst_capability_gap()] inline at any point your own code
#' recognizes a known limitation has been hit.
#'
#' @keywords internal
"_PACKAGE"
