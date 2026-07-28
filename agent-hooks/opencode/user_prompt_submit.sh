#!/bin/bash
# askfirst UserPromptSubmit hook — clears any pending stop-and-ask
# sentinels at the start of each new user turn, on the theory that a new
# user message means the user has had the chance to respond/redirect.
# Must never cause the turn to fail.
# askfirst-hook-version: 2

main() {
  local payload
  payload=$(cat)

  local cwd
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
  [[ -n "$cwd" ]] || cwd="."

  rm -rf "$cwd/.askfirst/pending"
}

main 2>/dev/null || true
