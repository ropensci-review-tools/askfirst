#!/bin/bash
# install-agent-hooks.sh — language-agnostic askfirst hook installer
# Installs SessionStart and PostToolUse hooks for the detected agent tool.
# Usage:
#   install-agent-hooks.sh                    # auto-detect tool
#   install-agent-hooks.sh --tool claude       # force Claude Code
#   install-agent-hooks.sh --tool opencode     # force opencode
#   install-agent-hooks.sh --overwrite         # replace existing files
#   install-agent-hooks.sh --help              # show this message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/agent-hooks"
if [[ ! -d "$HOOKS_DIR" ]]; then
  HOOKS_DIR="$(cd "$SCRIPT_DIR/../agent-hooks" && pwd 2>/dev/null)" || HOOKS_DIR=""
fi
OVERWRITE=false
TOOL=""

usage() {
  sed -n '/^# Usage:/,/^$/{ s/^# //; p; }' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool) TOOL="$2"; shift 2 ;;
    --overwrite) OVERWRITE=true; shift ;;
    --help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

detect_tool() {
  if [[ -n "$TOOL" ]]; then
    echo "$TOOL"
    return
  fi
  if [[ -f ".claude/settings.json" ]]; then
    echo "claude"
  elif [[ -f ".opencode/settings.json" ]]; then
    echo "opencode"
  else
    echo ""
  fi
}

TOOL=$(detect_tool)

if [[ -z "$TOOL" ]]; then
  echo "error: could not detect agent tool — no .claude/ or .opencode/ config found in current directory" >&2
  echo "  Use --tool <name> to specify the tool explicitly." >&2
  exit 1
fi

case "$TOOL" in
  claude)
    TARGET_HOOKS_DIR=".claude/hooks"
    TARGET_CONFIG=".claude/settings.json"
    ;;
  opencode)
    TARGET_HOOKS_DIR=".opencode/hooks"
    TARGET_CONFIG=".opencode/settings.json"
    ;;
  *)
    echo "error: unknown tool '$TOOL' (supported: claude, opencode)" >&2
    exit 1
    ;;
esac

if [[ ! -d "$HOOKS_DIR/$TOOL" ]]; then
  echo "error: no hooks found at $HOOKS_DIR/$TOOL" >&2
  exit 1
fi

mkdir -p "$TARGET_HOOKS_DIR"

copied=0
skipped=0
for hook_script in "$HOOKS_DIR/$TOOL"/*.sh; do
  name=$(basename "$hook_script")
  target="$TARGET_HOOKS_DIR/$name"
  if [[ -f "$target" ]] && [[ "$OVERWRITE" != "true" ]]; then
    echo "  skip: $target (exists, use --overwrite to replace)" >&2
    skipped=$((skipped + 1))
  else
    cp "$hook_script" "$target"
    chmod +x "$target"
    echo "  install: $target" >&2
    copied=$((copied + 1))
  fi
done

if ! command -v jq &>/dev/null; then
  echo "warning: jq not found — cannot auto-register hooks in $TARGET_CONFIG" >&2
  echo "  Register the hooks manually. See the askfirst vignette for details." >&2
  exit 0
fi

register_hooks_claude() {
  local tmp
  tmp=$(mktemp)
  if jq -e '.hooks.SessionStart // empty' "$TARGET_CONFIG" >/dev/null 2>&1; then
    jq '.hooks.SessionStart[0].hooks += [{"type": "command", "command": ".claude/hooks/session_start.sh"}] | .hooks.PostToolUse //= [] | .hooks.PostToolUse += [{"matcher": "Bash|R|Rscript", "hooks": [{"type": "command", "command": ".claude/hooks/post_tool_use.sh"}]}]' "$TARGET_CONFIG" > "$tmp" && mv "$tmp" "$TARGET_CONFIG"
  else
    jq '.hooks.SessionStart += [{"hooks": [{"type": "command", "command": ".claude/hooks/session_start.sh"}]}] | .hooks.PostToolUse //= [] | .hooks.PostToolUse += [{"matcher": "Bash|R|Rscript", "hooks": [{"type": "command", "command": ".claude/hooks/post_tool_use.sh"}]}]' "$TARGET_CONFIG" > "$tmp" && mv "$tmp" "$TARGET_CONFIG"
  fi
}

register_hooks_opencode() {
  local tmp
  tmp=$(mktemp)
  jq '.hooks.SessionStart += [{"hooks": [{"type": "command", "command": ".opencode/hooks/session_start.sh"}]}] | .hooks.PostToolUse //= [] | .hooks.PostToolUse += [{"matcher": "Bash|R|Rscript", "hooks": [{"type": "command", "command": ".opencode/hooks/post_tool_use.sh"}]}]' "$TARGET_CONFIG" > "$tmp" && mv "$tmp" "$TARGET_CONFIG"
}

if [[ -f "$TARGET_CONFIG" ]]; then
  case "$TOOL" in
    claude) register_hooks_claude ;;
    opencode) register_hooks_opencode ;;
  esac
  echo "  register: $TARGET_CONFIG (hooks added)" >&2
else
  echo "  skip: $TARGET_CONFIG not found — hooks installed but not registered" >&2
fi

echo "done: $copied hook(s) installed for $TOOL ($skipped skipped)" >&2
exit 0
