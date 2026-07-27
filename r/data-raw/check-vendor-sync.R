# CI check: fails if r/inst/agent-detect-spec/ has drifted from the
# repo-root agent-detect-spec/vendor/ source of truth. Run
# r/data-raw/sync-vendor.R and commit the result if this fails.
#
# Run from the repository root: Rscript r/data-raw/check-vendor-sync.R

src_dir <- file.path("agent-detect-spec", "vendor")
dest_dir <- file.path("r", "inst", "agent-detect-spec")

files <- c("agents.json", "agents.schema.json")

mismatches <- character(0)
for (f in files) {
  src_file <- file.path(src_dir, f)
  dest_file <- file.path(dest_dir, f)
  if (!file.exists(dest_file)) {
    mismatches <- c(mismatches, sprintf("%s is missing", dest_file))
    next
  }
  if (!identical(readLines(src_file), readLines(dest_file))) {
    mismatches <- c(mismatches, sprintf("%s differs from %s", dest_file, src_file))
  }
}

if (length(mismatches) > 0) {
  cat("Vendor data out of sync:\n")
  cat(paste(" -", mismatches), sep = "\n")
  cat("Run: Rscript r/data-raw/sync-vendor.R\n")
  quit(status = 1)
}

cat("r/inst/agent-detect-spec/ is in sync with agent-detect-spec/vendor/\n")
