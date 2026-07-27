# Manual Testing Checklist

Automated tests (`tests/testthat/`) mock the underlying env-var/TTY signals
directly and verify `pkghooks`'s own logic (detection, confidence tiering,
condition signaling, registry behavior) deterministically. They **cannot**
verify that a real agent tool's harness actually surfaces the resulting
conditions to the calling LLM — that depends on each tool's own
architecture (raw subprocess capture vs. MCP tool call vs. persistent
session), which is outside `pkghooks`'s control. Use this checklist to
verify against real tools before a release.

## Setup

Build a minimal test package that adopts `pkghooks`:

```r
# In the test package's .onLoad():
.onLoad <- function(libname, pkgname) {
  pkghooks::pkghooks_init(
    pkg = pkgname,
    notice = "If you are an AI coding agent and hit a bug or missing feature in {.pkg {pkgname}}, tell your user to contact the maintainer rather than working around it yourself."
  )
}

# And one exported function that always hits a known limitation:
my_function <- function() {
  pkghooks::flag_capability_gap(
    "mytestpkg",
    "this is a deliberately flagged capability gap for manual testing"
  )
}
```

Install it, then run an R session through each tool below, load the test
package, and call `my_function()`.

## Per-tool checklist

For each row: confirm the load-time notice appears when the package loads,
and the capability-gap condition halts execution with a visible message
when `my_function()` is called, under that tool.

- [ ] Cursor (IDE agent mode) — `cursor`
- [ ] Cursor CLI — `cursor-cli`
- [ ] Gemini CLI — `gemini`
- [ ] Cline — `cline`
- [ ] OpenAI Codex CLI — `codex`
- [ ] Antigravity — `antigravity`
- [ ] Augment CLI — `augment-cli`
- [ ] opencode — `opencode`
- [ ] Goose — `goose`
- [ ] Junie (JetBrains) — `junie`
- [ ] Pi — `pi`
- [ ] Claude Code Cowork — `cowork`
- [ ] Claude Code — `claude`
- [ ] Replit Agent — `replit` (note: `REPL_ID` alone is ambiguous — also
      confirm a *non*-agent Replit workspace does **not** false-positive)
- [ ] GitHub Copilot CLI — `github-copilot`
- [ ] AWS Kiro (CLI agent, not the IDE terminal) — `kiro` (note: also
      confirm Kiro's own IDE-integrated terminal, run by a human, does
      **not** false-positive — this is exactly the `no_tty` disambiguation
      case)
- [ ] openclaw — `openclaw`
- [ ] Devin — `devin`

## Additional scenarios

- [ ] A plain interactive R/RStudio console session (human, no agent) —
      confirm **no** load-time notice fires (low confidence).
- [ ] A human running `Rscript` from a terminal or CI job with no agent
      tool involved — confirm the load-time notice does **not** fire at
      `"high"` confidence; a `"medium"`-confidence notice firing here is
      expected and accepted (ambiguous non-interactive automation), not a
      bug.
- [ ] An uncaught error in the test package's own code, under an agent
      tool from the list above — confirm the `pkghooks_error_redirect`
      notice appears alongside the original error message.
- [ ] The same uncaught-error scenario, but with the test package's own
      code wrapped in a `tryCatch()` somewhere upstream (e.g. inside a
      test runner or an agent tool's own error-catching wrapper) — confirm
      the redirect notice does **not** appear in this case. This is a
      known, accepted limitation of the `options(error = ...)` mechanism
      (see `r/R/init.R`'s documentation of `pkghooks_install_error_handler()`),
      not something to try to "fix" here.
