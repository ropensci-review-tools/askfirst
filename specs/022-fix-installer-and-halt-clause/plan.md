---
created: 2026-07-30T00:00:00Z
agent: claude-sonnet-5
git_hash: 4dea3684cd28feaab71355e7f2d4b9107ec86eed
---

# Plan: fix-installer-and-halt-clause

## Overview
Fix install-agent-hooks.sh so the Claude Code branch creates .claude/settings.json when absent instead of silently skipping hook registration (closing the silent-hooks-inert failure mode found in askfirst-advice.md), and revise the HALT directive's point 6 in agent-hooks/askfirst-context.txt to require presenting the upstream question first and labeling any mentioned workaround as unvetted/provisional, rather than requiring workarounds be omitted from the response entirely

## Context

**Source of this stage:** a field trial documented in `askfirst-advice.md`
(a controlled reconciliation of a no-hooks vs. a with-hooks-content-read
session) surfaced two separate, unrelated bugs/gaps in the current design:

1. **Installer silent-skip bug.** `agent-hooks/install-agent-hooks.sh`'s
   Claude Code branch (lines ~717-722) only registers hooks into
   `.claude/settings.json`'s `hooks` key if that file already exists;
   otherwise it writes `session_start.sh`/`post_tool_use.sh`/
   `user_prompt_submit.sh` to `.claude/hooks/` unconditionally, logs a
   single stderr line ("skip: ... not found"), and still `exit 0`s as a
   reported success. This produces fully-installed, version-tagged,
   completely inert hooks with no observable failure signal from inside
   an agent's own context. Confirmed still present at the same lines as
   of this stage's creation. The `opencode` branch has no equivalent gap
   — it has no registration step at all (plugin auto-discovery from
   `.opencode/plugins/`, per stage 017).

2. **HALT directive point 6 ("no workaround as a menu option") reliably
   gets overridden regardless of hook reinforcement.** This is the
   substantive finding, and it cuts against three prior stages' direction:
   - Stage 011 (`sharpen-workaround-guidance`) first hardened this rule
     after a field report of an agent offering a workaround as a co-equal
     menu option.
   - Stage 012 (`harden-ask-first-gate`) hardened it further, explicitly
     removing a "mark the workaround as recommended (but still an option)"
     framing after finding that framing still let the workaround appear
     as a selectable choice — precisely what the rule was meant to
     prevent.
   - Stage 014 (`self-sufficient-stop-signal`) hardened it a third time,
     embedding the rule as a fixed, imperative, hooks-independent block
     directly in `askfirst_signal()`'s own message text, so the directive
     doesn't depend on hook-taught interpretation at all.
   - This stage's own reconciliation test (`askfirst-advice.md`) then ran
     the *same* task with and without hook-content reinforcement of that
     rule. Reinforcement measurably fixed a different problem (the agent
     stopped treating the signal as a prompt injection, and was more
     transparent about quoting it verbatim to the user) but did **not**
     stop the agent from presenting a workaround as a selectable option in
     the same turn as the halt, in either condition. The doc's diagnosis:
     "don't tell your principal a workaround exists" is a fundamentally
     different, harder ask than "don't autonomously implement one" —
     it conflicts with a stronger transparency norm that authenticity
     reassurance doesn't touch.

   This stage is therefore the first to *loosen* rather than tighten this
   specific clause — done deliberately, not as a reversal of stages
   011/012/014's intent. The specific menu-option pattern those stages
   fixed (a workaround appearing as a selectable, co-equal, or
   "recommended" choice alongside asking the user) remains explicitly
   forbidden; what changes is that a workaround may now be mentioned at
   all, as a clearly subordinate, explicitly-labeled aside, after the
   upstream question has been surfaced first.

**Canonical source locations — the clause is duplicated across two
independent mechanisms, both need the same wording change:**

1. `agent-hooks/askfirst-context.txt` — the single hand-edited source for
   the `<askfirst-context>` block's point 6 (hook-context reinforcement,
   read by a coding-agent tool that has hooks installed and registered).
   `agent-hooks/generate-install-hooks.sh` splices it into
   `agent-hooks/claude/session_start.sh` and
   `agent-hooks/opencode/askfirst-plugin.js`, which in turn get spliced
   into `install-agent-hooks.sh`'s embedded heredocs. Edits belong only in
   `askfirst-context.txt`, followed by regenerating the rest.
2. `agent-content/askfirst-stop-consequence.txt` and
   `agent-content/askfirst-notice-prime.txt` — the *hook-independent*
   copy. Stage 014 embedded this rule directly in `askfirst_signal()`'s
   own message text (read at runtime via `askfirst_read_content()` in
   `bindings/r/R/conditions.R`) specifically so the directive doesn't
   depend on hooks being installed, registered, or read at all. This is
   the more load-bearing of the two copies and must not be missed —
   fixing only `askfirst-context.txt` would leave the self-sufficient
   stop signal carrying the old, unrevised wording.

Both copies currently read, in substance: "do not implement, draft, or
offer a workaround as an option, recommended or otherwise, until the user
has [asked upstream] and you have their answer" (stop-consequence text)
and "direct the user to ask the developers ... before writing a
workaround, and do not offer one as an option in that turn" (notice-prime
text). Both need the revised wording from Design Goals applied
consistently. No existing test asserts on this literal prose (checked
`bindings/r/tests/testthat/*.R` — only the `<<<ASKFIRST:HALT>>>` delimiter
itself is asserted on), so this is a content-only change with no expected
test breakage, though new tests should be added per step 3 below.

## Design Goals
- Close the installer's silent-skip gap: when `.claude/settings.json` is
  absent, the Claude Code branch creates it (e.g. `echo '{}' >
  "$TARGET_CONFIG"`) and then registers hooks unconditionally, removing
  the silent-skip branch and its `exit 0`-as-success behavior entirely.
  The only remaining early-exit case is `jq` missing, already handled a
  few lines earlier with a loud warning.
- Revise point 6 in `agent-hooks/askfirst-context.txt` **and** the
  equivalent clauses in `agent-content/askfirst-stop-consequence.txt` and
  `agent-content/askfirst-notice-prime.txt` so that, on a `stop-and-ask`
  signal: (a) surfacing the upstream question to the user and waiting for
  their answer remains the required first and primary action, stated up
  front rather than buried after other content; (b) a workaround may be
  separately noted as existing, but only as a clearly subordinate,
  explicitly-labeled aside (e.g. "unvetted"/"provisional") — never as a
  selectable menu option, recommended or otherwise, co-equal with asking
  the user. The specific pattern stages 011/012 fixed (menu framing, even
  with a "recommended" label) stays forbidden, in all three files.
- Regenerate all downstream copies (`agent-hooks/claude/session_start.sh`,
  `agent-hooks/opencode/askfirst-plugin.js`, and the embedded heredocs in
  `install-agent-hooks.sh`) via `generate-install-hooks.sh` so no copy
  drifts from the canonical source.
- Keep the two fixes (installer bug vs. wording change) independently
  reviewable even though they land in one stage, since they have
  unrelated root causes and risk profiles.

## Proposed Approach
1. **Installer fix.** In `install-agent-hooks.sh`'s `claude)` case, replace
   the `if [[ -f "$TARGET_CONFIG" ]]; then register_hooks_claude; ...
   else ... skip ...; fi` block with an unconditional
   `[[ -f "$TARGET_CONFIG" ]] || echo '{}' > "$TARGET_CONFIG"` followed by
   an unconditional `register_hooks_claude` call and a single "register:
   ... (hooks added)" log line. No new flags or config needed;
   `register_hooks_claude` already tolerates a config file with no
   existing `.hooks` key (its `jq -e '.hooks.SessionStart // empty'`
   branch).
2. **Wording fix, hook-context copy.** Edit point 6 in
   `agent-hooks/askfirst-context.txt` per the Design Goals wording above.
   Run `generate-install-hooks.sh` to propagate the change into
   `agent-hooks/claude/session_start.sh`,
   `agent-hooks/opencode/askfirst-plugin.js`, and
   `install-agent-hooks.sh`'s embedded heredocs, and verify the sync
   check (`check-agent-content-sync.R` / equivalent) passes.
3. **Wording fix, hook-independent copy.** Edit
   `agent-content/askfirst-stop-consequence.txt` and
   `agent-content/askfirst-notice-prime.txt` to match, keeping both
   consistent with the hook-context wording in substance (they are
   shorter, inline forms, not required to be byte-identical). Run
   `bindings/r/data-raw/sync-agent-content.R` /
   `check-agent-content-sync.R` to keep `bindings/r/inst/agent-content/`
   in sync.
4. **Tests.** Add a test asserting the installer creates
   `.claude/settings.json` when absent and registers hooks into it (no
   more silent-skip path). Add/update tests in
   `bindings/r/tests/testthat/test-capability-gap.R` and `test-log.R`
   asserting the revised stop-consequence/notice-prime wording appears
   (e.g. an "unvetted"/subordinate-aside marker is present, and no
   "recommended... option" menu framing is reintroduced) rather than only
   checking the `<<<ASKFIRST:HALT>>>` delimiter as today.

## Open Questions
- Should the revised point 6 wording give a concrete example phrase for
  the "subordinate, labeled aside" (as drafted above), or leave the exact
  phrasing to the agent's judgment as long as it isn't menu-shaped? Draft
  above includes an example; can be adjusted during implementation.
- Are there other coding-agent-tool integrations beyond Claude Code and
  opencode (current or planned) that would need the same installer-style
  settings-file-creation fix, or is Claude Code the only one with a
  fixed, predictable config path today?
