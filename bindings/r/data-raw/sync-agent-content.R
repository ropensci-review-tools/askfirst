# Copies the repo-root agent-content/ files (the single source of truth
# for askfirst's fixed, binding-agnostic condition/notice text) into
# bindings/r/inst/agent-content/, so the askfirst R package is
# self-contained and installable independently of this monorepo. Re-run
# after agent-content/ changes.
#
# Run from the repository root: Rscript bindings/r/data-raw/sync-agent-content.R

src_dir <- "agent-content"
dest_dir <- file.path("bindings", "r", "inst", "agent-content")

stopifnot(
  "run this script from the repository root (src_dir not found)" =
    dir.exists(src_dir)
)

dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(src_dir, pattern = "\\.txt$")
for (f in files) {
  file.copy(
    file.path(src_dir, f),
    file.path(dest_dir, f),
    overwrite = TRUE
  )
}

cat(sprintf("Synced %s to %s\n", src_dir, dest_dir))
