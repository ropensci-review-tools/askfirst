# Copies the repo-root agent-detect-spec/vendor/ files (the single source
# of truth) into r/inst/agent-detect-spec/, so the pkghooks R package is
# self-contained and installable independently of this monorepo. Re-run
# after agent-detect-spec/vendor/ changes (e.g. after the
# sync-agent-detect-spec.yml Action updates it).
#
# Run from the repository root: Rscript r/data-raw/sync-vendor.R

src_dir <- file.path("agent-detect-spec", "vendor")
dest_dir <- file.path("r", "inst", "agent-detect-spec")

stopifnot(
  "run this script from the repository root (src_dir not found)" =
    dir.exists(src_dir)
)

dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

files <- c("agents.json", "agents.schema.json")
for (f in files) {
  file.copy(
    file.path(src_dir, f),
    file.path(dest_dir, f),
    overwrite = TRUE
  )
}

cat(sprintf("Synced %s to %s\n", src_dir, dest_dir))
