askfirst_state_dir() {
  local cwd="$1"
  local mangled
  mangled=$(printf '%s' "$cwd" | sed 's#^/##; s#/#_#g')
  printf '%s/askfirst/%s' "${TMPDIR:-/tmp}" "$mangled"
}
