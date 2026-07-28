---
created: 2026-07-28T18:32:38Z
agent: claude-sonnet-5
git_hash: f026845aad2ff202bc7df190e31be8c8ae1f4b0f
---

# Design Decisions: Consolidate Agent Hooks Text

## Summary
Removed three genuinely hand-duplicated pieces of content across `agent-hooks/claude/*.sh` and `agent-hooks/opencode/askfirst-plugin.js` (the `<askfirst-context>` prose, escalation-reminder wording, and `askfirst_state_dir()` mangling logic) by introducing canonical source files spliced in by an extended `generate-install-hooks.sh`, and merged the repo-root `tools/` directory into `agent-hooks/`, since its two files existed solely to support it.

## New Design Decisions

### Decision 1: Canonical text/data sources, spliced by an extended generator
**Chosen:** Three new files under `agent-hooks/` — `askfirst-context.txt`, `askfirst-reminder-messages.txt` (with neutral `{{PKG}}`/`{{COUNT}}` placeholders), `askfirst-state-dir.sh` — are the single source of truth for content previously hand-duplicated across bash and JS. `agent-hooks/generate-install-hooks.sh` gained an earlier splicing pass (before its existing per-tool-file-into-installer pass) that translates each canonical source into every target's native syntax: bash heredoc/printf/function body as-is, JS template literals with backticks escaped and `{{PKG}}`/`{{COUNT}}` rendered as `${pkg}`/`${count}`.
**Rationale:** Extends stage 012's existing dev-time generation pattern one layer earlier rather than inventing a new mechanism; keeps installed artifacts (Claude Code's hook scripts, opencode's plugin file) single-file/dependency-free at install time, since generation runs only at commit time.
**Tradeoffs:** The reminder wording's generated source is reformatted (single-line `printf`/template calls instead of the original hand-written multi-line form) — not held to source-level byte-identity, only to identical *rendered* output, verified by executing both forms with sample values and diffing.
**Proposed by:** git-user (scope), agent (mechanism design)

### Decision 2: Real content drift found and reconciled with tool-neutral wording
**Chosen:** Diffing the two existing context-prose copies before treating either as canonical found genuine, intentional stage-017 drift: the JS version had been reworded ("PostToolUse hook"/"block" → "tool-execution hook"/"reject") to match opencode's actual throw-based mechanism. The canonical text now uses wording accurate for both: "this coding tool's own enforcement hook will actively stop every subsequent tool call ... from succeeding" / "a subsequent failed tool call."
**Rationale:** A single canonical source can't serve both targets faithfully while retaining either tool's own specific mechanism terminology; neutral wording covering both Claude Code's exit-code blocking and opencode's thrown-error rejection was needed regardless of which stage introduced the split.
**Proposed by:** agent (found during consolidation), confirmed via plan review

### Decision 3: No forced code-sharing for the JS mangling port
**Chosen:** `askfirst_state_dir()`'s bash form has one canonical source (`askfirst-state-dir.sh`), spliced into both `post_tool_use.sh` and `user_prompt_submit.sh` (closing a same-language duplication that had no justification). The JS port (`askfirstMangleTermPath()` in `askfirst-plugin.js`) stays a manually-maintained, separate translation, verified against a shared fixture (`askfirst-state-dir-fixture.txt`) consumed by both the R and JS test suites rather than a literal shared source.
**Rationale:** Bash and JS cannot execute the same function body; genuine cross-language codegen for a ~3-line utility was judged disproportionate machinery. A shared behavioral-contract fixture achieves the same verification goal (catching drift) without that machinery.
**Tradeoffs:** A real bug was caught while building the JS fixture test: the `/` → `""` edge case mangles to the shared tmp state-root itself, so recursively deleting it in test cleanup would have been destructive to shared test infrastructure — excluded from the JS fixture test (still covered safely by the R-side test, which has no filesystem side effects).
**Proposed by:** joint

### Decision 4: Merge tools/ into agent-hooks/
**Chosen:** `tools/install-agent-hooks.sh` and `tools/generate-install-hooks.sh` moved into `agent-hooks/` itself (`git mv`); the now-empty `tools/` directory was removed. Every literal path reference across the R package (roxygen docs, a human-directed nudge message, vignette code blocks, test assertions, `manifest.json`'s comment) was updated. The R package's `bindings/r/inst/install-agent-hooks.sh` symlink (pointing at the old `tools/` location) was removed entirely rather than repointed, since the installer now lives inside `agent-hooks/`, already covered by the existing whole-directory `bindings/r/inst/agent-hooks` symlink; `install_hooks.R`'s two `system.file()` calls were updated accordingly.
**Rationale:** `tools/` held exactly two files, both existing solely to support `agent-hooks/` content — no other purpose justified it as a separate top-level directory. The symlink simplification (two top-level `inst/` symlinks down to one) was a direct, welcome consequence, not a separate goal.
**Proposed by:** git-user
**Relates to:** Stage 007 (established `agent-hooks/` and the root-level-plus-symlink pattern `bindings/r/inst/` follows)

### Decision 5: Considered and rejected renaming "hooks" terminology
**Chosen:** Whether `agent-hooks/` (and the public R API's "hooks" naming — `askfirst_install_agent_hooks()`, `askfirst_hooks_status()`, `askfirst_hooks_manifest()`) should become something mechanism-neutral, given opencode's delivery format is called a "plugin" and future tools may use neither term, was raised and explicitly not pursued this stage.
**Rationale:** Both Claude Code's hooks and opencode's plugin are hook-shaped at what they actually implement (opencode's own SDK types the object every plugin returns as `Hooks`) — "hooks" isn't inaccurate for what exists today. "Plugin" describes only opencode's delivery format, not a different underlying mechanism. The blast radius of a rename (the whole public R API, not just a directory name) was judged large enough to warrant its own dedicated future stage, should a genuinely non-hook-shaped tool integration ever make the term stop fitting.
**Proposed by:** git-user

## Integration with Prior Work
Extends stage 012's dev-time generation pattern (`generate-install-hooks.sh` splicing canonical sources into the installer) one layer earlier. Reconciles a genuine content divergence introduced in stage 017 (the JS plugin's context wording). Extends stage 007's `agent-hooks/` root-level-plus-symlink pattern by folding `tools/` into it.

## Issues Resolved
- Three pieces of content hand-duplicated across bash and JS (and, for the mangling function, even within Claude Code's own two bash files) with no mechanism to catch drift — resolved via canonical sources and generation.
- A real, previously-undetected content divergence between the two context-prose copies (stage 017's intentional-but-unreconciled wording change) — found and fixed with tool-neutral phrasing.
- `tools/` as a separate top-level directory with no purpose beyond serving `agent-hooks/` — merged; a redundant `bindings/r/inst/` symlink removed as a direct consequence.
- A real bug in the generator itself (`[[ ]] && chmod` tripping `set -e` on a false condition, aborting the script mid-run) — found during first-run verification and fixed.

## Deferred Items
- Renaming `agent-hooks/`/the "hooks" API terminology to something mechanism-neutral — explicitly considered and deferred to a possible future stage, not rejected outright.
- Genuine cross-language code generation for the JS mangling port — deferred in favor of a shared behavioral-contract fixture, judged disproportionate for a ~3-line utility.

## Process Notes
- This stage's scope grew twice during planning, both at the user's initiative: first to include the `tools/`→`agent-hooks/` directory merge ("while we're at it"), then to weigh (and ultimately decline) a broader naming reconsideration. Both were incorporated into the same plan rather than deferred, since the merge in particular touched the same files the text-consolidation work was already touching.
- Implementation surfaced two genuine bugs beyond the planned scope: real (not accidental) content drift in the context prose between the two existing copies, and a `set -e`-vs-`[[ ]] && chmod` bug in the generator script that aborted mid-run on first execution. Both were found, diagnosed, and fixed as part of implementation rather than deferred.
- Several R test files (`file.path(dir, "tools", "install-agent-hooks.sh")`-style calls, as opposed to literal joined-string paths) needed a second, broader repo-wide sweep beyond the initial targeted grep to catch every reference to the moved installer — a plain string search for the old literal path missed calls using separate path components.
