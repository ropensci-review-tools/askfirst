---
created: 2026-07-29T14:06:06Z
agent: claude-sonnet-5
git_hash: 9a84f92a25af9435f8f22c2a1b82129a98791244
---

# Tasks: harden-hooks-nudge-relay

## T021-1: Add TELL-USER/END-TELL-USER markers, revise nudge wording, sync to the R binding
- [ ] T021-1: In `agent-content/askfirst-markers.txt`, add a new
  `TELL-USER` / `END-TELL-USER` section pair after the existing `HALT` /
  `RESUME` pair, following the file's exact `--- NAME ---` / token format:
  ```
  --- TELL-USER ---
  <<<ASKFIRST:TELL-USER>>>
  --- END-TELL-USER ---
  <<<ASKFIRST:END-TELL-USER>>>
  ```
  In `agent-content/askfirst-hooks-nudge.txt`, replace "Tell your human
  user to run `agent-hooks/install-agent-hooks.sh` (from the askfirst
  repository) to install or update hooks that help you and other..." with
  "Tell your human user to install 'askfirst' agent hooks from
  `https://github.com/ropensci-review-tools/askfirst` to help you and
  other...", leaving the rest of the sentence ("AI coding assistants
  recognise askfirst's structured signals directly, rather than relying
  solely on this per-call condition text.") unchanged. Do not touch the
  separate, unchanged human-directed console nudge in
  `askfirst_maybe_nudge_hooks_install()` (`bindings/r/R/hooks_status.R`),
  which still references `agent-hooks/install-agent-hooks.sh` directly and
  is out of scope for this stage.
  Then run `Rscript bindings/r/data-raw/sync-agent-content.R` from the repo
  root to copy both updated files into
  `bindings/r/inst/agent-content/`, and confirm
  `Rscript bindings/r/data-raw/check-agent-content-sync.R` reports the
  copies in sync.

## T021-2: Add TELL-USER delimiter helpers to conditions.R
- [ ] T021-2: In `bindings/r/R/conditions.R`, add
  `askfirst_tell_user_start_delimiter()` and
  `askfirst_tell_user_end_delimiter()`, mirroring
  `askfirst_stop_start_delimiter()`/`askfirst_stop_end_delimiter()`
  exactly (each calls `askfirst_load_marker()` with `"TELL-USER"` /
  `"END-TELL-USER"` respectively, `@rdname askfirst_stop_start_delimiter`,
  `@keywords internal`, `@noRd`).

## T021-3: Add session-state fields for the pending relay
- [ ] T021-3: In `bindings/r/R/state.R`, add
  `.askfirst_state$hooks_nudge_pending_relay <- FALSE` and
  `.askfirst_state$hooks_nudge_relay_text <- NULL` alongside the existing
  `.askfirst_state$hooks_nudge_shown <- FALSE` initializer. In
  `bindings/r/tests/testthat/helper-state.R`'s `local_reset_askfirst_state()`,
  add both new fields to the `old <- list(...)` save block, the reset
  block that follows it, and the `withr::defer()` restore block, matching
  exactly how `hooks_nudge_shown` is already saved/reset/restored there —
  otherwise the new fields will leak state between tests.

## T021-4: Give askfirst_hooks_nudge its own TELL-USER-bounded message shape
- [ ] T021-4: In `askfirst_signal()` (`bindings/r/R/conditions.R`), add a
  third message-assembly branch, taken only when
  `class == "askfirst_hooks_nudge"` (checked before the existing
  `directive_map[[class]] == "stop-and-ask"` branch, since this class's
  directive is `"notice"` but it must not fall into the generic notice
  branch below it). This branch:
  1. Assembles `tell_user_block <- paste(askfirst_tell_user_start_delimiter(), header, message, askfirst_tell_user_end_delimiter(), sep = "\n\n")` (no `askfirst_notice_prime()` text — that sentence exists only to prime for a later hard stop, which doesn't apply to this class).
  2. Stashes the undecorated block for later reuse:
     `.askfirst_state$hooks_nudge_relay_text <- tell_user_block` and
     `.askfirst_state$hooks_nudge_pending_relay <- TRUE`.
  3. Sets the final `message` for this call to
     `paste(tell_user_block, url_line, sep = "\n\n")` (the standalone
     signalled message keeps its own `See:` line).
  The generic notice-shape branch (used by `askfirst_notice`) is otherwise
  unchanged. Update the roxygen block immediately above `askfirst_signal()`
  (the "Hard-stop shape" / "Notice shape" bullet list and the
  `askfirst_hooks_nudge` bullet under "Five concrete classes...") to
  describe this as a third, distinct shape rather than "Uses the notice
  shape."

## T021-5: Implement the merge into a later stop-and-ask halt
- [ ] T021-5: In `askfirst_signal()`'s hard-stop-shape branch
  (`bindings/r/R/conditions.R`, the `identical(directive_map[[class]], "stop-and-ask")` branch), before assembling the existing
  `askfirst_stop_start_delimiter()`-bounded message: if
  `isTRUE(.askfirst_state$hooks_nudge_pending_relay)`, prepend
  `.askfirst_state$hooks_nudge_relay_text` to the assembled `message`
  (nudge block first, then the existing hard-stop block, joined with
  `"\n\n"`, matching the "Confirmed merged-message shape" in `plan.md`),
  and then set `.askfirst_state$hooks_nudge_pending_relay <- FALSE`. The
  halt's own trailing `url_line` is unchanged and remains the only `See:`
  line in the merged message (the stashed nudge block has none of its
  own, per T021-4). Update the roxygen block above `askfirst_signal()` to
  document this merge behaviour (when it triggers, what it prepends, and
  that it consumes the pending flag so only the next halt after a fresh
  nudge absorbs it).

## T021-6: Test the new TELL-USER shape
- [ ] T021-6: In `bindings/r/tests/testthat/test-init.R`, add tests
  (following the file's existing `local_reset_askfirst_state()` /
  `withCallingHandlers()` conventions used by the neighbouring
  `askfirst_hooks_nudge` tests around line 320):
  - `askfirst_load_marker("TELL-USER")` and
    `askfirst_load_marker("END-TELL-USER")` return
    `"<<<ASKFIRST:TELL-USER>>>"` and `"<<<ASKFIRST:END-TELL-USER>>>"`
    respectively (mirroring the existing HALT/RESUME test at line 264).
  - Under high confidence with hooks missing, the `askfirst_hooks_nudge`
    condition's message is bounded by `"<<<ASKFIRST:TELL-USER>>>"` /
    `"<<<ASKFIRST:END-TELL-USER>>>"` and contains a `"See:"` line.
  - That same message does **not** contain
    `"<<<ASKFIRST:HALT>>>"`/`"<<<ASKFIRST:RESUME>>>"` and does not contain
    the forward-reference text `askfirst_notice_prime()` would have added
    (e.g. assert it doesn't match `"If a later signal"`, the fixed lead-in
    from `agent-content/askfirst-notice-prime.txt`).

  Also update the existing test `"askfirst_read_content reads agent-content/
  files verbatim"` (`test-init.R`, ~line 283-287), which currently asserts
  `expect_match(text, "agent-hooks/install-agent-hooks.sh", fixed = TRUE)`
  against `askfirst-hooks-nudge.txt` — this will fail once T021-1's wording
  revision lands. Replace that assertion with
  `expect_match(text, "https://github.com/ropensci-review-tools/askfirst", fixed = TRUE)`.

## T021-7: Test the merge with a same-session stop-and-ask halt
- [ ] T021-7: In `bindings/r/tests/testthat/test-capability-gap.R`, add
  tests using `askfirst_init()` (to trigger the nudge, as in
  `test-init.R`'s existing pattern) followed by
  `askfirst_capability_gap()` (to trigger a halt), both under high
  confidence with hooks missing, in the same simulated session
  (`local_reset_askfirst_state()` called once for the whole test):
  - The `askfirst_capability_gap` condition's message contains both the
    `"<<<ASKFIRST:TELL-USER>>>"`/`"<<<ASKFIRST:END-TELL-USER>>>"` block
    and the `"<<<ASKFIRST:HALT>>>"`/`"<<<ASKFIRST:RESUME>>>"` block, with
    the `TELL-USER` block appearing first (use
    `regexpr()`/position comparison, not just two separate
    `expect_match()` calls, to assert ordering).
  - That merged message contains exactly one `"See:"` line (the nudge's
    own was dropped).
  - A **second** `askfirst_capability_gap()` call in the same session
    (after the first already consumed the pending relay) does **not**
    contain a `"<<<ASKFIRST:TELL-USER>>>"` block.
  - A control case: calling `askfirst_capability_gap()` under high
    confidence with hooks missing but *without* first calling
    `askfirst_init()` (or with hooks current, so no nudge ever fires)
    produces a halt message with no `"<<<ASKFIRST:TELL-USER>>>"` block at
    all — the merge only applies when a nudge actually preceded it.

## T021-8: Full verification pass
- [ ] T021-8: From `bindings/r/`, run the full test suite
  (`devtools::test()` or `R CMD check`) and confirm no failures or new
  warnings/notes; from the repo root, re-run
  `Rscript bindings/r/data-raw/check-agent-content-sync.R` to confirm
  `agent-content/` and `bindings/r/inst/agent-content/` are still in sync
  after all edits.
