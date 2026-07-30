---
created: 2026-07-30T14:30:00Z
agent: claude-sonnet-5
git_hash: d367e8e09e97cbbe5b7782774e18b465f7f49411
---

# Tasks: root-install-script

## T024-1: Create root-level `install.sh` wrapper
- [ ] T024-1: Create `install.sh` at the repo root. It must: start with
  `#!/usr/bin/env bash` and `set -euo pipefail`; `curl -fsSL` the raw file
  `https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/agent-hooks/install-agent-hooks.sh`
  and pipe it into `bash -s -- "$@"` so any arguments the caller passes
  (e.g. `--tool claude`, `--overwrite`, `--detect`) are forwarded
  unchanged; run against the caller's current `$PWD` (no `cd`, no
  `$0`-relative lookups — mirrors `agent-hooks/install-agent-hooks.sh`'s
  own behavior). Because of `set -euo pipefail` plus `curl -f`, a failed
  download (e.g. 404 while the repo is private) must produce a non-zero
  exit status and a visible error rather than a silent no-op. Make the
  file executable (`chmod +x install.sh`).

## T024-2: Create root-level `install.ps1` PowerShell wrapper
- [ ] T024-2: Create `install.ps1` at the repo root, a PowerShell
  counterpart to `install.sh` — a wrapper, not a reimplementation of
  installer logic. It must:
  1. Download `agent-hooks/install-agent-hooks.sh` from
     `https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/agent-hooks/install-agent-hooks.sh`
     to a temp file via `Invoke-WebRequest` (fail loudly — non-zero exit
     with a visible error — if the download fails, e.g. 404 while the
     repo is private).
  2. Locate a `bash` executable: try Git Bash first (e.g. resolve via
     `Get-Command bash -ErrorAction SilentlyContinue`, which picks up Git
     Bash's `bash.exe` if it's on `PATH`), falling back to `wsl bash` if
     no native `bash` is found.
  3. If a bash is found, exec the downloaded script through it, e.g.
     `bash <tempfile> @args` (or the `wsl` equivalent), forwarding any
     arguments the caller passed (e.g. `-tool claude`, `-overwrite`) so
     behavior matches `install.sh`/`install-agent-hooks.sh` exactly.
  4. If no bash is found, `Write-Error` a clear message naming Git Bash
     and WSL as prerequisites with brief pointers to install either, and
     exit non-zero — do not silently no-op.
  Run against the caller's current working directory (no path
  assumptions beyond that), matching `install.sh`'s behavior.

## T024-3: Revise `README.md`'s "askfirst for everybody" section
- [ ] T024-3: In `README.md`, replace the current single sentence under
  `## askfirst for everybody` ("To make sure your AI will respond
  appropriately to `askfirst` messages, please install agent-specific
  hooks.") with:
  1. A short intro sentence keeping the same meaning.
  2. A fenced ```bash code block containing exactly:
     `curl -fsSL https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.sh | bash`
  3. A fenced ```powershell code block containing the PowerShell
     equivalent, e.g.:
     `irm https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.ps1 | iex`
     with a short note that this still requires Git Bash or WSL to be
     present on the machine (since `install.ps1` shells out to bash
     under the hood), and that Linux/macOS users should use the `bash`
     one-liner above instead.
  4. A short "R users" note pointing at
     `askfirst::askfirst_detect_agent_tool()` /
     `askfirst::askfirst_install_agent_hooks()` as the R-native
     equivalent, with a pointer to the vignette
     (`bindings/r/vignettes/using-askfirst.Rmd`) for details. Do not
     change any other section of `README.md`.

## T024-4: Cross-reference both one-liners in the vignette
- [ ] T024-4: In `bindings/r/vignettes/using-askfirst.Rmd`, section "0.
  Pre-configuring agent tools" (currently lines 26-69), add the new
  `curl -fsSL .../install.sh | bash` and
  `irm .../install.ps1 | iex` one-liners as a third documented install
  path (bash version primary, PowerShell version noted as the
  Windows-native alternative requiring Git Bash/WSL), alongside the
  existing R-function example (lines 32-40) and the local-checkout
  `agent-hooks/install-agent-hooks.sh` example (lines 62-69). Present it
  as the option for someone with no local checkout and no R installed
  yet. Leave the existing two examples and all other vignette content,
  including `askfirst-development.Rmd`, untouched.

## T024-5: Write `tests/test-install-hooks.sh`
- [ ] T024-5: Create a standalone bash test script at
  `tests/test-install-hooks.sh`, in a new top-level `tests/` directory
  (this establishes that directory as the project's general test
  location going forward — more tests will land here later — rather than
  colocating with `agent-hooks/`). It must run four phases, each in its
  own `mktemp -d` scratch directory so they cannot interfere with each
  other or the checkout, and must `exit 1` with a clear message on any
  failed assertion:
  1. **Direct-script install (hard, always enforced):** seed a scratch
     dir with a minimal `.claude/settings.json` (e.g. `{}`), run the
     checked-out `agent-hooks/install-agent-hooks.sh --tool claude`
     against it, and assert `.claude/hooks/askfirst-session-start.sh`,
     `.claude/hooks/askfirst-post-tool-use.sh`, and
     `.claude/hooks/askfirst-user-prompt-submit.sh` all exist, and that
     `.claude/settings.json`'s `.hooks.SessionStart`,
     `.hooks.PostToolUse`, and `.hooks.UserPromptSubmit` arrays each
     reference the corresponding `.claude/hooks/askfirst-*.sh` command
     (use `jq` for the JSON assertions). Factor these assertions into a
     reusable shell function since phases 2-4 all repeat them.
  2. **`install.sh` live-fetch (soft, `continue-on-error` while private):**
     in a second scratch dir, run the real repo-root `install.sh`
     unmodified (the actual `curl .../main/install.sh | bash` path), and
     apply the same assertions as phase 1. Structure this phase so the
     calling workflow step can mark it `continue-on-error: true`
     independently of the other phases (e.g. isolate it in its own
     function/exit code, or make the script accept a flag/env var to run
     only this phase) — do not let a failure here abort phases 1, 3, or
     4. Include a comment explaining that this is expected to fail until
     the repo is made public (private repos 404 on unauthenticated
     `raw.githubusercontent.com` requests), and that the
     `continue-on-error` should be removed at that point.
  3. **R-function vs. script comparison (hard, always enforced):** in two
     more scratch dirs, run `Rscript -e
     'askfirst::askfirst_install_agent_hooks("claude")'` in one and
     `agent-hooks/install-agent-hooks.sh --tool claude` directly in the
     other (each seeded with the same minimal `.claude/settings.json`),
     then `diff` the three `.claude/hooks/askfirst-*.sh` files byte-for-byte
     between the two dirs, and compare the `.hooks` section of
     `.claude/settings.json` between the two (e.g. via `jq .hooks` on
     each, diffed), failing the script if anything differs.
  4. **`install.ps1` install (hard, always enforced):** in a fourth
     scratch dir, run the repo-root `install.ps1` via `pwsh` (PowerShell
     Core — preinstalled on `ubuntu-latest`, `macos-latest`, and
     `windows-latest` GitHub-hosted runners, so this phase is not
     Windows-only), e.g. `pwsh -File install.ps1 -tool claude` from
     within the scratch dir, and apply the same assertions as phase 1 —
     confirming `install.ps1`'s bash-discovery-and-exec path produces an
     identical result to invoking `install-agent-hooks.sh` directly. If
     `pwsh` is not on `PATH` in a given environment, this phase should
     fail loudly rather than silently skip.
  Make the script executable and runnable standalone with no required
  arguments (`./tests/test-install-hooks.sh`), printing a clear pass/fail
  summary per phase.

## T024-6: Add `.github/workflows/test-install.yml`
- [ ] T024-6: Create `.github/workflows/test-install.yml`, matching the
  path-filtering and step-naming style of the existing
  `.github/workflows/r-cmd-check.yml`. Trigger on `push` and
  `pull_request` with `paths` covering `install.sh`, `install.ps1`,
  `agent-hooks/**`, `tests/test-install-hooks.sh`,
  `bindings/r/R/install_hooks.R`, and
  `.github/workflows/test-install.yml` itself. Define one job with
  `strategy.matrix.os: [ubuntu-latest, macos-latest, windows-latest]`,
  `shell: bash` set for all `run` steps (needed for `windows-latest`'s
  Git Bash; phase 4's `pwsh` invocation happens from inside the bash test
  script itself, so no separate PowerShell step shell is needed). Steps:
  checkout (`actions/checkout@v4`); set up R
  (`r-lib/actions/setup-r@v2`) and R dependencies
  (`r-lib/actions/setup-r-dependencies@v2` with
  `working-directory: bindings/r`) since phase 3 of the test script needs
  the `askfirst` package installed; then a step that runs
  `tests/test-install-hooks.sh` in full-run mode, with
  `continue-on-error: true` applied only to the sub-part covering phase 2
  (per how T024-5 exposes that phase) and a comment cross-referencing the
  private-repo caveat from T024-5.

## T024-7: Verify the full change set locally
- [ ] T024-7: With the repo still private, run
  `tests/test-install-hooks.sh` locally and confirm: phase 1
  (direct-script install) passes, phase 2 (`install.sh` live-fetch) fails
  with a network/404 error (expected while private — confirms `install.sh`
  fails loudly rather than silently), phase 3 (R-function vs. script
  diff) passes with zero differences, and phase 4 (`install.ps1` via
  `pwsh`) passes and matches phase 1's result (if `pwsh` isn't available
  locally, confirm it at least runs correctly in the CI matrix from
  T024-6 instead). Also manually inspect the rendered `README.md` and the
  vignette diff for correctness (both code blocks render, both
  one-liners are copy-pasteable, the PowerShell block's Git Bash/WSL
  caveat is present and accurate). Do not attempt to work around the
  phase-2 failure (no auth token, no mocked URL) — a failing phase 2 at
  this point is the expected, documented state per the plan.
