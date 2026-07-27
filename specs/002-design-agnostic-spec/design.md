# Design: design-agnostic-spec

Implementation output for stage `002-design-agnostic-spec`. Sections
correspond 1:1 to the tasks in `tasks.md`.

---

## T002-1: Vendor upstream agents.json

Fetched `agents.json` and its companion `agents.schema.json` verbatim from
`vercel/detect-agent`'s `main` branch, saved unmodified at
`agent-detect-spec/vendor/agents.json` and
`agent-detect-spec/vendor/agents.schema.json`. Both files are consumed
directly using upstream's own schema — no `pkghooks`-specific reformatting.

The vendored data covers 17 agents (`cursor`, `cursor-cli`, `gemini`,
`cline`, `codex`, `antigravity`, `augment-cli`, `opencode`, `goose`,
`junie`, `pi`, `cowork`, `claude`, `replit`, `github-copilot`, `kiro`,
`openclaw`, `devin`), which is a superset of stage 001's T001-1 survey
table — it additionally includes `pi` (a PATH-segment-based check not
identified in stage 001) and explicitly orders `cowork` before `claude` so
the more specific Cowork marker wins, matching stage 001's own note about
`CLAUDE_CODE_IS_COWORK`. This confirms the mid-stage scope reduction was
correct: upstream's data already covers everything stage 001 surveyed, with
no gaps that would have justified maintaining a parallel schema.

The last commit touching `agents.json` at fetch time was
`db63e913876eebbe8526e67a21d5ab392a58908c` (2026-07-15T20:48:51Z),
recorded in `manifest.json`.

---

## T002-2: Write the spec manifest

Wrote `agent-detect-spec/manifest.json` with `name`, `version: "0.1.0"`,
a `files` map pointing to the vendored data/schema and the two model
documents, and a `vendor_source` object recording the upstream repo, path,
URLs, last-synced commit/date, and sync timestamp.

---

## T002-3: Build the upstream sync GitHub Action

Wrote `.github/workflows/sync-agent-detect-spec.yml`: triggered weekly via
`schedule` (Mondays 06:00 UTC) and manually via `workflow_dispatch`. It
fetches the current upstream `agents.json`/`agents.schema.json`, diffs them
against the vendored copies, and — only if they differ — updates the
vendored files, refreshes `manifest.json`'s `vendor_source` metadata, and
opens a pull request via `peter-evans/create-pull-request` rather than
auto-merging, so a human reviews any upstream change before it takes
effect for consumers. Validated the workflow file as syntactically valid
YAML.

---

## T002-4: Document the abstract confidence-tiering model

Wrote `agent-detect-spec/confidence-model.md`: a closed
`high`/`medium`/`low`/`cooperative` enum with ordered mapping rules —
`high` on any vendored-data match, `medium` for no match plus TTY/ancestry
corroboration, `low` for no signals at all, and `cooperative` reserved
(currently unused by any lookup path) for a future tool-initiated signal.
This resolves `plan.md`'s confidence-enum question in favor of closed, as
decided before implementation began.

---

## T002-5: Document the abstract intervention-point model

Wrote `agent-detect-spec/intervention-model.md`: three independent,
language-neutral points — `load_time` (once per session, `notice`
severity), `error_time` (re-triggerable, layered onto existing errors,
`notice` severity), and `capability_gap_time` (re-triggerable,
`halt`-capable, requires author instrumentation since nothing errors in
this case). Documented `first_call`, `every_call`, and `help_access` as
rejected, carrying forward stage 001's reasoning rather than re-deriving
it, and flagged that the `help_access` rejection reasoning is R-specific
and should be re-evaluated by future non-R implementations.

---

## T002-6: Write the spec directory's README

Wrote `agent-detect-spec/README.md`: explains the directory's purpose and
layout, the versioning policy (this directory's own `manifest.json`
`version` covers the confidence/intervention models and sync tooling,
separately from the vendored file's own upstream provenance), and the
sync-workflow review process (review the PR's diff, merge — no other
repo changes required, since `vendor/agents.json` is consumed directly).

---

## T002-7: Synthesis

This stage began with a broader plan — designing an independent JSON
schema and data file mirroring `agents.json`'s content in a
`pkghooks`-specific shape — before the user correctly identified that this
would duplicate `vercel/detect-agent`'s already-maintained data for no real
benefit. The plan and tasks were revised mid-stage to drop that duplication
entirely: `agents.json` is vendored and consumed verbatim, and this stage's
actual design contribution is narrowed to the two layers upstream doesn't
provide — the confidence-tiering model (`confidence-model.md`) and the
abstract intervention-point model (`intervention-model.md`) — plus the
automation (sync workflow, manifest) needed to keep the vendored data
current without hand-maintenance.

Both previously-open questions from `plan.md` are resolved:
- **Confidence-tier enum**: closed (`high`/`medium`/`low`/`cooperative`)
  for v1, extensible later without a breaking change.
- **Detection-data shape**: moot — the vendored file uses whatever shape
  `vercel/detect-agent` defines (a flat array), consumed as-is rather than
  re-derived into a parallel shape.

`agent-detect-spec/` is now a complete, versioned artifact
(`manifest.json` at `0.1.0`) ready to be consumed by a follow-up
R-specific implementation stage, which will map `confidence-model.md`'s
tiers and `intervention-model.md`'s three points onto R's own
`.onLoad()`/`.onAttach()` hooks and condition system — none of which was
designed in this stage.
