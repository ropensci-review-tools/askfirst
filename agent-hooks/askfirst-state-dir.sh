# Mangles cwd into a directory-name-safe string: normalizes backslashes to
# /, strips a leading / (the POSIX root marker), replaces remaining / with
# _, and strips drive-letter colons -- so a Windows-style absolute path
# (e.g. C:/Users/... or C:\Users\...) mangles to a filesystem-safe segment
# instead of leaving a literal : embedded in it (stage 020; kept
# byte-identical to bindings/r/R/state.R's askfirst_mangle_path() and
# agent-hooks/opencode/askfirst-plugin.js's askfirstMangleTermPath(), per
# the shared agent-hooks/askfirst-state-dir-fixture.txt).
askfirst_state_dir() {
  local cwd="$1"
  local mangled
  mangled=$(printf '%s' "$cwd" | sed 's#\\#/#g; s#^/##; s#/#_#g; s#:##g')
  printf '%s/askfirst/%s' "${TMPDIR:-/tmp}" "$mangled"
}
