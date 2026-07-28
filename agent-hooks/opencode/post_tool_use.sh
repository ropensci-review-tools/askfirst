#!/bin/bash
# askfirst PostToolUse hook — watches tool output for askfirst structured
# signals and annotates them. Must never cause the agent turn to fail.
# askfirst-hook-version: 1

set -euo pipefail

main() {
  local payload
  payload=$(cat)

  local tool_result
  tool_result=$(echo "$payload" | jq -r '.result // ""' 2>/dev/null) || return 0

  if echo "$tool_result" | grep -q 'askfirst::'; then
    local signal_line
    signal_line=$(echo "$tool_result" | grep 'askfirst::' | head -1)
    echo "[askfirst-annotation: detected structured signal: $signal_line]"
  fi
}

main 2>/dev/null || true
