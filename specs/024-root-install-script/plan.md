---
created: 2026-07-30T00:00:00Z
agent: claude-sonnet-5
git_hash: d367e8e09e97cbbe5b7782774e18b465f7f49411
---

# Plan: root-install-script

## Overview
Add a root-level `install.sh` wrapper script and revise `README.md` with a
one-line, copy-paste `curl | bash` install instruction for the agent hooks,
keeping the R install function (`askfirst_install_agent_hooks()`) and the
vignette's local-checkout example documented alongside it as alternative
paths.

## Context
- `agent-hooks/install-agent-hooks.sh` (stage 012 onward) is already the
  single canonical, self-contained installer: hook scripts are embedded
  inline via heredocs so it works regardless of whether the rest of
  `agent-hooks/` exists at the call site, and it operates purely on the
  caller's `$PWD` (no `$0`-relative sibling-file lookups). It already
  handles Windows-style paths at the state-dir-mangling level (stage 020).
  This means no new installer logic is needed — only a new, easily
  discoverable entry point to it.
- `agent-hooks/generate-install-hooks.sh` (stages 012, 018, 019) already
  maintains a two-layer regeneration pipeline that keeps
  `install-agent-hooks.sh` in sync with several canonical sources
  (`agent-hooks/claude/*.sh`, `agent-hooks/opencode/askfirst-plugin.js`,
  shared prose/mangling-logic fragments). Adding a fifth file to that
  pipeline was considered and explicitly rejected (see Decision below) to
  avoid extending an already-nontrivial sync mechanism.
- The R binding (`bindings/r/R/install_hooks.R`) locates the installer via
  `system.file("agent-hooks", "install-agent-hooks.sh", package =
  "askfirst")`, relying on `agent-hooks/` being symlinked whole into
  `bindings/r/inst/`. This stage does not touch that file or its behavior
  — the user has explicitly asked to keep the R function as-is.
- The vignette (`bindings/r/vignettes/using-askfirst.Rmd`, section "0.
  Pre-configuring agent tools") currently documents two install paths: the
  R function, and running `/path/to/askfirst/agent-hooks/install-agent-hooks.sh`
  directly from a local checkout. Neither path works for someone who has
  not yet cloned/installed anything — the gap this stage closes.
- Repo confirmed as `ropensci-review-tools/askfirst` on GitHub, default
  branch `main` (matches `git_hash` above / recent commit history).
- Repo visibility confirmed **private** (`gh repo view` →
  `"visibility":"PRIVATE"`). `raw.githubusercontent.com` does not serve
  private-repo content to unauthenticated requests, so `install.sh`'s
  `curl` step is expected to fail in CI (and for any real user) until the
  repo is made public. The user has explicitly asked to write and wire up
  the test anyway, on the expectation it starts passing once the repo's
  visibility changes — not to build any workaround (auth token, mocked
  URL, etc.) around this in the meantime.
- Existing CI conventions checked: `.github/workflows/r-cmd-check.yml`
  already runs a `{macos-latest, windows-latest, ubuntu-latest}` matrix
  via `r-lib/actions`, and `.github/workflows/sync-agent-detect-spec.yml`
  shows the project's house style for `curl`-based steps (`curl -sL`,
  explicit `steps.<id>.outputs` checks rather than silent failure).
  GitHub Actions' `shell: bash` on `windows-latest` runs via the Git Bash
  that ships with the runner image — the same environment this stage's
  Windows story already targets, so no extra Windows-specific setup step
  is needed for the bash-script tests themselves.
- No existing convention for standalone (non-R) test scripts, except
  `agent-hooks/opencode/askfirst-plugin.test.js`, which is colocated
  directly next to the source file it tests rather than under a separate
  `tests/` directory.

## Design Goals
1. A first-time user with no local checkout and no R installed can set up
   the agent hooks for their project with a single copy-paste terminal
   command from the README.
2. No new duplication of hook-installer logic: the root script defers to
   the existing canonical `agent-hooks/install-agent-hooks.sh`, so
   `agent-hooks/generate-install-hooks.sh`'s existing sync pipeline does
   not need to grow a new target.
3. The one-liner and root script work as-is on Linux and macOS, and on
   Windows under a bash environment (Git Bash or WSL) — consistent with
   `install-agent-hooks.sh`'s existing Windows-path handling (stage 020).
   A PowerShell-native entry point (`install.ps1`) is also provided for
   Windows users who prefer not to invoke Git Bash/WSL themselves; it
   still shells out to the same canonical `install-agent-hooks.sh` under
   the hood (see Proposed Approach) rather than reimplementing installer
   logic, so this does not reopen the no-duplicate-logic tradeoff in
   Goal 2. No cmd.exe-native variant is created.
4. Existing install paths (R function, local-checkout script invocation)
   remain valid and are cross-referenced, not replaced.
5. CI verifies the install machinery actually works on all three target
   OSes (Linux, macOS, Windows via Git Bash) and that the R-function
   install path and the direct-script install path produce the same
   result — a regression check, not just a docs claim.

## Proposed Approach
- **`install.sh` (new, repo root):** a thin wrapper, not a duplicate. It
  `curl`s `agent-hooks/install-agent-hooks.sh` from
  `https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/agent-hooks/install-agent-hooks.sh`
  and execs it via `bash -s -- "$@"`, forwarding any arguments (e.g.
  `--tool claude`, `--overwrite`) the caller passed. Runs against the
  caller's current `$PWD`, matching `install-agent-hooks.sh`'s own
  existing behavior. `set -euo pipefail`; fails loudly (non-zero exit, an
  error visible in the piped output) if the download fails, rather than
  silently no-op-ing.
- **`install.ps1` (new, repo root):** a PowerShell counterpart to
  `install.sh`, not a reimplementation of installer logic. Downloads
  `agent-hooks/install-agent-hooks.sh` from the same raw-GitHub URL
  (`Invoke-WebRequest` in place of `curl`) to a temp file, locates a
  `bash` executable (Git Bash first, falling back to `wsl bash`), and
  execs the downloaded script through it, forwarding `$args` (e.g.
  `-tool claude`, `-overwrite`). Runs against the caller's current
  working directory, matching `install.sh`/`install-agent-hooks.sh`. If
  no bash is found, prints a clear error naming Git Bash/WSL as
  prerequisites and exits non-zero, rather than silently no-op-ing —
  same fail-loud contract as `install.sh`.
- **README.md revision:** replace the current one-line "please install
  agent-specific hooks" sentence under "askfirst for everybody" with:
  - A fenced `bash` code block containing the copy-paste one-liner:
    `curl -fsSL https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.sh | bash`
  - A fenced `powershell` code block containing the PowerShell
    equivalent using `install.ps1`, for users who want a native
    PowerShell entry point (still requires Git Bash or WSL to be present
    on the machine, since it shells out — noted alongside it).
  - A short "R users" note pointing at `askfirst_install_agent_hooks()` /
    `askfirst_detect_agent_tool()` as the equivalent R-native path (kept
    exactly as-is per instruction), linking to the vignette for details.
- **Vignette cross-reference (`using-askfirst.Rmd`, section "0.
  Pre-configuring agent tools"):** add the new one-liner as a third
  documented option alongside the existing R-function and
  local-checkout-script examples, so the vignette and README stay
  consistent. `askfirst-development.Rmd`'s references to
  `install-agent-hooks.sh` (maintainer-facing regeneration docs) are left
  untouched — out of scope, not user-facing install instructions.
- **Decision — wrapper vs. standalone copy:** chosen: thin wrapper that
  fetches from GitHub at run time. Rejected alternative: a full
  standalone copy of the installer logic at the repo root, kept in sync
  by extending `generate-install-hooks.sh`. Rejected because it would add
  a fifth synced target to an already multi-stage regeneration pipeline
  (stages 012/018/019) for no functional benefit — the wrapper achieves
  the same one-liner UX with a single source of truth. Tradeoff accepted:
  the one-liner requires network access and depends on the `main` branch
  being runnable at any given moment (no release-tag pinning, since the
  project has no existing release/tagging process to hook into).
  `install.ps1` follows the same decision: it is a wrapper around
  `install-agent-hooks.sh` (via a located `bash`), not a sixth synced
  target, so it does not extend `generate-install-hooks.sh`'s pipeline
  either. Its own tradeoff: it still requires a `bash` executable
  (Git Bash or WSL) to be present on the Windows machine — it removes
  the need for the *user* to invoke bash themselves, not the underlying
  bash dependency itself.
- **New `tests/` directory with `tests/test-install-hooks.sh`:** a
  standalone bash script under a new top-level `tests/` directory (not
  colocated in `agent-hooks/`), starting this project's general-purpose
  test location so future non-R-package tests land here too, rather than
  scattered per-directory (the only prior precedent,
  `agent-hooks/opencode/askfirst-plugin.test.js`, stays where it is —
  out of scope to move). Runs four independent phases, each in its own
  scratch temp directory (`mktemp -d`) so they can't interfere with each
  other or the checkout:
  1. **Direct-script install (hard requirement, always enforced):** runs
     the checked-out `agent-hooks/install-agent-hooks.sh --tool claude`
     against a scratch dir seeded with a minimal `.claude/settings.json`,
     and asserts the three namespaced hook files are written and
     registered. This is the one phase that validates real installer
     logic on each OS and must always pass.
  2. **`install.sh` live-fetch (soft requirement while the repo is
     private):** runs the real repo-root `install.sh`, unmodified,
     against a scratch dir — i.e. the actual `curl .../main/install.sh |
     bash` path a user would run. Wired up for real, but the workflow
     step uses `continue-on-error: true` with a comment explaining why
     (private repo → `raw.githubusercontent.com` 404s pre-authentication)
     and noting that `continue-on-error` should be removed once the repo
     goes public, at which point this becomes a hard, enforced check like
     phase 1.
  3. **R function vs. script comparison (hard requirement):** runs
     `askfirst::askfirst_install_agent_hooks("claude")` via `Rscript` in
     one scratch dir and `agent-hooks/install-agent-hooks.sh --tool
     claude` directly in another, then diffs the resulting
     `.claude/hooks/*.sh` file contents and the `.hooks` section of
     `.claude/settings.json` between the two, failing on any difference.
     Guards against future drift (e.g. the R binding someday passing
     different flags) even though today the R function is just a thin
     `system2()` wrapper around the same script.
  4. **`install.ps1` install (hard requirement):** runs the repo-root
     `install.ps1` via `pwsh` (PowerShell Core, preinstalled on all three
     GitHub-hosted runner images, so this phase runs on Linux/macOS/
     Windows alike rather than only under `windows-latest`) against a
     scratch dir, and asserts the same hook-file/registration outcome as
     phase 1 — i.e. `install.ps1`'s bash-discovery-and-exec path produces
     an identical result to invoking `install-agent-hooks.sh` directly.
- **New workflow (`.github/workflows/test-install.yml`):** triggered on
  `push`/`pull_request` `paths` touching `install.sh`, `install.ps1`,
  `agent-hooks/**`, `tests/test-install-hooks.sh`, or
  `bindings/r/R/install_hooks.R` (mirroring `r-cmd-check.yml`'s
  path-filtering style). Matrix over `{ubuntu-latest, macos-latest,
  windows-latest}`, `shell: bash` throughout (phase 4's `pwsh` invocation
  is called out from within the bash test script itself, not the
  workflow's own step shell). Sets up R (`r-lib/actions/
  setup-r@v2` + `setup-r-dependencies@v2` against `bindings/r`, matching
  `r-cmd-check.yml`) since phase 3 needs the `askfirst` package
  installed. Each job simply checks out and runs
  `tests/test-install-hooks.sh`.

## Open Questions
None outstanding — script strategy, branch to target, vignette scope, and
CI approach were resolved with the user before this plan was written.
