#!/bin/bash
# askfirst UserPromptSubmit hook — clears any pending stop-and-ask
# sentinels at the start of each new user turn, on the theory that a new
# user message means the user has had the chance to respond/redirect. Does
# NOT clear unresolved-notice/ -- that marker isn't waiting on a human
# answer, it's waiting on the agent's own askfirst_check_scenarios() call,
# so a new user turn must leave it untouched. Must never cause the turn to
# fail.
#
# CONCRETE FINDING (stage 016, opencode only -- this note is kept in both
# copies since agent-hooks/claude/ and agent-hooks/opencode/ are kept
# byte-identical): see the matching comment in `post_tool_use.sh` --
# opencode's real plugin API is a JS/TS `Hooks` object registered via
# `opencode.json`'s `plugin` array and executed in-process, not a shell
# script reading JSON from stdin. The opencode copy of this file is very
# likely never actually invoked by real opencode; kept as a best-effort
# placeholder pending a real JS/TS plugin implementation. Does not apply to
# the Claude Code side.
#
# State lives under a session-scoped tmp directory, not the project's
# working tree -- see the matching comment/mangling scheme in
# `post_tool_use.sh` (kept identical here so both hooks derive the same
# path from the same `cwd` payload field, if this script is ever actually
# invoked on the opencode side).
# askfirst-hook-version: 4

askfirst_state_dir() {
  local cwd="$1"
  local mangled
  mangled=$(printf '%s' "$cwd" | sed 's#^/##; s#/#_#g')
  printf '%s/askfirst/%s' "${TMPDIR:-/tmp}" "$mangled"
}

main() {
  local payload
  payload=$(cat)

  local cwd
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
  [[ -n "$cwd" ]] || cwd="."

  local state_dir
  state_dir=$(askfirst_state_dir "$cwd")

  rm -rf "$state_dir/pending"
}

main 2>/dev/null || true
