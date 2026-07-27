# agent-detect-spec

A language-agnostic contract for detecting when software is being called by
an LLM/AI coding agent rather than a human, and for deciding when and how
severely to respond. `pkghooks` (the R package in this repo) is the first
consumer; this directory is kept independent of the R package's own `R/`,
`man/`, `tests/` structure so the contract itself is unambiguously portable,
not R-specific.

## Layout

- **`vendor/agents.json`** and **`vendor/agents.schema.json`** — an
  unmodified copy of `vercel/detect-agent`'s detection-signal
  specification: which environment variables, environment values, or
  filesystem markers identify which AI coding tool. Consumed as-is, using
  upstream's own schema — this repo does not define a parallel schema for
  detection signals, since duplicating `agents.json` into a
  `pkghooks`-specific shape would just be a second thing to keep in sync
  for no real benefit.
- **`confidence-model.md`** — the layer `agents.json` does not provide: how
  to map a raw detection outcome (a vendored-data match, or the absence of
  one, plus optional TTY/process-ancestry corroboration) onto a
  `high`/`medium`/`low`/`cooperative` confidence tier.
- **`intervention-model.md`** — the abstract, language-neutral messaging
  model: three independent points (`load_time`, `error_time`,
  `capability_gap_time`) at which a redirect-to-maintainer message may be
  delivered, with trigger, severity, and cardinality semantics for each.
- **`manifest.json`** — versioning and provenance metadata (see below).

## Versioning

`manifest.json`'s `version` field (semantic versioning) covers **this
directory's own contribution** — the confidence model, the intervention
model, and the sync tooling — not the content of `vendor/agents.json`,
which has its own upstream provenance recorded separately under
`manifest.json`'s `vendor_source` key (`last_synced_commit`,
`last_synced_commit_date`, `last_synced_at`). Bump `version` whenever
`confidence-model.md` or `intervention-model.md` changes in a way a
downstream consumer (starting with the R implementation) needs to notice.
A `vendor/agents.json` update from the sync workflow does **not** require
bumping `version` on its own, since it's the same contract consuming newer
upstream data, not a change to the contract itself.

## Keeping vendored data current

`.github/workflows/sync-agent-detect-spec.yml` runs weekly (and can be
triggered manually via `workflow_dispatch`). It fetches the current
`agents.json`/`agents.schema.json` from `vercel/detect-agent`, diffs them
against `vendor/`, and — if they differ — opens a pull request updating the
vendored files and `manifest.json`'s `vendor_source` metadata. No
reconciliation logic is needed beyond the diff itself, since `vendor/`
*is* the detection data consumed directly, not an input to a second,
hand-curated file.

When that PR appears:

1. Review the diff — what tool entries were added, removed, or changed.
2. Merge it once satisfied; no other repo changes are required, since
   consumers read `vendor/agents.json` directly.
3. If a new upstream entry motivates a change to `confidence-model.md` or
   `intervention-model.md` (unlikely, since those are independent of which
   specific tools are listed), make that change separately and bump
   `manifest.json`'s `version`.
