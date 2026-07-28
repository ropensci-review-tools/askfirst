---
created: 2026-07-28T12:20:00Z
agent: claude-sonnet-5
git_hash: b07e93ec14bf083b339d05d93d2267ed81cf883a
---

# Design Decisions: Recover Swallowed Stderr Signals

## Summary
Reconciled two field reports of askfirst signals never reaching an agent — one where `2>/dev/null` discarded stderr outright, another where signals reached the agent's context but were buried, self-filtered, or acted on too late — into a single design combining stdout duplication, a persistent actively-blocking sentinel, a reworked severity-first message format, and an opt-in notice-silencing mechanism.

## New Design Decisions

### Decision 1: Stdout duplication scoped to `stop-and-ask` only
**Chosen:** `askfirst_signal()` writes the fully-rendered message to stdout, unconditionally, for every `stop-and-ask`-directive class, before signalling the condition on stderr. `notice` signals are never duplicated this way.
**Rationale:** A tool invoking `Rscript ... 2>/dev/null` discards stderr entirely, with nothing recoverable; `stop-and-ask` is rare and halting, so redundant delivery is cheap. `notice` fires on every load and would make stdout duplication unusably noisy.
**Tradeoffs:** Does not address `2>&1 | grep`-style merge-then-filter loss for notices — mitigated instead by Decision 4's opt-in silencing.
**Proposed by:** joint

### Decision 2: Persistent sentinel with active `PostToolUse` blocking, not a passive log
**Chosen:** `stop-and-ask` signals write a per-`{pkg}-{type}` file under `.askfirst/pending/`; `post_tool_use.sh` now blocks every subsequent tool call (Claude Code's exit-code-2/stderr-as-reason convention) while any pending file exists, cleared only by a new `user_prompt_submit.sh` hook firing on the next user turn. `notice` signals keep the original one-shot `.askfirst/log`, annotated non-blocking and cleared passively.
**Rationale:** Directly answers the field report's "delayed consequence" failure — a stop-and-ask fired several tool calls before it mattered, with no way to retroactively re-surface it. A new user message is the only available proxy for "the human has had the chance to respond," since askfirst cannot detect an actual answer.
**Tradeoffs:** Adds a third hook type across `agent-hooks/`, `tools/install-agent-hooks.sh`, and `tools/generate-install-hooks.sh`. opencode has no documented shell-hook config equivalent to Claude Code's `settings.json` hooks at all (its plugin API is a separate `tool.execute.before/after` interface with no documented blocking-result semantics) — the opencode copy uses the Claude Code convention as an explicitly-flagged, unverified fallback rather than blocking implementation on opencode's own docs catching up.
**Proposed by:** git-user
**Relates to:** Stage 014, Decision 3 (the `agent-hooks/manifest.json`/version-marker scheme this stage extends to a third hook file, bumping `hook_version` to 2)

### Decision 3: Severity-first prefix and compact halt/resume tokens
**Chosen:** The structured prefix becomes `askfirst::{lang}::{pkg}::{directive}` (directive — `stop-and-ask` or `notice` — as the last segment of the first line), with a new `type:` line carrying the finer-grained signal class immediately after. The prose delimiter lines from stage 014 (`----- ASKFIRST AGENT STOP ... -----` / `----- ASKFIRST AGENT: RESUME ... -----`) are replaced by `<<<ASKFIRST:HALT>>>` / `<<<ASKFIRST:RESUME>>>`.
**Rationale:** The field report found that `notice` and `stop-and-ask` look nearly identical for their first ~15 lines, causing habituation, and that a prefix-anchored regex needs severity on line one rather than several lines into a `directive:` field. Compact tokens pattern-match more reliably under repeated exposure than prose.
**Tradeoffs:** Reopens stage 014's delimiter text, but only the bounding tokens — `askfirst_stop_consequence()`'s imperative wording, reviewed and confirmed in stage 014, is left unchanged.
**Proposed by:** git-user
**Relates to:** Stage 014, Decision 1 (the hard-stop block this reformats without altering its imperative content)

### Decision 4: Opt-in `ASKFIRST_SILENCE_NOTICE`, replacing ad hoc filtering
**Chosen:** A comma-separated `ASKFIRST_SILENCE_NOTICE` environment variable (package names, or `all`) suppresses `notice`-level logging only, checked inside `askfirst_signal()`. `stop-and-ask` signals consult it never.
**Rationale:** The field report's agent resorted to `grep -v askfirst...` specifically because no sanctioned way existed to reduce repeated-notice noise — that filtering is what stripped its own stop-and-ask signal. A supported suppression path removes the reason to ever pipe askfirst output through a content filter.
**Proposed by:** joint

## Integration with Prior Work
Extends stage 014's self-sufficient message-text decision without reopening its imperative consequence wording — only the structural prefix and bounding tokens change. Extends stage 014's hook-installation manifest/version-marker scheme (Decision 3 there) to a third hook file. Does not alter stage 010's confidence gating or stage 012's directive-severity mapping.

## Issues Resolved
- `2>/dev/null` silently discarding every askfirst signal — resolved via unconditional stdout duplication for `stop-and-ask`.
- Signal fired several tool calls before it mattered, with no re-surfacing mechanism — resolved via the persistent `.askfirst/pending/` sentinel and active `PostToolUse` blocking.
- `notice`/`stop-and-ask` visually near-identical, and severity buried ~15 lines in — resolved via the severity-first prefix and compact tokens.
- No sanctioned way to reduce notice noise, prompting an agent to self-filter and strip its own stop signal — resolved via `ASKFIRST_SILENCE_NOTICE`.

## Deferred Items
- Prefixing every body line (not just bounding tokens) with a marker — deferred as unneeded complexity against `cli::format_inline()`'s reflowed output; revisit if a future report shows the token pair still isn't enough.
- Adding `.askfirst/` to a project's `.gitignore` automatically — deferred, though both `log` and `pending/` are now confirmed pure runtime artifacts.
- Verifying opencode's actual blocking-hook support once/if it becomes documented — the current opencode hook files carry an explicit comment flagging the convention as an unverified fallback.

## Process Notes
- The stdout-duplication and pending-sentinel side effects (Decisions 1–2) were gated on `askfirst_signal()`'s existing `prefix` argument, so `prefix = FALSE` test calls (used to check condition class/metadata only) don't write real files or print to stdout — an implementation-time decision not explicit in `plan.md`.
- `local_reset_askfirst_state()` (the shared test helper) was extended to sandbox the working directory into a fresh tempdir for every test that uses it, rather than adding per-test sandboxing calls, since `askfirst_signal()` now has real filesystem side effects at high confidence for both notice and stop-and-ask paths.
- Checking opencode's own hook/plugin documentation (an open question in `plan.md`) found no shell-hook config equivalent to Claude Code's `settings.json` hooks at all — resolved by falling back to the Claude Code convention with an explicit unverified-fallback comment, per the plan's own fallback framing, rather than treating the absence as a blocker.
