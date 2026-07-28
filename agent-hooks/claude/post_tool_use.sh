#!/bin/bash
# askfirst PostToolUse hook — actively blocks every subsequent tool call
# while an unresolved stop-and-ask sentinel is pending (Claude Code's
# PostToolUse blocking convention: exit code 2, reason on stderr), passively
# surfaces/clears any queued notice-level annotations, and (non-blocking)
# escalates a reminder on file-modifying tool calls while a notice for some
# package has never been followed up with askfirst_check_scenarios(). Only
# ever exits non-zero deliberately, to block on a pending sentinel -- any
# other failure (e.g. jq missing, no payload) falls through to a clean exit
# 0. The exit-code-2/stderr-as-reason convention is confirmed for Claude
# Code; opencode has no documented shell-hook equivalent (its plugin API is
# a separate JS/TS tool.execute.before/after interface with no documented
# blocking-result semantics as of this writing), so the opencode copy of
# this file uses the same convention as a best-effort fallback, unverified
# against opencode itself.
#
# CONCRETE FINDING (stage 016, opencode only -- this note is kept in both
# copies since agent-hooks/claude/ and agent-hooks/opencode/ are kept
# byte-identical): opencode's real plugin API (`@opencode-ai/plugin`) is a
# JS/TS `Hooks` object -- `tool.execute.before`/`tool.execute.after` etc. --
# registered via `opencode.json`'s `plugin` array (a list of module file
# paths) and executed in-process by opencode itself. There is no
# `.opencode/hooks/*.sh`-style shell-script-reading-JSON-from-stdin
# convention anywhere in that SDK's type definitions. The opencode copy of
# this file is therefore very likely never actually invoked by real
# opencode at all -- a stronger finding than the "unverified fallback" label
# above, kept as a best-effort placeholder (in case some undocumented
# shell-hook path does exist) rather than removed, but not to be trusted to
# provide any of this mechanism's guarantees for opencode until a real
# JS/TS plugin is built and verified. This finding does not apply to the
# Claude Code side, which is confirmed via the exit-code-2 convention
# above. See this stage's design-decisions.md for the follow-up this
# should become.
#
# All state (pending/, log, unresolved-notice/) lives under a session-scoped
# tmp directory, not the project's working tree -- computed here from the
# same mangling scheme as `askfirst_state_dir()`/`askfirst_mangle_path()` in
# the R package's `bindings/r/R/state.R`, so both processes independently
# derive the identical path from the one thing they share: the project's
# working directory (`getwd()` on the R side, this payload's `cwd` field
# here). Neither side resolves symlinks -- keep both sides in sync if this
# scheme ever changes.
# askfirst-hook-version: 4

# ASKFIRST_STATE_DIR_START
askfirst_state_dir() {
  local cwd="$1"
  local mangled
  mangled=$(printf '%s' "$cwd" | sed 's#^/##; s#/#_#g')
  printf '%s/askfirst/%s' "${TMPDIR:-/tmp}" "$mangled"
}
# ASKFIRST_STATE_DIR_END

main() {
  local payload
  payload=$(cat)

  local cwd
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
  [[ -n "$cwd" ]] || cwd="."

  local state_dir
  state_dir=$(askfirst_state_dir "$cwd")

  local pending_dir="$state_dir/pending"
  if [[ -d "$pending_dir" ]]; then
    shopt -s nullglob
    local pending_files=("$pending_dir"/*.txt)
    shopt -u nullglob
    if [[ ${#pending_files[@]} -gt 0 ]]; then
      cat "${pending_files[@]}" >&2
      exit 2
    fi
  fi

  local log_file="$state_dir/log"
  if [[ -f "$log_file" ]]; then
    echo "[askfirst-annotation:]"
    cat "$log_file"
    rm -f "$log_file"
  fi

  local tool_name
  tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool_name" in
    Edit|Write|NotebookEdit)
      local notice_dir="$state_dir/unresolved-notice"
      if [[ -d "$notice_dir" ]]; then
        shopt -s nullglob
        local notice_files=("$notice_dir"/*.txt)
        shopt -u nullglob
        if [[ ${#notice_files[@]} -gt 0 ]]; then
          local count_dir="$state_dir/unresolved-notice-count"
          mkdir -p "$count_dir"
          echo "[askfirst-unresolved-notice-reminder:]"
          local f pkg count_file count
          for f in "${notice_files[@]}"; do
            pkg=$(basename "$f" .txt)
            count_file="$count_dir/$pkg.txt"
            count=0
            [[ -f "$count_file" ]] && count=$(cat "$count_file" 2>/dev/null)
            [[ "$count" =~ ^[0-9]+$ ]] || count=0
            count=$((count + 1))
            echo "$count" > "$count_file"
            if (( count >= 3 )); then
              # ASKFIRST_REMINDER_LEVEL2_START
              printf 'REPEATED reminder (%dx): the notice from %s has now gone unaddressed across multiple edits. This is not optional -- call askfirst::askfirst_check_scenarios("%s") now, before making any further edits that could duplicate, wrap, or extend functionality already provided by %s, or tell the user explicitly that this edit is unrelated to %s.\n\n' "$count" "$pkg" "$pkg" "$pkg" "$pkg"
              # ASKFIRST_REMINDER_LEVEL2_END
            else
              # ASKFIRST_REMINDER_LEVEL1_START
              printf 'A notice from %s is still open this session -- askfirst::askfirst_check_scenarios("%s") has not been called. If this edit duplicates, wraps, or extends functionality already provided by %s, call askfirst::askfirst_check_scenarios("%s") before proceeding.\n\n' "$pkg" "$pkg" "$pkg" "$pkg"
              # ASKFIRST_REMINDER_LEVEL1_END
            fi
          done
        fi
      fi
      ;;
  esac

  exit 0
}

main
