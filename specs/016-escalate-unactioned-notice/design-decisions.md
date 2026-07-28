---
created: 2026-07-28T14:14:35Z
agent: claude-sonnet-5
git_hash: 8b47d990537d5e607601a4827065ef1e61e85e89
---

# Design Decisions: Escalate Unactioned Notice

## Summary
Closed a field-diagnosed reachability gap — the hard `stop-and-ask` gate was only reachable if an agent voluntarily called `askfirst_check_scenarios()` — with a non-blocking `PostToolUse` escalation, and relocated all askfirst runtime state out of the project's working tree into a session-scoped tmp location.

## New Design Decisions

### Decision 1: Non-blocking, untargeted PostToolUse escalation
**Chosen:** Once a `notice` fires for a package without a following `askfirst_check_scenarios()` call, every subsequent file-modifying tool call (`Edit`/`Write`/`NotebookEdit`) carries a reminder appended to the tool result — escalating from a single-line nudge to a firmer "REPEATED" wording after 3 occurrences — until the check is called or the session ends. The trigger is deliberately untargeted: it fires on any such call, not scoped to files that reference the flagged package.
**Rationale:** A field trial (`askfirst-tests/trials/trial-opencode-withhooks-problem1-1`) showed a `notice` firing twice while an agent implemented exactly the kind of workaround the mechanism exists to catch, without the agent ever calling the self-check that would have raised the real gate. The package itself cannot detect this mechanically (the workaround code typically never touches the package's namespace), so detection was moved to the coding-tool hook layer, which does see the agent's subsequent file edits.
**Tradeoffs:** Non-blocking by explicit choice — false positives cost only an extra line of text, but the mechanism still depends on the agent reading and acting on the reminder rather than being forced to.
**Proposed by:** git-user
**Relates to:** Stage 004 (introduced `askfirst_check_scenarios()` as agent-invoked); stages 011/012 (hardened it once reached, but not its reachability)

### Decision 2: Relocate all runtime state to a session-scoped tmp root
**Chosen:** `log`, `pending/`, and the new `unresolved-notice/` marker all move from `<project>/.askfirst/...` to `${TMPDIR:-/tmp}/askfirst/<mangled-abs-project-path>/...`, with the mangled path (leading `/` stripped, remaining `/` replaced with `_`) computed independently by the R process (from `getwd()`) and by each hook script (from the payload's `cwd` field) — the one value both already share, with no new coordination introduced. The mangling is a literal transform, not a hash, prioritizing human debuggability over hiding the path from other users on a shared multi-user `/tmp`.
**Rationale:** Adding a third marker family alongside stage 015's `log`/`pending/` — both already sitting ungitignored in the project tree, per that stage's own deferred `.gitignore` item — would have compounded rather than fixed the gap. All three are session-scoped and meaningless past the current session, so none belong in a git-tracked directory at all.
**Tradeoffs:** No active pruning of leftover empty tmp directories was added; relies on the OS's normal tmp reaping. R's own `tempdir()` could not be used, since it is randomized per R session and undiscoverable by the separate hook process.
**Proposed by:** joint
**Relates to:** Stage 015 (the `log`/`pending/` mechanism relocated here)

### Decision 3: Broaden the Claude Code PostToolUse matcher
**Chosen:** `tools/install-agent-hooks.sh`'s registered matcher for Claude Code's `PostToolUse` hook changed from `Bash|R|Rscript` to also include `Edit|Write|NotebookEdit`.
**Rationale:** Without it, the hook script is never invoked at all for file-edit tool calls, which this stage's escalation depends on. This also retroactively closes a latent gap in stage 015: its one-shot `log` notice was meant to flush "on the next tool call," but the narrower matcher silently skipped that flush whenever the next call was an edit rather than a Bash/R/Rscript call.
**Tradeoffs:** None identified; purely additive.
**Proposed by:** agent

### Decision 4: Document, not rebuild, the opencode plugin-API mismatch
**Chosen:** Investigating opencode's real plugin SDK (`@opencode-ai/plugin`) found its `Hooks` interface is a JS/TS object registered via `opencode.json`'s `plugin` array and executed in-process — not a shell-script/stdin-JSON convention. The existing `agent-hooks/opencode/*.sh` scripts (all three, since stages 014/015) are very likely never invoked by real opencode at all, a stronger finding than stage 015's "unverified fallback" label. Decision: relocate and extend these scripts identically to the Claude Code side anyway (for consistency and in case an undocumented path exists), document the concrete finding precisely in both copies' headers, and do not attempt a real JS/TS plugin in this stage.
**Rationale:** Matches stage 015's own precedent of shipping an explicitly-flagged, unverified mechanism rather than blocking this stage on a substantially larger, separate undertaking (a real opencode plugin).
**Tradeoffs:** opencode support for this entire mechanism family remains unverified in practice; flagged as the top candidate for a future stage.
**Proposed by:** git-user
**Relates to:** Stage 015 (opencode blocking-convention caveat, extended here to the new escalation feature)

## Integration with Prior Work
Extends stage 004's agent-invoked scenario-check mechanism and stages 011/012's hardening of it once reached, by addressing reachability itself for the first time. Relocates stage 015's `log`/`pending/` state mechanism without changing its clearing semantics (log: one-shot on next tool call; pending: cleared only on next user turn). Extends stage 014/015's `agent-hooks/manifest.json` hook-version scheme to version 3.

## Issues Resolved
- The hard stop-and-ask gate's sole reachability path (an agent's own voluntary `askfirst_check_scenarios()` call) had no fallback if skipped — resolved via the new PostToolUse escalation.
- `.askfirst/log`/`pending/` sitting ungitignored in the project tree (deferred in stage 015) — resolved by relocating all state out of the project tree entirely, obsoleting the `.gitignore` question rather than answering it.
- Claude Code's `PostToolUse` matcher silently excluding Edit/Write calls — fixed, closing a latent gap in stage 015's own log-flush guarantee.

## Deferred Items
- A real JS/TS opencode plugin implementing this mechanism's `SessionStart`/`PostToolUse`/`UserPromptSubmit` equivalents — flagged as the highest-priority candidate for a future stage; not attempted here.
- Active pruning of leftover empty tmp directories under the new state root — deferred in favor of relying on normal OS tmp reaping.
- Re-running the `askfirst-tests` harness's `opencode × with-hooks × problem1` trial cell to confirm this stage's fix closes the originally diagnosed gap — lives in that sibling repo's own workflow, not this stage.

## Process Notes
- Mid-design, reviewing the new marker's storage location surfaced that stage 015's `log`/`pending/` files were already sitting ungitignored in the project tree; the storage-location redesign (Decision 2) was a direct consequence of that review, not part of the original stage scope.
- One task (reconciling this repo's own local dev hook installation) was found to rest on a wrong premise during implementation: this repo's `.claude/hooks/` belong to an unrelated tool (the workflow driving this project's own design-stage tooling), not to any prior askfirst dev-hook install. The task was skipped rather than forced, to avoid overwriting unrelated, actively-used hooks.
- Implementation surfaced one genuine R CMD check regression (a "detritus in the temp directory" NOTE caused by test cleanup leaving an empty parent directory under the new tmp root) and one stale test fixture (a hardcoded hook-version-2 fixture predating this stage's version bump) — both fixed before considering the stage complete.
