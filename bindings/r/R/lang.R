#' Language identifier for the current binding
#'
#' Returns the language component used in the structured prefix
#' (`askfirst::<language>::<pkg>::<type>`). Each binding overrides this:
#' the R binding returns `"r"`, a future Python binding would return
#' `"python"`, etc.
#' @keywords internal
#' @noRd
askfirst_lang <- function() {
  "r"
}

#' Placeholder URL for askfirst documentation
#'
#' Returns the URL appended to every structured signal as a `See: <url>`
#' line. This is a placeholder target — the actual documentation page about
#' askfirst's agent protocol does not exist yet.
#' @keywords internal
#' @noRd
askfirst_url <- function() {
  "https://ropensci.github.io/askfirst/"
}
