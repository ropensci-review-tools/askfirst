---
created: 2026-07-31T00:00:00Z
agent: claude-sonnet-5
git_hash: 667f262a4b0432043b00bfcdedc60dde10b0f449
---

# Design Decisions: Retrospective (027)

## Commit Window
From: fcdce2b7
To: 667f262a
Commits: 10

## Summary
This window closed out stage 026's design-decisions.md and then continued hardening the cross-platform install/hooks test suite through five follow-up fixes for Windows and macOS CI failures, alongside a small correction to reinstate Claude Code's designlens hook scripts that had been dropped.

## Changes Captured

### Cross-platform test-install-hooks fixes
**What changed:** A run of targeted fixes to `tests/test-install-hooks.sh`, `bindings/r/R/install_hooks.R`, `agent-hooks/install-agent-hooks.sh`, `.github/workflows/test.yml`, and `install.ps1`: skipping the Windows WSL-launcher `bash.exe` stub in `install_hooks.R`, adding R-side diagnostics for a phase-3 failure that was identical across reruns, fixing a macOS `timeout` dependency and stale-package caching in tests, replacing `mapfile` (unavailable in bash 3.2, macOS's default) and a shebang-execution issue affecting Windows, correcting phase 4's `--tool` flag, and enforcing LF line endings via `.gitattributes` to avoid CRLF-related breakage on Windows checkouts.
**Rationale:** Each fix targeted a specific CI failure signature on a specific OS (Windows or macOS), discovered by iterating on real CI runs rather than local reproduction — commit messages reference the observed symptom (e.g. "Windows still fails identically") directly.
**Impact:** The install-hooks test suite is now expected to pass identically across Linux, macOS, and Windows runners; future changes to install scripts should account for bash 3.2 (macOS), WSL bash.exe shims, and CRLF line endings as recurring constraints.

### Claude Code hook reinstatement
**What changed:** `.claude/hooks/designlens_session_start.sh`, `designlens_post_tool_use.sh`, and `designlens_stop.sh` were re-added, and `.claude/settings.json` updated to reference the corrected hook paths.
**Rationale:** These designlens-owned hook scripts had gone missing from the working tree relative to what settings.json expected; reinstating them restores the designlens session/status hook behavior.
**Impact:** designlens's own Claude Code integration (session-start banner, stop-hook stats collection) is intact going forward.

## Notes
Several commits in this window include only `.metadata.json` diffs alongside the substantive change — these are designlens's own per-stage session-stat accumulation, incrementing as work continued on stage 026 after its design-decisions.md had already been written, not separate functional changes.
