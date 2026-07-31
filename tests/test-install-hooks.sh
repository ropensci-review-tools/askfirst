#!/usr/bin/env bash
# tests/test-install-hooks.sh — end-to-end tests for the askfirst agent-hooks
# installer and its root-level entry points (install.sh, install.ps1).
#
# Usage:
#   tests/test-install-hooks.sh   # run all 6 phases

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$REPO_ROOT/agent-hooks/install-agent-hooks.sh"
INSTALL_SH="$REPO_ROOT/install.sh"
INSTALL_PS1="$REPO_ROOT/install.ps1"

PASS=0
HARD_FAIL=0
SKIP=0

log_pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

log_fail() {
  echo "FAIL: $1" >&2
  HARD_FAIL=$((HARD_FAIL + 1))
}

log_skip() {
  echo "SKIP: $1"
  SKIP=$((SKIP + 1))
}

# Portable substitute for GNU coreutils' `timeout` -- not preinstalled on
# macOS, whose BSD userland doesn't include it. Runs "$@" in the
# background, kills it with SIGKILL if still running after $1 seconds, and
# returns 124 in that case to match GNU timeout's own convention (the only
# caller, phase6, checks for exactly that).
run_with_timeout() {
  local secs="$1"
  shift
  "$@" &
  local cmd_pid=$!
  (
    sleep "$secs"
    kill -9 "$cmd_pid" 2>/dev/null
  ) &
  local watcher_pid=$!
  wait "$cmd_pid" 2>/dev/null
  local status=$?
  kill "$watcher_pid" 2>/dev/null
  wait "$watcher_pid" 2>/dev/null
  if [[ $status -eq 137 ]]; then
    return 124
  fi
  return "$status"
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

# Prints "ok" if $1/.opencode/plugins/askfirst-plugin.js exists, otherwise a
# "missing: ..." line.
check_opencode_installed() {
  local dir="$1"
  if [[ -f "$dir/.opencode/plugins/askfirst-plugin.js" ]]; then
    echo "ok"
  else
    echo "missing: .opencode/plugins/askfirst-plugin.js"
  fi
}

# Phase 1: direct-script install.
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

# Phase 2: install.sh live-fetch.
phase2() {
  local dir problems
  dir="$(make_scratch_dir)"
  if ! (cd "$dir" && bash "$INSTALL_SH" --tool claude) >/dev/null 2>&1; then
    log_fail "phase 2 (install.sh live-fetch): install.sh exited non-zero"
    return
  fi
  problems="$(check_hooks_installed "$dir")"
  if [[ "$problems" == "ok" ]]; then
    log_pass "phase 2 (install.sh live-fetch)"
  else
    log_fail "phase 2 (install.sh live-fetch):
$problems"
  fi
}

# Phase 3: R function vs. script comparison.
phase3() {
  local dir_r dir_script

  # Always (re)install, never conditionally on "is askfirst already
  # installed" -- CI's r-lib/actions/setup-r-dependencies@v2 step caches the
  # R library across runs, so a stale askfirst build from a previous run
  # (predating whatever's actually being tested right now) could otherwise
  # silently be what this phase compares against.
  if ! R CMD INSTALL --no-docs --no-byte-compile --no-test-load "$REPO_ROOT/bindings/r" >/dev/null 2>&1; then
    log_fail "phase 3 (R function vs. script comparison): R CMD INSTALL bindings/r failed"
    return
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

  # Compared with CRLF stripped (tr -d '\r', not dos2unix -- portable across
  # all three OSes' bash environments without requiring an extra binary that
  # isn't guaranteed present on macOS or Windows Git Bash) so a stray line-
  # ending difference between the two invocation paths can't produce a false
  # positive here; the .gitattributes normalization to LF is the real fix,
  # this is defense-in-depth.
  local diffs=""
  for f in askfirst-session-start.sh askfirst-post-tool-use.sh askfirst-user-prompt-submit.sh; do
    local d
    d="$(diff -u <(tr -d '\r' <"$dir_r/.claude/hooks/$f") <(tr -d '\r' <"$dir_script/.claude/hooks/$f") 2>&1)"
    if [[ -n "$d" ]]; then
      diffs="$diffs
.claude/hooks/$f differs between the R function and the direct script:
$d"
    fi
  done
  local settings_diff
  settings_diff="$(diff -u <(jq -S .hooks "$dir_r/.claude/settings.json" | tr -d '\r') <(jq -S .hooks "$dir_script/.claude/settings.json" | tr -d '\r') 2>&1)"
  if [[ -n "$settings_diff" ]]; then
    diffs="$diffs
.hooks section of .claude/settings.json differs between the R function and the direct script:
$settings_diff"
  fi

  if [[ -z "$diffs" ]]; then
    log_pass "phase 3 (R function vs. script comparison)"
  else
    log_fail "phase 3 (R function vs. script comparison):$diffs"
  fi
}

# Phase 4: install.ps1 install via pwsh pwsh (PowerShell Core) is preinstalled
# on ubuntu-latest, macos-latest, and windows-latest GitHub-hosted runners, so
# this phase is not Windows-only.
phase4() {
  local dir problems
  if ! command -v pwsh >/dev/null 2>&1; then
    log_skip "phase 4 (install.ps1 via pwsh): pwsh not found on PATH -- cannot run this phase locally, but it is preinstalled on ubuntu-latest, macos-latest, and windows-latest GitHub-hosted runners"
    return
  fi
  dir="$(make_scratch_dir)"
  if ! (cd "$dir" && pwsh -NoProfile -NonInteractive -File "$INSTALL_PS1" --tool claude) >/dev/null 2>&1; then
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

# Phase 5: install-all-detected -- seeds both a claude and an opencode marker
# in the same scratch dir, runs the installer with no --tool, and asserts hooks
# are installed for both (stage 025's detect-and-install-all behavior,
# replacing the installer's old single-choice "multiple tools detected"
# prompt).
phase5() {
  local dir output problems_claude problems_opencode
  dir="$(mktemp -d)"
  mkdir -p "$dir/.claude" "$dir/.opencode"
  echo '{}' >"$dir/.claude/settings.json"
  output="$(cd "$dir" && "$INSTALLER" 2>&1)"
  if [[ $? -ne 0 ]]; then
    log_fail "phase 5 (install-all-detected): install-agent-hooks.sh exited non-zero:
$output"
    return
  fi
  problems_claude="$(check_hooks_installed "$dir")"
  problems_opencode="$(check_opencode_installed "$dir")"
  if [[ "$problems_claude" == "ok" && "$problems_opencode" == "ok" ]] \
    && echo "$output" | grep -q "installed for claude" \
    && echo "$output" | grep -q "installed for opencode"; then
    log_pass "phase 5 (install-all-detected)"
  else
    log_fail "phase 5 (install-all-detected):
$problems_claude
$problems_opencode"
  fi
}

# Phase 6: no tool detected, stdin not a terminal -- models the `curl
# install.sh | bash` invocation shape (stdin is the piped script, not a
# terminal). Must fail clearly and quickly, not hang on a broken interactive
# prompt.
phase6() {
  local dir output status
  dir="$(mktemp -d)"
  output="$(cd "$dir" && run_with_timeout 10 "$INSTALLER" </dev/null 2>&1)"
  status=$?
  if [[ $status -eq 124 ]]; then
    log_fail "phase 6 (no detection, non-tty stdin): install-agent-hooks.sh hung (timed out)"
    return
  fi
  if [[ $status -eq 0 ]]; then
    log_fail "phase 6 (no detection, non-tty stdin): install-agent-hooks.sh exited 0 (expected non-zero):
$output"
    return
  fi
  if echo "$output" | grep -q "could not detect an agent tool" \
    && echo "$output" | grep -q "claude" \
    && echo "$output" | grep -q "opencode"; then
    log_pass "phase 6 (no detection, non-tty stdin)"
  else
    log_fail "phase 6 (no detection, non-tty stdin): unexpected output:
$output"
  fi
}

phase1
phase2
phase3
phase4
phase5
phase6

echo
echo "Summary: $PASS passed, $HARD_FAIL failed, $SKIP skipped"
[[ $HARD_FAIL -eq 0 ]]
