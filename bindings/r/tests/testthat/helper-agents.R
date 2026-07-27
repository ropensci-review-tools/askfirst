# Recursively collects every env var `name` referenced anywhere in a parsed
# agents.json match-condition tree, so tests can unset all known signals
# without hardcoding (and risking drift from) the vendored tool list.
collect_env_var_names <- function(cond) {
  if (is.null(cond)) {
    return(character(0))
  }
  if (identical(cond$type, "env_set") || identical(cond$type, "env_value") ||
    identical(cond$type, "env_matches")) {
    return(cond$name)
  }
  if (identical(cond$type, "anyOf") || identical(cond$type, "allOf")) {
    return(unlist(lapply(cond$conditions, collect_env_var_names)))
  }
  character(0)
}

all_known_signal_env_vars <- function() {
  spec <- askfirst:::askfirst_load_agents()
  vars <- unlist(lapply(spec$agents, function(agent) collect_env_var_names(agent$match)))
  unique(c(vars, spec$aiAgentVar))
}
