---
created: 2026-07-28T09:42:32Z
agent: claude-sonnet-5
git_hash: 8906541ebc8774d06b7e1595d13c128532bbb2a7
---

# Plan: recover-swallowed-stderr-signals

## Overview
Recover askfirst signals from tools that discard, bury, or filter them out before an agent ever acts on them. Originally scoped around `Rscript ... 2>/dev/null` swallowing stderr entirely; expanded mid-planning, after a second field report, to also cover signals that reach the agent's output stream but get lost to scrolling/habituation, get stripped by the agent's own content-based filtering, or fire too many tool calls before the agent acts on them. Combines: stdout duplication for stop-and-ask signals, a persistent per-package sentinel with active PostToolUse blocking (not just a passive log), a reworked prefix/delimiter format that's faster to pattern-match, and an opt-in notice-silencing mechanism so agents never need to `grep` askfirst output away themselves.

## Context
Every askfirst signal is delivered through R's condition system — `rlang::inform()` (via `message()`) for `notice`/`error_redirect`, and R's default uncaught-error printer for the halting `rlang::abort()` calls behind `capability_gap`/`scenario_check`. Both paths write to stderr, never stdout. A calling tool that invokes `Rscript some_script.R 2>/dev/null` silently discards every askfirst signal with nothing recoverable — not a garbled message (which stage 014 addressed), but no message at all. Stage 014 made `stop-and-ask` message *text* self-sufficient assuming it reaches the agent's context at all; this stage addresses the delivery layer beneath that assumption.

A second field report (`askfirst-advice.md`, rewritten) described a related but distinct failure from a live session: signals *were* present in the output the agent read, but (a) the agent was instructed to run `grep -v "askfirst|notice|directive|..."` to filter noise from repeated `Rscript -e` calls, and complied, stripping its own stop signal along with the noise; (b) the stop-and-ask block's marker lines appear *before* the `askfirst::` prefix, so a tool consuming stdout incrementally may summarize before the bounding markers register; (c) `notice` and `stop-and-ask` look nearly identical for their first ~15 lines, so repeated exposure habituates the agent to skip past both; (d) the stop signal fired several tool calls before the agent actually started implementing a workaround, and there was no mechanism to retroactively re-surface it at the moment it mattered.

The report's literal suggestion to "move signals to stderr instead of stdout" is based on a mistaken premise — signals are already stderr-only by default — most likely because the reporter's tooling merged or uniformly captured both streams, or the agent's own `2>&1 | grep` piping merged them before filtering. Reconciling both reports: stderr being *discarded* (`2>/dev/null`) and stderr being *merged-then-filtered* are different failure modes that both end with the signal never reaching the agent, so a robust fix needs a channel that survives both — which points toward the same conclusion this stage already reached (stdout duplication for high-severity signals) plus something *outside* any single output stream entirely (a persistent, hook-enforced sentinel), which the report's "sticky flag" and "tool-level enforcement" suggestions also independently arrive at.

Discussed with the user: reopen stage 014's prefix/delimiter format within this stage (rather than deferring to yet another stage), and upgrade the log-file idea from a passive one-shot annotation to a persistent, actively-blocking sentinel — confirmed via Claude Code's hooks reference that PostToolUse hooks can force a blocking error state (exit code 2, stderr becomes the reason sent to the model; or JSON `"decision": "block"` with a `reason` field), not just append passive text, and that a `UserPromptSubmit` hook exists as a natural point to clear a sentinel once the user has had a chance to respond.

## Design Goals

### Delivery redundancy (original scope, unchanged in substance)
- Every `directive: stop-and-ask` signal writes its fully-rendered message to stdout, in addition to the existing stderr condition-system delivery, unconditionally.
- `askfirst_notice` is not duplicated to stdout — too frequent, not itself a halting signal.
- No change to *which* situations halt or to session-confidence gating (stage 010).

### Format rework (reopens stage 014)
- Fold directive severity into the structured prefix's last segment (`askfirst::{lang}::{pkg}::{directive}`, i.e. `stop-and-ask` or `notice`, as the literal first line) so a simple prefix-anchored regex catches severity immediately, without needing to read to a separate `directive:` line first. The finer-grained signal class (`notice`/`error_redirect`/`capability_gap`/`scenario_check`) moves to a new `type:` line immediately after (replacing the old `directive:` line's position) — no information is lost, it's reordered by how urgently each piece is needed.
- Replace the hard-stop shape's prose delimiter *lines* with a compact, maximally pattern-matchable token pair (`<<<ASKFIRST:HALT>>>` / `<<<ASKFIRST:RESUME>>>`), while keeping the actual imperative consequence sentence between them — that sentence's exact wording was deliberately reviewed and confirmed in stage 014 and isn't being reopened, only the bounding markers around it.
- `askfirst_notice_prime()`'s reference to the old delimiter text is updated to reference the new token.

### Persistent sentinel + active blocking (upgrades the original passive log-and-clear idea)
- A `directive: stop-and-ask` signal, in addition to stdout duplication, writes a persistent per-package sentinel under `.askfirst/pending/` that is *not* cleared by the next tool call.
- `post_tool_use.sh` checks for any pending sentinel on *every* subsequent tool call (not just the triggering one) and, if any exist, returns a blocking response (exit code 2, full pending message(s) as the reason) so the agent cannot proceed on *any* topic without being re-confronted with the unresolved stop-and-ask — directly addressing the "delayed consequence" failure mode, where the signal fired several calls before it mattered.
- A new `agent-hooks/*/user_prompt_submit.sh` hook clears `.askfirst/pending/` at the start of each new user turn, on the theory that a new user message means the user has had the chance to respond/redirect — the natural boundary for "the human has been asked," since askfirst has no way to detect an actual answer.
- `askfirst_notice` continues to use the original one-shot `.askfirst/log` (informational only, consumed and cleared passively) — this distinction (ephemeral log for notices, persistent blocking sentinel for stop-and-ask) is the core of "both, scoped differently."

### Opt-in silencing (new; directly answers the report's root complaint)
- An environment variable, e.g. `ASKFIRST_SILENCE_NOTICE` (comma-separated package names, or `all`), suppresses `notice`-level signals only, checked inside `askfirst_signal()`'s notice branch. `stop-and-ask` signals are never silenceable this way.
- Rationale: the field report's agent resorted to `grep -v askfirst...` specifically because there was no sanctioned way to reduce repeated-call notice noise — that ad hoc filtering is what stripped its own stop signal. A supported, explicit, notice-only suppression mechanism removes the reason to ever pipe askfirst output through a content filter at all.

### Test hygiene
- Any test exercising real signal emission at high confidence must sandbox its working directory (`withr::local_dir(withr::local_tempdir())`) to avoid writing `.askfirst/log`/`.askfirst/pending/` into the real repo, following stage 014's `askfirst_hooks_status()` test precedent.

## Proposed Approach

### 1. Reworked message assembly in `askfirst_signal()` (`bindings/r/R/conditions.R`)
- Prefix line becomes `askfirst::{lang}::{pkg}::{directive}`; a new `type:` line (using the existing `type` value) takes the old `directive:` line's position.
- `askfirst_stop_start_delimiter`/`askfirst_stop_end_delimiter` constants become `<<<ASKFIRST:HALT>>>` / `<<<ASKFIRST:RESUME>>>`; the imperative consequence text (`askfirst_stop_consequence()`) is unchanged in wording.
- `askfirst_notice_prime()` updated to reference `<<<ASKFIRST:HALT>>>` instead of the old prose delimiter text.
- After assembling `formatted`, for `stop-and-ask`-directive classes: write `formatted` to stdout (`cat(formatted, "\n\n", sep = "", file = stdout())`) and write a persistent sentinel entry to `.askfirst/pending/` (see below), both unconditionally, before the `rlang::abort()`/`rlang::inform()` call. For `notice`: append to the one-shot `.askfirst/log` only, gated on `ASKFIRST_SILENCE_NOTICE` not matching `pkg`.

### 2. Persistent sentinel storage
New internal module (e.g. `bindings/r/R/log.R`) with:
- `askfirst_log_notice(pkg, formatted)` — appends to `.askfirst/log`, as originally planned.
- `askfirst_write_pending(pkg, type, formatted)` — writes one file per pending stop under `.askfirst/pending/{pkg}-{type}.txt` (filename doubles as natural de-duplication: a repeat capability-gap from the same package overwrites its own pending file rather than accumulating duplicates).
- `askfirst_silence_notice_active(pkg)` — checks `Sys.getenv("ASKFIRST_SILENCE_NOTICE")` for `pkg` or `all`.

### 3. `post_tool_use.sh`: block on pending sentinels, still annotate the notice log
- Extract `.cwd` from the payload; check `"$cwd/.askfirst/pending/"` for any files. If any exist, concatenate them as the blocking reason and exit 2 (or emit the `decision: "block"` JSON form with that reason) — every subsequent tool call is blocked this way until cleared.
- Separately (non-blocking), still surface and clear `"$cwd/.askfirst/log"` as a passive annotation, as originally planned for notices.
- Apply identically to `agent-hooks/opencode/post_tool_use.sh`.

### 4. New `user_prompt_submit.sh` hook
- `agent-hooks/claude/user_prompt_submit.sh` (and opencode copy): on each new user turn, clears `"$cwd/.askfirst/pending/"`. `tools/install-agent-hooks.sh` gains a third hook type to install and register (`hooks.UserPromptSubmit` in `.claude/settings.json`, alongside the existing `SessionStart`/`PostToolUse` entries); `tools/generate-install-hooks.sh` extended to splice its content the same way as the other two.

### 5. Update `agent-hooks/*/session_start.sh`
Describe the new prefix format (severity-first, `type:` line), the new token pair, and the persistent-sentinel/active-blocking behavior, so the pre-loaded context stays accurate.

### 6. Regenerate and re-test
Run `tools/generate-install-hooks.sh`; update `test-install-agent-hooks.R` for the third hook file; update `test-init.R`/`test-capability-gap.R`/`test-scenarios.R` assertions for the new prefix/token literals; add new tests for `askfirst_write_pending()`, `ASKFIRST_SILENCE_NOTICE`, and the stdout-duplication behavior (all sandboxed per the test-hygiene goal).

## Open Questions
- Exact file-naming/format for `.askfirst/pending/` entries and the blocking-reason text assembled from possibly-multiple pending files — draft during implementation.
- Whether `decision: "block"` (JSON) or exit-code-2 (stderr-as-reason) is the more robust blocking mechanism across Claude Code and opencode, given only Claude Code's schema was verified directly — needs a quick check against opencode's own hook documentation before implementation, since opencode's blocking protocol may differ or may not support PostToolUse blocking at all.
- Whether `.askfirst/` should be added to a project's `.gitignore` automatically — still deferred, now with more reason (both `log` and `pending/` are pure runtime artifacts).
- Whether prefixing *every* line of a signal's body with a marker (not just bounding start/end tokens), as the field report also suggested, is worth the added complexity of post-processing `cli::format_inline()`'s reflowed output line-by-line — deferred; the start/end token pair is judged sufficient for now, revisit if a future report shows it still isn't.
- Whether `UserPromptSubmit`-triggered clearing is the right boundary at all, versus e.g. requiring an explicit acknowledgment action — chosen as the simplest mechanism available without needing a new exported "clear" function, but not battle-tested.
