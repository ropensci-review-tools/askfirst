# CI/pre-commit check: fails if bindings/r/inst/agent-content/ has drifted
# from the repo-root agent-content/ source of truth. Run
# bindings/r/data-raw/sync-agent-content.R and commit the result if this
# fails.
#
# Run from the repository root: Rscript bindings/r/data-raw/check-agent-content-sync.R

src_dir <- "agent-content"
dest_dir <- as.character(fs::path("bindings", "r", "inst", "agent-content"))

files <- list.files(src_dir, pattern = "\\.txt$")

mismatches <- character(0)
for (f in files) {
  src_file <- as.character(fs::path(src_dir, f))
  dest_file <- as.character(fs::path(dest_dir, f))
  if (!file.exists(dest_file)) {
    mismatches <- c(mismatches, sprintf("%s is missing", dest_file))
    next
  }
  if (!identical(readLines(src_file), readLines(dest_file))) {
    mismatches <- c(mismatches, sprintf("%s differs from %s", dest_file, src_file))
  }
}

if (length(mismatches) > 0) {
  cat("agent-content data out of sync:\n")
  cat(paste(" -", mismatches), sep = "\n")
  cat("Run: Rscript bindings/r/data-raw/sync-agent-content.R\n")
  quit(status = 1)
}

cat("bindings/r/inst/agent-content/ is in sync with agent-content/\n")
