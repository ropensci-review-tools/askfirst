#!/usr/bin/env bash
# tests/test-install-hooks.sh — end-to-end tests for the askfirst agent-hooks
# installer and its root-level entry points (install.sh, install.ps1).
#
# Usage:
#   tests/test-install-hooks.sh                # run all 4 phases (phase 2 is
#                                               # reported but doesn't affect
#                                               # the exit code -- see phase2())
#   tests/test-install-hooks.sh --skip-phase2   # run phases 1, 3, 4 only (hard)
#   tests/test-install-hooks.sh --phase2-only   # run phase 2 only (soft, for a
#                                               # continue-on-error CI step)
#
# Phase 2 (install.sh's live curl-from-GitHub path) is expected to fail while
# the ropensci-review-tools/askfirst repo is private, since
# raw.githubusercontent.com 404s on unauthenticated requests to private repos.
# Once the repo is public, phase 2 should be promoted to a hard requirement
# (drop the --skip-phase2/--phase2-only split in the CI workflow and just run
# this script once).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$REPO_ROOT/agent-hooks/install-agent-hooks.sh"
INSTALL_SH="$REPO_ROOT/install.sh"
INSTALL_PS1="$REPO_ROOT/install.ps1"

PASS=0
HARD_FAIL=0

log_pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

log_fail() {
  echo "FAIL: $1" >&2
  HARD_FAIL=$((HARD_FAIL + 1))
}

log_soft_fail() {
  echo "FAIL (soft): $1" >&2
}

make_scratch_dir() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/.claude"
  echo '{}' >"$dir/.claude/settings.json"
  echo "$dir"
}

# Prints "ok" (and nothing else) on stdout if the three namespaced hook files
# exist in $1/.claude/hooks/ and are registered in $1/.claude/settings.json;
# otherwise prints one "missing: ..." line per problem found.
check_hooks_installed() {
  local dir="$1"
  local problem_found=false

  for f in askfirst-session-start.sh askfirst-post-tool-use.sh askfirst-user-prompt-submit.sh; do
    if [[ ! -f "$dir/.claude/hooks/$f" ]]; then
      echo "missing: .claude/hooks/$f"
      problem_found=true
    fi
  done

  if [[ ! -f "$dir/.claude/settings.json" ]]; then
    echo "missing: .claude/settings.json"
    return
  fi

  if ! jq -e '.hooks.SessionStart // [] | .[].hooks[]?.command | select(test("askfirst-session-start\\.sh$"))' \
    "$dir/.claude/settings.json" >/dev/null 2>&1; then
    echo "missing: SessionStart registration for askfirst-session-start.sh in .claude/settings.json"
    problem_found=true
  fi
  if ! jq -e '.hooks.PostToolUse // [] | .[].hooks[]?.command | select(test("askfirst-post-tool-use\\.sh$"))' \
    "$dir/.claude/settings.json" >/dev/null 2>&1; then
    echo "missing: PostToolUse registration for askfirst-post-tool-use.sh in .claude/settings.json"
    problem_found=true
  fi
  if ! jq -e '.hooks.UserPromptSubmit // [] | .[].hooks[]?.command | select(test("askfirst-user-prompt-submit\\.sh$"))' \
    "$dir/.claude/settings.json" >/dev/null 2>&1; then
    echo "missing: UserPromptSubmit registration for askfirst-user-prompt-submit.sh in .claude/settings.json"
    problem_found=true
  fi

  if [[ "$problem_found" == false ]]; then
    echo "ok"
  fi
}

# Phase 1: direct-script install (hard requirement, always enforced).
phase1() {
  local dir problems
  dir="$(make_scratch_dir)"
  if ! (cd "$dir" && "$INSTALLER" --tool claude) >/dev/null 2>&1; then
    log_fail "phase 1 (direct-script install): install-agent-hooks.sh exited non-zero"
    return
  fi
  problems="$(check_hooks_installed "$dir")"
  if [[ "$problems" == "ok" ]]; then
    log_pass "phase 1 (direct-script install)"
  else
    log_fail "phase 1 (direct-script install):
$problems"
  fi
}

# Phase 2: install.sh live-fetch (soft requirement while the repo is private).
phase2() {
  local dir problems
  dir="$(make_scratch_dir)"
  if ! (cd "$dir" && bash "$INSTALL_SH" --tool claude) >/dev/null 2>&1; then
    log_soft_fail "phase 2 (install.sh live-fetch): install.sh exited non-zero (expected while the repo is private)"
    return
  fi
  problems="$(check_hooks_installed "$dir")"
  if [[ "$problems" == "ok" ]]; then
    log_pass "phase 2 (install.sh live-fetch)"
  else
    log_soft_fail "phase 2 (install.sh live-fetch):
$problems"
  fi
}

# Phase 3: R function vs. script comparison (hard requirement, always enforced).
phase3() {
  local dir_r dir_script

  if ! Rscript -e 'if (!("askfirst" %in% rownames(installed.packages()))) quit(status = 1)' >/dev/null 2>&1; then
    if ! R CMD INSTALL --no-docs --no-byte-compile --no-test-load "$REPO_ROOT/bindings/r" >/dev/null 2>&1; then
      log_fail "phase 3 (R function vs. script comparison): R CMD INSTALL bindings/r failed"
      return
    fi
  fi

  dir_r="$(make_scratch_dir)"
  dir_script="$(make_scratch_dir)"

  if ! (cd "$dir_r" && Rscript -e 'askfirst::askfirst_install_agent_hooks("claude")') >/dev/null 2>&1; then
    log_fail "phase 3 (R function vs. script comparison): askfirst_install_agent_hooks() exited non-zero"
    return
  fi
  if ! (cd "$dir_script" && "$INSTALLER" --tool claude) >/dev/null 2>&1; then
    log_fail "phase 3 (R function vs. script comparison): install-agent-hooks.sh exited non-zero"
    return
  fi

  local diffs=""
  for f in askfirst-session-start.sh askfirst-post-tool-use.sh askfirst-user-prompt-submit.sh; do
    if ! diff -q "$dir_r/.claude/hooks/$f" "$dir_script/.claude/hooks/$f" >/dev/null 2>&1; then
      diffs="$diffs
.claude/hooks/$f differs between the R function and the direct script"
    fi
  done
  if ! diff -q <(jq -S .hooks "$dir_r/.claude/settings.json") <(jq -S .hooks "$dir_script/.claude/settings.json") >/dev/null 2>&1; then
    diffs="$diffs
.hooks section of .claude/settings.json differs between the R function and the direct script"
  fi

  if [[ -z "$diffs" ]]; then
    log_pass "phase 3 (R function vs. script comparison)"
  else
    log_fail "phase 3 (R function vs. script comparison):$diffs"
  fi
}

# Phase 4: install.ps1 install via pwsh (hard requirement, always enforced).
# pwsh (PowerShell Core) is preinstalled on ubuntu-latest, macos-latest, and
# windows-latest GitHub-hosted runners, so this phase is not Windows-only.
phase4() {
  local dir problems
  if ! command -v pwsh >/dev/null 2>&1; then
    log_fail "phase 4 (install.ps1 via pwsh): pwsh not found on PATH"
    return
  fi
  dir="$(make_scratch_dir)"
  if ! (cd "$dir" && pwsh -NoProfile -NonInteractive -File "$INSTALL_PS1" -tool claude) >/dev/null 2>&1; then
    log_fail "phase 4 (install.ps1 via pwsh): install.ps1 exited non-zero"
    return
  fi
  problems="$(check_hooks_installed "$dir")"
  if [[ "$problems" == "ok" ]]; then
    log_pass "phase 4 (install.ps1 via pwsh)"
  else
    log_fail "phase 4 (install.ps1 via pwsh):
$problems"
  fi
}

MODE="${1:-all}"

case "$MODE" in
  --skip-phase2)
    phase1
    phase3
    phase4
    ;;
  --phase2-only)
    phase2
    ;;
  all)
    phase1
    phase2
    phase3
    phase4
    ;;
  *)
    echo "Unknown option: $MODE (expected --skip-phase2, --phase2-only, or no argument)" >&2
    exit 2
    ;;
esac

echo
echo "Summary: $PASS passed, $HARD_FAIL failed (hard requirements only; phase 2 is soft)"
[[ $HARD_FAIL -eq 0 ]]
