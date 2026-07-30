---
created: 2026-07-30T17:05:00Z
agent: claude-sonnet-5
git_hash: f20a22eea6944c52deefe3a9687949829acc28c2
---

# Design Decisions: install-all-detected-agents

## Summary
Replaced the agent-hooks installer's single-choice "multiple tools detected"
prompt (which could never actually trigger, since opencode was never
auto-detected) with detect-and-install-all behavior, added a stdin-aware
fallback (interactive prompt, or a clear non-hanging error) for the
zero-detected case, made the tool list data-driven from
`agent-hooks/manifest.json`, and un-exported the R binding's detection
helper now that installation handles detection internally. A real latent
bug was found and fixed along the way: an empty-array `printf` call made
"zero tools detected" indistinguishable from "one match" to every caller.

## New Design Decisions

### Decision 1: Detect-and-install-all, replacing single-choice selection
**Chosen:** `agent-hooks/install-agent-hooks.sh` now installs hooks for
every tool `detect_tools()` finds (looping, reporting each), rather than
prompting the user to pick one among several detected tools. `--tool
<name>` still installs a single explicit tool as before.
**Rationale:** Installing for only one of several genuinely-in-use tools
would silently leave the others without hook context; the prior
single-choice prompt was also unreachable dead code in practice, since only
`claude` was ever auto-detected.
**Tradeoffs:** A per-tool failure no longer aborts the whole run; failures
are collected and reported together at the end, changing the installer's
prior fail-fast semantics for the multi-tool case.
**Proposed by:** joint

### Decision 2: Real opencode auto-detection via a project-level `.opencode/` directory
**Chosen:** `detect_tools()` treats an existing `.opencode/` directory as
"opencode detected," making install-all-detected a reachable case rather
than one that could only ever apply to a single tool.
**Rationale:** Confirmed against opencode's own current config-discovery
docs that all config locations are read and merged (not first-match-wins),
and that a project-level `.opencode/` directory is one such location,
always read when present — a reliable signal, independent of
`opencode.json` (which askfirst never reads or writes, since it only
installs into `.opencode/plugins/`, auto-discovered per stage 017).
**Roads not taken:** Checking for `opencode.json`'s presence too — rejected
once confirmed askfirst never interacts with that file. Traversing upward
toward the nearest `.git` directory (mirroring opencode's own project-config
search) — rejected as unneeded complexity, since project-level config is
read regardless of what else exists, and the installer already assumes it
runs from the project root everywhere else.
**Proposed by:** joint — this reverses stage 019's assumption that opencode
"has no fixed, project-relative config path to check," which was based on
an incomplete reading of opencode's precedence docs (it does not account
for `.opencode/` itself being one of the read-and-merged locations).

### Decision 3: Tool list spliced into the installer at generation time, not read at run time
**Chosen:** `agent-hooks/generate-install-hooks.sh` gained a new splice
step: a `KNOWN_TOOLS` bash array, generated from
`agent-hooks/manifest.json`'s `tools` object keys, embedded into
`install-agent-hooks.sh` (used for `--list-tools`, tool-name validation,
and the fallback prompt/error text).
**Rationale:** `install-agent-hooks.sh` must remain self-contained — stage
024's `install.sh` fetches only this one file via `curl`, with no
`manifest.json` alongside it — so a live `jq` read of `manifest.json` at
run time would silently find nothing via that path. `bindings/r/R/hooks_status.R`
already carries a hand-maintained, manually-synced hardcoded copy of the
same manifest data for an analogous reason; adding a second such copy was
rejected as the exact duplication this stage was meant to remove.
**Tradeoffs:** Adds a fifth splice target to
`generate-install-hooks.sh`'s regeneration pipeline (stages 012/018/019
established the first four). Accepted as consistent with that pipeline's
existing purpose (single canonical source, generated copies) rather than
a new kind of duplication.
**Proposed by:** joint

### Decision 4: Un-export the R detection helper; `askfirst_install_agent_hooks()` detects internally
**Chosen:** `askfirst_detect_agent_tool()` dropped from the R package's
public API (kept as an internal helper). `askfirst_install_agent_hooks(tool
= NULL, overwrite = FALSE)` now detects internally when `tool` is omitted:
installs every detected tool (reporting each); with none detected, prompts
via `utils::menu()` in an interactive session, or `stop()`s with the
available tools listed in a non-interactive one. Return value changed from
a single unnamed exit-status integer to a named vector (one entry per tool
installed).
**Rationale:** The vignette's own documented example had a latent,
never-exercised bug motivating this: it hardcoded installing both `"claude"`
and `"opencode"` whenever more than one tool was detected (regardless of
what was actually detected), and did nothing when zero were detected.
Internalizing detection removes the need for callers to orchestrate this
themselves.
**Tradeoffs:** Breaking API change (function un-exported, return shape
changed) — accepted pre-1.0, at version `0.0.0.9000`.
**Proposed by:** joint

## Integration with Prior Work
Builds on stage 024's `install.sh`/`install.ps1` (whose self-contained-
installer assumption directly shaped Decision 3) and stage 019's manifest/
version-marker mechanism (`agent-hooks/manifest.json`, now read by the
generator as well as by R's `askfirst_hooks_status()`). Stage 017's
opencode-plugin auto-discovery design (`.opencode/plugins/`, no config
registration) is what makes `.opencode/`'s mere presence a safe detection
signal in Decision 2.

## Issues Resolved
- The zero-detected case: previously a hard error with no fallback; now
  prompts interactively or fails clearly, without hanging, when stdin isn't
  a terminal (verified against the `curl install.sh | bash` invocation
  shape specifically).
- A real bug, found during implementation rather than anticipated in the
  plan: `detect_tools()`'s `printf '%s\n' "${found[@]}"` emitted a single
  blank line even when `found` was empty (bash's `printf` always applies
  its format string at least once), so a genuinely empty detection result
  was indistinguishable from one match to every caller (`mapfile`, command
  substitution). Fixed by only calling `printf` when the array is
  non-empty.
- The vignette's (and `askfirst-development.Rmd`'s) example code, which
  would error today given the un-export in Decision 4, was updated in the
  same pass.

## Deferred Items
None — tool-list sourcing, the opencode detection signal, non-interactive
fallback behavior, and the R export/return-value changes were all resolved
during this stage.

## Process Notes
- The self-contained-installer constraint on Decision 3 was found during
  `/designlens.make-tasks`, after the plan had already been reviewed and
  approved; `plan.md` was revised in place to incorporate the resolution
  before `tasks.md` was written, keeping the two documents consistent.
- The opencode detection signal (Decision 2) went through two rounds of
  correction during `/designlens.new-stage`: an initial proposal citing
  `~/.opencode` was corrected against opencode's actual docs to
  `~/.config/opencode/`, then further narrowed to the project-level
  `.opencode/` directory once mpadge pointed out the docs' precedence list
  already covered it and that all locations are read and merged rather than
  first-match-wins.
