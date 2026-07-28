#!/bin/bash
# askfirst PostToolUse hook — actively blocks every subsequent tool call
# while an unresolved stop-and-ask sentinel is pending (Claude Code's
# PostToolUse blocking convention: exit code 2, reason on stderr), and
# passively surfaces/clears any queued notice-level annotations. Only ever
# exits non-zero deliberately, to block on a pending sentinel -- any other
# failure (e.g. jq missing, no payload) falls through to a clean exit 0.
# The exit-code-2/stderr-as-reason convention is confirmed for Claude Code;
# opencode has no documented shell-hook equivalent (its plugin API is a
# separate JS/TS tool.execute.before/after interface with no documented
# blocking-result semantics as of this writing), so the opencode copy of
# this file uses the same convention as a best-effort fallback, unverified
# against opencode itself.
# askfirst-hook-version: 2

main() {
  local payload
  payload=$(cat)

  local cwd
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
  [[ -n "$cwd" ]] || cwd="."

  local pending_dir="$cwd/.askfirst/pending"
  if [[ -d "$pending_dir" ]]; then
    shopt -s nullglob
    local pending_files=("$pending_dir"/*.txt)
    shopt -u nullglob
    if [[ ${#pending_files[@]} -gt 0 ]]; then
      cat "${pending_files[@]}" >&2
      exit 2
    fi
  fi

  local log_file="$cwd/.askfirst/log"
  if [[ -f "$log_file" ]]; then
    echo "[askfirst-annotation:]"
    cat "$log_file"
    rm -f "$log_file"
  fi

  exit 0
}

main
