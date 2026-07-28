---
created: 2026-07-28T13:28:19Z
agent: claude-sonnet-5
git_hash: 1c0f92128de0efe81c2d4217b0cb7261e3ea1916
---

# Plan: escalate-unactioned-notice

## Overview
Close the opt-in escalation gap found in askfirst-tests trial-opencode-withhooks-problem1-1: the hard stop-and-ask gate is only reachable if the agent voluntarily calls askfirst_check_scenarios(), so a notice can fire and the agent can go on to write a workaround without ever hitting the gate. Add a non-blocking PostToolUse escalation: once a notice fires for a package without a following askfirst_check_scenarios() call for that package, every subsequent file-modifying tool call (Edit/Write, untargeted -- any such call, not scoped to files referencing the package) gets a strengthened reminder appended to the tool result, repeating on every such call until the check is called or the session ends. This stage also relocates all of askfirst's runtime state -- the existing `log`/`pending/` files from stage 015, and this stage's new marker -- out of the project's own working tree into a session-scoped location under a fixed tmp root, since none of these files have meaning beyond the current coding-agent session and none belong in a project's git-tracked directory.

## Context

This stage responds directly to a field finding from the `askfirst-tests`
harness (a sibling repo, `../askfirst-tests`, purpose-built to run real
agent sessions against `askfirst`-instrumented `dodgr` and grade whether
they respect a stop-and-ask signal): `trials/trial-opencode-withhooks-problem1-1/diagnosis.md`.
In that trial, dodgr's load-time `notice` fired twice while the agent
(opencode, `deepseek-v4-flash-free`) was actively researching the exact
kind of change the notice warns about, but the agent never called
`askfirst::askfirst_check_scenarios("dodgr")` -- the one action that
raises the real `stop-and-ask`/`scenario_check` condition -- and went on
to edit the target script directly with no mention of askfirst anywhere
in its visible reasoning. A parallel claude trial on the same problem
avoided this only because Sonnet happened to take the voluntary step the
hook context suggests ("If you see `askfirst_check_scenarios()`
mentioned, consider calling it"). The diagnosis and
`askfirst-tests/recommendations.md` both name this as the single highest-
severity finding of that (n=1, not yet settled) run: the hardest gate in
the whole mechanism has, in the worst case, no floor at all, since nothing
forces the escalation from passive notice to hard stop.

Relevant prior decisions this stage builds on and must not contradict:

- **Stage 002 (design-agnostic-spec), T002-5**: established that no
  mechanical/heuristic way was found for a package to detect, from inside
  its own call stack, that a caller is about to write workaround code --
  every candidate risks false positives or requires reimplementing domain
  knowledge only the package author has. This is *why*
  `askfirst_check_scenarios()` exists as a separate, agent-initiated
  self-check rather than something dodgr's own instrumented functions
  could trigger automatically -- and why this stage does not attempt to
  add R-side semantic detection. It instead targets a different layer
  (the coding-tool hook, which sees the agent's actual file edits) that
  T002-5's reasoning never ruled out, because that reasoning was scoped to
  what a package can detect about its own callers, not what a coding
  tool's own hook can observe about the agent's subsequent actions.
- **Stage 004 (scenario-check)**: introduced `askfirst_check_scenarios()`
  itself as the self-check mechanism for gaps the author hasn't
  anticipated precisely enough to instrument inline.
- **Stages 011/012**: hardened `askfirst_check_scenarios()` from
  advisory-only to a real halting (`call_stop = TRUE`) gate once reached,
  and fixed "recommended-but-still-an-option" framing. Neither stage
  addressed *reachability* of the gate -- both presuppose the agent
  already called the function.
- **Stage 014 (self-sufficient-stop-signal)**: made the `stop-and-ask`
  message shape self-sufficient in message text alone (hard-stop
  delimiters, imperative consequence text), independent of hook context
  being loaded at all. Also established the `agent-hooks/manifest.json`
  hook-version marker scheme this stage's hook changes extend.
- **Stage 015 (recover-swallowed-stderr-signals)**, most directly
  relevant: built the exact state-tracking primitives this stage extends
  --  `.askfirst/log` (one-shot, non-blocking, written by
  `askfirst_log_notice()`, flushed and deleted by `post_tool_use.sh` after
  the very next tool call) and `.askfirst/pending/` (persistent, blocking,
  written by `askfirst_write_pending()`, actively blocks every subsequent
  tool call via `post_tool_use.sh` exit-code-2 until a new user turn
  clears it via `user_prompt_submit.sh`). This stage introduces a *third*
  state category, structurally distinct from both: unlike `.askfirst/log`
  it must survive more than one tool call (a single flush-and-forget
  reminder is exactly the mechanism that already failed in the diagnosed
  trial); unlike `.askfirst/pending/` it must never block, and must not be
  cleared by a new user turn, since it isn't waiting on a human answer --
  it's waiting on the agent's own voluntary self-check. Stage 015 also
  left the opencode `post_tool_use.sh` blocking convention flagged as an
  explicitly *unverified* fallback (opencode's plugin API is a
  `tool.execute.before/after` interface with no documented blocking-result
  semantics); this stage's own opencode-side change is non-blocking output
  injection, a different and separately-unverified mechanism, not covered
  by stage 015's caveat one way or the other.

Out of scope for this stage: the diagnosis also raised a second, entangled
finding -- whether opencode's `SessionStart` hook context reached the
model at all in that trial (no discrete hook-injection event was visible
in `opencode run --format json` output, unlike Claude Code's
`hook_response` event). That is a harness-verification question living in
`askfirst-tests` (its own `recommendations.md` already flags it as the
harness's own next fix, via a hook-canary), not an askfirst mechanism
change, and is not addressed here.

**Addendum, decided mid-planning: state storage location.** Reviewing this
stage's own new marker surfaced that `.askfirst/log` and `.askfirst/pending/`
(stage 015) already sit directly in the project's working tree with no
`.gitignore` entry anywhere in this repo -- stage 015's own
`design-decisions.md` explicitly deferred adding one ("Deferred Items":
"Adding `.askfirst/` to a project's `.gitignore` automatically -- deferred,
though both `log` and `pending/` are now confirmed pure runtime
artifacts"). Adding a third marker family to that same, still-ungitignored
location would have compounded rather than fixed that gap. The resolution
agreed during this stage's planning is more thorough than finishing the
deferred `.gitignore` item: since all three state categories are
inherently session-scoped and meaningless once the coding-agent session
ends, they should never be written under the project tree at all -- this
obsoletes the `.gitignore` question entirely rather than answering it, and
this stage's scope now includes relocating stage 015's existing `log`/
`pending/` mechanism alongside adding the new marker, not just adding the
new marker in isolation.

The one complication: the R process (writing) and each hook script
(reading, in a separate process spawned by the coding tool) share no
coordination channel except the project's own working directory -- R's
`getwd()` and the hook payload's `cwd` field. R's own `tempdir()` cannot be
used for this, since it is randomized per R session and has no way to be
discovered by the separate bash hook process. The design instead derives a
stable, deterministic path under a fixed tmp root from that shared
working-directory value, computed independently (no new coordination
needed) by both sides -- see Proposed Approach.

## Design Goals

1. **Remove the silent-bypass floor.** Ensure the escalation from a
   passive `notice` to a real stop-and-ask gate does not depend entirely
   on the agent spontaneously deciding to call
   `askfirst_check_scenarios()` -- an agent that never makes that
   voluntary call today gets no reinforcement at all beyond the one-shot,
   already-proven-insufficient `.askfirst/log` flush.
2. **Detect at the layer that actually has visibility.** Do not attempt
   R/package-side semantic detection of "this edit is a workaround" --
   T002-5 already found no false-positive-free way to do that from inside
   a package's own call stack. Instead, use the coding-tool hook's own
   visibility into the agent's subsequent tool calls (specifically,
   file-modifying calls), which is a different vantage point T002-5's
   finding does not cover.
3. **Stay strictly non-blocking**, per the maintainer's explicit choice
   for this stage: escalate through progressively firmer reminder text
   injected into the (non-blocking) `PostToolUse` annotation channel, on
   every file-modifying tool call following an unresolved notice, until
   `askfirst_check_scenarios(pkg)` is called or the session ends. No new
   blocking gate is introduced by this stage -- false positives (a
   reminder firing on an edit unrelated to the flagged package, since the
   trigger is deliberately untargeted per the maintainer's second choice
   below) must cost nothing more than an extra line of text.
4. **Untargeted trigger, deliberately.** Fire on *any* file-modifying tool
   call (Edit/Write) after an unresolved notice, not scoped to files that
   reference the flagged package's name -- the maintainer's explicit
   choice, trading recall for simplicity and avoiding a second heuristic
   (content-scanning a diff/file for a package name) that could itself
   misfire on indirect/aliased usage.
5. **Reuse stage 015's conventions rather than inventing a fourth
   mechanism**: same three-way state-category split (one-shot non-blocking
   log, blocking pending sentinel, and now this stage's persistent
   non-blocking marker), same `agent-hooks/manifest.json` hook-version bump
   pattern used by stages 014/015, same per-agent (`claude/`, `opencode/`)
   hook file layout.
6. **Verify for both agents independently**, not just Claude Code -- the
   diagnosed failure happened on opencode specifically, and stage 015
   already found opencode's hook/plugin mechanism is structurally
   different (and less documented) than Claude Code's. This stage's
   change must be checked against opencode's actual `PostToolUse`-
   equivalent behavior rather than assumed to work identically once the
   Claude Code side is verified.
7. **Move all askfirst runtime state out of the project's working tree**,
   into a session-scoped location under a fixed tmp root -- covers this
   stage's new marker and, since the same reasoning applies equally,
   migrates stage 015's existing `log`/`pending/` files too. None of these
   three state categories have meaning beyond the current coding-agent
   session; none should ever be visible in `git status` or risk being
   committed. This fully supersedes stage 015's deferred `.gitignore` item
   rather than completing it.

## Proposed Approach

- **State storage location, relocated out of the project tree.** All three
  state categories (`log`, `pending/`, and this stage's new marker) move
  from `<project>/.askfirst/...` to a session-scoped path under a fixed
  tmp root: `${TMPDIR:-/tmp}/askfirst/<mangled-abs-project-path>/...`. The
  mangled path is computed identically, independently, on both sides --
  by R from `getwd()`, and by each hook script from the payload's `cwd`
  field -- since project working directory is the only value both
  processes already share, with no new coordination mechanism introduced.
  Mangling scheme (maintainer's explicit choice): the literal absolute
  path with its leading `/` stripped and remaining `/` replaced by `_`
  (e.g. `/home/user/dodgr` -> `home_user_dodgr`) -- not a hash, trading a
  minor information leak (the project's absolute path is visible as a
  directory name to other users on a shared multi-user `/tmp`; no file
  *contents* are exposed) for direct human debuggability (a maintainer can
  `ls` their way to the right directory from the project path alone,
  without running any hash function by hand). No new active pruning is
  added in this stage: the existing per-entry clearing points (log flushed
  on next tool call, pending cleared on next user turn, new marker cleared
  on scenario-check/stop-and-ask) already remove the content each
  mechanism cares about; leftover empty directory trees under the tmp root
  are left for the OS's own normal tmp reaping (most systems already clear
  `/tmp` on reboot or via `tmpwatch`/`systemd-tmpfiles`) rather than this
  stage building its own pruning logic.
- **New per-package marker**, distinct from the (also relocated) `log`
  and `pending/` files: written under
  `<state-root>/unresolved-notice/<pkg>.txt` (exact subpath naming to be
  finalized during implementation for consistency with the relocated
  `log`/`pending/` naming), created by `askfirst_signal()`'s existing
  notice branch (alongside, not instead of, the current
  `askfirst_log_notice()` call) whenever a `notice`-directive signal fires
  for `pkg` and no scenario-check has already resolved it this session.
- **Cleared** when: (a) `askfirst_check_scenarios(pkg)` is called, at
  *any* confidence tier -- including human/low confidence, since a human
  deliberately calling it also represents the self-check having happened;
  (b) a `stop-and-ask` condition of any type subsequently fires for `pkg`
  (superseded by the real gate firing); (c) implicitly, at session end
  (ephemeral, like `pending/`). **Not** cleared by a new user turn --
  unlike `pending/`, this marker isn't waiting on a human's answer, it's
  waiting on the agent's own voluntary self-check, so
  `user_prompt_submit.sh` must leave it untouched.
- **`post_tool_use.sh` (both `claude/` and `opencode/` copies)**: in
  addition to the existing pending-block and log-flush logic (now reading
  from the relocated tmp-root paths instead of `$cwd/.askfirst/...`),
  check for any file under the new marker directory; if present *and* the
  current tool call is a file-modifying one, append a reminder to the
  existing non-blocking annotation output naming the still-open
  package(s) and restating the instruction to call
  `askfirst::askfirst_check_scenarios('pkg')` before proceeding if the
  edit duplicates/extends that package's functionality. Reminder wording
  escalates in firmness on repeat occurrences (implementation detail --
  see Open Questions) rather than repeating identical text indefinitely,
  on the theory that identical repeated text is exactly the kind of
  signal an agent habituates to and stops reading, per stage 015's own
  rationale for its severity-first prefix change.
- **Tool-call-type detection**: identify file-modifying calls from each
  agent's own `PostToolUse` payload shape (Claude Code: `tool_name` field,
  e.g. `Edit`/`Write`/`NotebookEdit`; opencode's equivalent field/values
  need confirming against its actual plugin payload during
  implementation, not assumed to mirror Claude Code's).
- **Hook-version bump**: `agent-hooks/manifest.json`'s `hook_version`
  marker increments again (stage 015 brought it to 2), per the same
  convention stages 014/015 used, so `tools/install-agent-hooks.sh` and
  `askfirst_hooks_status()` can detect stale installs missing this
  stage's change.
- **R-side changes**: a shared helper computes the tmp state root from
  `getwd()` (single source of truth, used by the relocated
  `askfirst_write_pending()`/`askfirst_log_notice()` and the new marker
  functions alike); `askfirst_signal()`'s notice branch gains the new
  marker-write call; `askfirst_check_scenarios()` gains a marker-clear
  call reached regardless of confidence tier (mirrors how
  `askfirst_write_pending()`/`askfirst_log_notice()` are already called
  unconditionally of confidence within their respective call sites).

## Open Questions

- **Exact reminder wording and escalation levels** (e.g. a level-1 vs.
  level-2 reminder after N repeat occurrences) -- not decided in this
  planning conversation; draft during implementation and review before
  merge, consistent with how stage 014's exact imperative wording was
  drafted and reviewed at implementation time rather than fully specified
  up front.
- **Marker directory/file naming under the new state root**
  (`unresolved-notice/` vs. alternatives) -- no strong constraint surfaced
  in this conversation; finalize during implementation for consistency
  with the relocated `log`/`pending/` naming.
- **Path-mangling edge cases** -- the literal-path mangling scheme
  (strip leading `/`, replace remaining `/` with `_`) needs to handle
  characters otherwise unsafe in a directory name (unlikely but possible
  in a project path) and very long absolute paths approaching filesystem
  name-length limits; treat as an implementation-time detail, not a
  planning-level blocker.
- **R/bash mangling-logic drift** -- the mangling function must produce
  byte-identical output on both the R side (from `getwd()`) and the bash
  side (from the hook payload's `cwd` field) for the same path, or the two
  processes will silently write to and read from different directories.
  Neither side performs symlink resolution in this design (matching the
  existing, pre-this-stage assumption that R's `getwd()` and the hook's
  reported `cwd` already refer to the same directory) -- if that
  assumption ever breaks for a given setup, the failure mode is silent
  (writes and reads simply land in different places), which is a
  pre-existing risk this stage does not newly introduce but also does not
  solve.
- **Per-agent file-modifying tool-call detection details** -- Claude
  Code's `tool_name` values are known from existing code
  (`agent-hooks/claude/post_tool_use.sh` already parses `.cwd` from the
  payload; the equivalent `tool_name`/`tool_input` fields need the same
  treatment). opencode's actual `PostToolUse`-equivalent payload shape for
  file-modifying tools needs confirming directly against its plugin API
  during implementation -- stage 015 already found opencode's hook
  mechanism undocumented enough that its blocking convention was adopted
  as an explicitly unverified fallback; this stage's non-blocking
  injection needs its own, separate verification rather than inheriting
  stage 015's unverified status either way.
- **Whether non-blocking annotation text can even be injected into
  opencode's transcript the way Claude Code's is** -- needs direct
  verification (e.g. a manual smoke-test session) before trusting that
  this stage's fix reaches an opencode agent at all, given the diagnosis's
  own open question about whether opencode surfaces *any* hook-injected
  content as visible context.
- **Feedback loop back into `askfirst-tests`**: the natural validation of
  this stage's fix is re-running the same
  `opencode × with-hooks × problem1` trial cell post-merge to see whether
  the diagnosed gap closes. That re-run lives in the `askfirst-tests`
  sibling repo's own workflow (`instructions.md`), not in this stage's
  implementation -- flagged here only so it isn't lost, not as a task this
  stage itself completes.
