#' Evaluate a single agent-detect-spec match condition (or combinator)
#'
#' @param cond A parsed condition node (a list with a `type` field), as
#'   found in `agent-detect-spec`'s vendored `agents.json`.
#' @return `TRUE`/`FALSE`.
#' @keywords internal
#' @noRd
pkghooks_eval_condition <- function(cond) {
  switch(
    cond$type,
    env_set = nzchar(Sys.getenv(cond$name, unset = "")),
    env_value = identical(Sys.getenv(cond$name, unset = NA_character_), cond$value),
    env_matches = {
      val <- Sys.getenv(cond$name, unset = "")
      nzchar(val) && grepl(cond$pattern, val, perl = TRUE)
    },
    file_exists = file.exists(cond$path),
    no_tty = !isatty(stdin()) || !isatty(stdout()),
    anyOf = any(vapply(cond$conditions, pkghooks_eval_condition, logical(1))),
    allOf = all(vapply(cond$conditions, pkghooks_eval_condition, logical(1))),
    stop("pkghooks: unknown condition type in agents.json: ", cond$type, call. = FALSE)
  )
}

#' Path to the vendored agent-detect-spec agents.json
#' @keywords internal
#' @noRd
pkghooks_agents_path <- function() {
  system.file("agent-detect-spec", "agents.json", package = "pkghooks")
}

#' Load and parse the vendored agents.json
#' @keywords internal
#' @noRd
pkghooks_load_agents <- function() {
  path <- pkghooks_agents_path()
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

#' Detect which known AI coding tool (if any) the current process matches
#'
#' Evaluates `agent-detect-spec`'s vendored `agents.json` entries in array
#' order (first-match-wins, matching upstream's own evaluation semantics)
#' against the current process's environment variables and TTY state.
#'
#' @return A list with `key` and `name` for the first matching agent entry,
#'   or `NULL` if none match.
#' @keywords internal
#' @noRd
pkghooks_detect_tool <- function() {
  spec <- pkghooks_load_agents()
  for (agent in spec$agents) {
    if (isTRUE(pkghooks_eval_condition(agent$match))) {
      return(list(key = agent$key, name = agent$name))
    }
  }
  NULL
}
