#!/bin/bash
# generate-install-hooks.sh — regenerates the embedded SESSION_HOOK/POST_HOOK/
# USER_PROMPT_HOOK/PLUGIN_HOOK heredoc bodies in install-agent-hooks.sh from
# their canonical agent-hooks/ source files.
#
# As of stage 017, agent-hooks/claude/ and agent-hooks/opencode/ are NOT
# byte-identical to each other -- that invariant held only while opencode's
# mechanism was a (very likely non-functional) shell-script family mirroring
# Claude Code's. opencode's real mechanism is now a JS plugin
# (agent-hooks/opencode/askfirst-plugin.js), spliced from its own
# independent source, separate from the three Claude Code shell scripts.
#
# Run this after editing agent-hooks/claude/{session_start,post_tool_use,
# user_prompt_submit}.sh or agent-hooks/opencode/askfirst-plugin.js, then
# commit the regenerated install-agent-hooks.sh alongside the agent-hooks/
# change.
#
# This script only ever touches tools/ and agent-hooks/ -- it has no
# knowledge of, or dependency on, any specific language binding.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$REPO_ROOT/tools/install-agent-hooks.sh"
SESSION_SRC="$REPO_ROOT/agent-hooks/claude/session_start.sh"
POST_SRC="$REPO_ROOT/agent-hooks/claude/post_tool_use.sh"
USER_PROMPT_SRC="$REPO_ROOT/agent-hooks/claude/user_prompt_submit.sh"
PLUGIN_SRC="$REPO_ROOT/agent-hooks/opencode/askfirst-plugin.js"

for f in "$INSTALLER" "$SESSION_SRC" "$POST_SRC" "$USER_PROMPT_SRC" "$PLUGIN_SRC"; do
  if [[ ! -f "$f" ]]; then
    echo "error: expected file not found: $f" >&2
    exit 1
  fi
done

tmp=$(mktemp)

awk -v session_file="$SESSION_SRC" -v post_file="$POST_SRC" -v user_prompt_file="$USER_PROMPT_SRC" -v plugin_file="$PLUGIN_SRC" '
  $0 ~ /<<.SESSION_HOOK.$/ {
    print
    while ((getline line < session_file) > 0) print line
    close(session_file)
    skip = "SESSION_HOOK"
    next
  }
  $0 ~ /<<.POST_HOOK.$/ {
    print
    while ((getline line < post_file) > 0) print line
    close(post_file)
    skip = "POST_HOOK"
    next
  }
  $0 ~ /<<.USER_PROMPT_HOOK.$/ {
    print
    while ((getline line < user_prompt_file) > 0) print line
    close(user_prompt_file)
    skip = "USER_PROMPT_HOOK"
    next
  }
  $0 ~ /<<.PLUGIN_HOOK.$/ {
    print
    while ((getline line < plugin_file) > 0) print line
    close(plugin_file)
    skip = "PLUGIN_HOOK"
    next
  }
  skip != "" {
    if ($0 == skip) { print; skip = "" }
    next
  }
  { print }
' "$INSTALLER" > "$tmp"

mv "$tmp" "$INSTALLER"
chmod +x "$INSTALLER"

echo "regenerated: $INSTALLER (from $SESSION_SRC, $POST_SRC, $USER_PROMPT_SRC, $PLUGIN_SRC)" >&2
