#!/bin/bash
# generate-install-hooks.sh — two-layer regeneration pipeline:
#
#   1. Splices shared canonical-content sources (askfirst-context.txt,
#      askfirst-reminder-messages.txt, askfirst-state-dir.sh) into the
#      per-tool canonical files (agent-hooks/claude/*.sh,
#      agent-hooks/opencode/askfirst-plugin.js), which previously
#      hand-duplicated this content across bash and JS (stage 018).
#   2. Splices those now-regenerated per-tool files into
#      install-agent-hooks.sh's embedded SESSION_HOOK/POST_HOOK/
#      USER_PROMPT_HOOK/PLUGIN_HOOK heredoc bodies (stage 012 onward).
#
# As of stage 017, agent-hooks/claude/ and agent-hooks/opencode/ are NOT
# byte-identical to each other -- that invariant held only while opencode's
# mechanism was a (very likely non-functional) shell-script family mirroring
# Claude Code's. opencode's real mechanism is now a JS plugin
# (agent-hooks/opencode/askfirst-plugin.js), spliced from its own
# independent source, separate from the three Claude Code shell scripts.
# What IS shared between them now (stage 018) is prose/data *content*, not
# code structure: the <askfirst-context> block, the escalation-reminder
# wording, and the askfirst_state_dir() mangling logic all come from one
# canonical source each, translated into each target's native syntax by
# this script -- not hand-duplicated.
#
# As of stage 018, this script and install-agent-hooks.sh both live under
# agent-hooks/ itself (moved from a separate top-level tools/ directory,
# which existed solely to hold these two files). This script has no
# knowledge of, or dependency on, any specific language binding.
#
# As of stage 019, askfirst-context.txt's marker-token prose
# ({{HALT_MARKER}}/{{RESUME_MARKER}} placeholders) is rendered from
# agent-content/askfirst-markers.txt -- the same canonical source
# bindings/r/R/conditions.R reads at runtime -- before being spliced into
# the per-tool files, so the literal token values can't drift between what
# askfirst actually emits and what this hook-context prose describes them
# as.
#
# Run this after editing any of: agent-hooks/askfirst-context.txt,
# agent-hooks/askfirst-reminder-messages.txt,
# agent-hooks/askfirst-state-dir.sh, agent-content/askfirst-markers.txt,
# agent-hooks/claude/{session_start,
# post_tool_use,user_prompt_submit}.sh, or
# agent-hooks/opencode/askfirst-plugin.js -- then commit every regenerated
# file together (the per-tool canonical files AND install-agent-hooks.sh).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$REPO_ROOT/agent-hooks/install-agent-hooks.sh"
SESSION_SRC="$REPO_ROOT/agent-hooks/claude/askfirst-session-start.sh"
POST_SRC="$REPO_ROOT/agent-hooks/claude/askfirst-post-tool-use.sh"
USER_PROMPT_SRC="$REPO_ROOT/agent-hooks/claude/askfirst-user-prompt-submit.sh"
PLUGIN_SRC="$REPO_ROOT/agent-hooks/opencode/askfirst-plugin.js"
CONTEXT_SRC="$REPO_ROOT/agent-hooks/askfirst-context.txt"
REMINDER_SRC="$REPO_ROOT/agent-hooks/askfirst-reminder-messages.txt"
STATE_DIR_SRC="$REPO_ROOT/agent-hooks/askfirst-state-dir.sh"
MARKERS_SRC="$REPO_ROOT/agent-content/askfirst-markers.txt"

for f in "$INSTALLER" "$SESSION_SRC" "$POST_SRC" "$USER_PROMPT_SRC" "$PLUGIN_SRC" \
  "$CONTEXT_SRC" "$REMINDER_SRC" "$STATE_DIR_SRC" "$MARKERS_SRC"; do
  if [[ ! -f "$f" ]]; then
    echo "error: expected file not found: $f" >&2
    exit 1
  fi
done

# Replaces the region between two literal marker lines in $1 (a file) with
# the content of $4 (a file), indenting each inserted line to match the
# marker line's own leading whitespace. $5 selects whether the marker
# lines themselves are part of the replaced content ("inclusive" -- used
# for the <askfirst-context>/</askfirst-context> tags, which are the
# content's own delimiters) or preserved around it ("exclusive" -- used
# for synthetic ASKFIRST_*_START/_END comment markers).
splice_between_markers() {
  local target="$1" start_pat="$2" end_pat="$3" content_file="$4" mode="$5"
  local out; out=$(mktemp)
  awk -v start="$start_pat" -v endp="$end_pat" -v cfile="$content_file" -v mode="$mode" '
    !skip && $0 ~ ("^[ \t]*" start "[ \t]*$") {
      match($0, /^[ \t]*/)
      indent = substr($0, RSTART, RLENGTH)
      if (mode == "exclusive") print
      while ((getline line < cfile) > 0) print indent line
      close(cfile)
      skip = 1
      next
    }
    skip && $0 ~ ("^[ \t]*" endp "[ \t]*$") {
      if (mode == "exclusive") print
      skip = 0
      next
    }
    skip { next }
    { print }
  ' "$target" > "$out"
  mv "$out" "$target"
  if [[ "$target" == *.sh ]]; then
    chmod +x "$target"
  fi
}

# Extracts the single-line message body immediately following a
# "--- LEVELn ---" section marker in askfirst-reminder-messages.txt.
extract_reminder_raw() {
  local level="$1"
  awk -v marker="--- ${level} ---" '$0 == marker { getline; print; exit }' "$REMINDER_SRC"
}

# Extracts the single-line token immediately following a "--- NAME ---"
# section marker in agent-content/askfirst-markers.txt (same section-marker
# format as askfirst-reminder-messages.txt; conditions.R's
# askfirst_load_marker() reads the same file at R runtime).
extract_marker_raw() {
  local name="$1"
  awk -v marker="--- ${name} ---" '$0 == marker { getline; print; exit }' "$MARKERS_SRC"
}

# Renders a canonical {{PKG}}/{{COUNT}}-templated message as a single-line
# bash `printf` call, reconstructing the positional argument list in the
# order placeholders appear (so the rendered *output* text is identical to
# the original hand-written two-line printf + continuation form, even
# though the generated source is formatted differently -- see this
# stage's tasks.md, T018-11, for why source-level formatting isn't held to
# byte-identity here the way the context block and state-dir function are).
render_reminder_bash_line() {
  local raw="$1"
  local fmt="${raw//\{\{COUNT\}\}/%d}"
  fmt="${fmt//\{\{PKG\}\}/%s}"
  local args="" rest="$raw"
  while [[ "$rest" =~ \{\{(COUNT|PKG)\}\} ]]; do
    case "${BASH_REMATCH[1]}" in
      COUNT) args+=' "$count"' ;;
      PKG) args+=' "$pkg"' ;;
    esac
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
  printf "printf '%s'%s\\n" "$fmt" "$args"
}

# Renders the same canonical message as a single-line JS template-literal
# append (no positional reconstruction needed -- JS uses named ${pkg}/
# ${count} interpolation directly).
render_reminder_js_line() {
  local raw="$1"
  local js="${raw//\{\{COUNT\}\}/\${count\}}"
  js="${js//\{\{PKG\}\}/\${pkg\}}"
  printf 'reminder += `%s`;\n' "$js"
}

# --- Pass 1: shared canonical sources -> per-tool canonical files ---

# <askfirst-context> block: render its {{HALT_MARKER}}/{{RESUME_MARKER}}
# placeholders from agent-content/askfirst-markers.txt first (stage 019),
# then splice the rendered copy -- not askfirst-context.txt directly -- into
# each target. bash heredoc takes the rendered text verbatim (backticks are
# not special inside a quoted heredoc); the JS template literal needs every
# literal backtick escaped first.
halt_marker=$(extract_marker_raw HALT)
resume_marker=$(extract_marker_raw RESUME)

context_rendered=$(mktemp)
sed -e "s#{{HALT_MARKER}}#${halt_marker}#g" -e "s#{{RESUME_MARKER}}#${resume_marker}#g" "$CONTEXT_SRC" > "$context_rendered"

splice_between_markers "$SESSION_SRC" '<askfirst-context>' '</askfirst-context>' "$context_rendered" inclusive

context_js_escaped=$(mktemp)
sed 's/`/\\`/g' "$context_rendered" > "$context_js_escaped"
splice_between_markers "$PLUGIN_SRC" '<askfirst-context>' '</askfirst-context>' "$context_js_escaped" inclusive
rm -f "$context_rendered" "$context_js_escaped"

# askfirst_state_dir() mangling function: bash-only canonical source,
# spliced into both Claude Code hook scripts that need it. No JS
# equivalent is generated (see askfirst-plugin.js's own comment on
# askfirstMangleTermPath() -- a manually-maintained, separately-verified
# port, per this stage's Design Goal 4).
splice_between_markers "$POST_SRC" '# ASKFIRST_STATE_DIR_START' '# ASKFIRST_STATE_DIR_END' "$STATE_DIR_SRC" exclusive
splice_between_markers "$USER_PROMPT_SRC" '# ASKFIRST_STATE_DIR_START' '# ASKFIRST_STATE_DIR_END' "$STATE_DIR_SRC" exclusive

# Escalation-reminder wording: one canonical {{PKG}}/{{COUNT}}-templated
# message per level, rendered into each target's native syntax.
level1_raw=$(extract_reminder_raw LEVEL1)
level2_raw=$(extract_reminder_raw LEVEL2)

bash_level1=$(mktemp); render_reminder_bash_line "$level1_raw" > "$bash_level1"
bash_level2=$(mktemp); render_reminder_bash_line "$level2_raw" > "$bash_level2"
js_level1=$(mktemp); render_reminder_js_line "$level1_raw" > "$js_level1"
js_level2=$(mktemp); render_reminder_js_line "$level2_raw" > "$js_level2"

splice_between_markers "$POST_SRC" '# ASKFIRST_REMINDER_LEVEL1_START' '# ASKFIRST_REMINDER_LEVEL1_END' "$bash_level1" exclusive
splice_between_markers "$POST_SRC" '# ASKFIRST_REMINDER_LEVEL2_START' '# ASKFIRST_REMINDER_LEVEL2_END' "$bash_level2" exclusive
splice_between_markers "$PLUGIN_SRC" '// ASKFIRST_REMINDER_LEVEL1_START' '// ASKFIRST_REMINDER_LEVEL1_END' "$js_level1" exclusive
splice_between_markers "$PLUGIN_SRC" '// ASKFIRST_REMINDER_LEVEL2_START' '// ASKFIRST_REMINDER_LEVEL2_END' "$js_level2" exclusive

rm -f "$bash_level1" "$bash_level2" "$js_level1" "$js_level2"

echo "regenerated (pass 1): $SESSION_SRC, $POST_SRC, $USER_PROMPT_SRC, $PLUGIN_SRC (from $CONTEXT_SRC, $REMINDER_SRC, $STATE_DIR_SRC, $MARKERS_SRC)" >&2

# --- Pass 2: per-tool canonical files -> install-agent-hooks.sh ---

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

echo "regenerated (pass 2): $INSTALLER (from $SESSION_SRC, $POST_SRC, $USER_PROMPT_SRC, $PLUGIN_SRC)" >&2
