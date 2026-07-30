---
created: 2026-07-30T15:15:00Z
agent: claude-sonnet-5
git_hash: 134db745bb5bc438c82002c415bafdd6a528f69b
---

# Design Decisions: root-install-script

## Summary
Added a copy-paste one-line install path for askfirst's agent hooks —
`install.sh` (bash) and `install.ps1` (PowerShell) at the repo root, both
thin wrappers around the existing canonical `agent-hooks/install-agent-hooks.sh`
— with README and vignette cross-references, plus a new CI-verified test
suite comparing all install paths against each other.

## New Design Decisions

### Decision 1: `install.sh` as a thin curl-and-exec wrapper
**Chosen:** A root-level `install.sh` that `curl`s
`agent-hooks/install-agent-hooks.sh` from GitHub's raw content endpoint and
execs it via `bash -s -- "$@"`, forwarding all caller arguments.
**Rationale:** Gives a first-time user with no local checkout and no R
installed a single copy-paste terminal command, without duplicating
installer logic that `agent-hooks/generate-install-hooks.sh` would then
need a new sync target to keep current.
**Tradeoffs:** Requires network access and depends on the `main` branch
being runnable at any given moment — no release-tag pinning exists yet to
hook into.
**Proposed by:** joint

### Decision 2: `install.ps1` added as a bash-shelling PowerShell wrapper, reversing an earlier no-PowerShell-variant call
**Chosen:** A root-level `install.ps1` that downloads the same
`install-agent-hooks.sh`, locates a `bash` executable (Git Bash first,
falling back to WSL), and execs the script through it — rather than
reimplementing installer logic natively in PowerShell.
**Rationale:** The initial version of this stage's plan explicitly decided
against a PowerShell/cmd-native variant, documenting the Windows story via
README prose (Git Bash/WSL) instead. That decision was revisited
mid-session once a PowerShell-runnable entry point was requested; the
bash-shelling wrapper approach preserves the single-source-of-truth
property that motivated Decision 1, at the cost of `install.ps1` still
depending on Git Bash/WSL being present on the machine.
**Tradeoffs:** Does not remove the underlying bash dependency, only the
need for the user to invoke bash themselves. A native reimplementation was
considered and rejected for the same reason a standalone `install.sh` copy
was rejected in Decision 1.
**Proposed by:** joint — see the stage's `.transcript.md` for the session
in which this was decided.

### Decision 3: New top-level `tests/` directory for install verification
**Chosen:** `tests/test-install-hooks.sh`, running four independent
scratch-directory phases (direct-script install; `install.sh` live-fetch;
R-function-vs-script diff; `install.ps1` via `pwsh`), rather than
colocating the test with `agent-hooks/` as originally planned.
**Rationale:** Establishes a general-purpose test location for this
project going forward, since more non-R-package tests are expected later.
**Tradeoffs:** Diverges from the one existing colocation precedent
(`agent-hooks/opencode/askfirst-plugin.test.js`), which was left in place
rather than moved.
**Proposed by:** git-user

## Integration with Prior Work
Builds directly on stage 020's Windows-path-mangling handling and stage
023's hook-filename namespacing inside `install-agent-hooks.sh` — neither
required changes here, since both `install.sh` and `install.ps1` defer to
that script unmodified. The R binding (`bindings/r/R/install_hooks.R`) is
untouched, per an explicit instruction to keep it as-is; it remains the
comparison baseline in the new test suite's phase 3.

## Issues Resolved
- No discoverable install path existed for a user with no local checkout
  and no R installed: closed by `install.sh`/`install.ps1` plus matching
  README and vignette entries.
- The base plan's private-repo caveat (`raw.githubusercontent.com` 404s
  pre-authentication) is handled as a soft, `continue-on-error` CI phase
  rather than worked around, per explicit instruction not to add auth
  tokens or mocked URLs.

## Deferred Items
- Promoting the `install.sh`/`install.ps1` live-fetch CI phase from soft
  to hard once the repo becomes public.
- No release-tag pinning for the one-liners; both track `main` directly.

## Process Notes
- This stage's plan was revised in place, mid-session, to add Decision 2
  and Decision 3 above after `tasks.md` had already been generated once —
  both `plan.md` and `tasks.md` were updated together to keep them
  consistent before implementation began.
