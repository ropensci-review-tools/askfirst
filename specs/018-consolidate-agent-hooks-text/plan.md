---
created: 2026-07-28T17:11:56Z
agent: claude-sonnet-5
git_hash: 410c1b799c3ef5a7210681bbe1743ed4b7dd1e67
---

# Plan: consolidate-agent-hooks-text

## Overview
Remove redundant text hand-duplicated across agent-hooks/claude/*.sh and agent-hooks/opencode/askfirst-plugin.js: the <askfirst-context> prose block, the escalation-reminder wording strings, and the askfirst_state_dir() path-mangling function (the latter also duplicated within Claude Code's own post_tool_use.sh and user_prompt_submit.sh). Introduce new plain-text/data canonical source files under agent-hooks/, and extend generate-install-hooks.sh to splice them into the per-tool canonical files (agent-hooks/claude/*.sh, agent-hooks/opencode/askfirst-plugin.js) before those are in turn spliced into install-agent-hooks.sh, so installed artifacts remain single-file/dependency-free while eliminating hand-duplication at the source level. Additionally, merge the repo-root tools/ directory into agent-hooks/: tools/ contains exactly two files (install-agent-hooks.sh, generate-install-hooks.sh), both used solely in service of agent-hooks/ content, so they move there rather than remaining a separate top-level directory with no other purpose.

## Context

This stage is a direct hygiene follow-up to stage 017 (add-opencode-plugin),
which introduced `agent-hooks/opencode/askfirst-plugin.js` as a hand-written
JS port of content that already existed in `agent-hooks/claude/*.sh`. Three
distinct pieces of content were duplicated by hand at that time, rather
than shared:

- The `<askfirst-context>` prose block (~120 lines) — present verbatim (down
  to identical wording) in both `agent-hooks/claude/session_start.sh`'s bash
  heredoc and `agent-hooks/opencode/askfirst-plugin.js`'s JS template
  literal.
- The escalation-reminder wording (two variants: a level-1 nudge and a
  level-2 "REPEATED" wording introduced in stage 016) — present in both
  `agent-hooks/claude/post_tool_use.sh` (bash `printf` with `%s`
  placeholders) and `agent-hooks/opencode/askfirst-plugin.js` (JS template
  literals with `${pkg}` placeholders).
- The `askfirst_state_dir()`/path-mangling logic (stage 016's tmp-root
  relocation scheme: strip a leading `/`, replace remaining `/` with `_`,
  join under `${TMPDIR:-/tmp}/askfirst/<mangled>`) — present *three* times:
  once each in `agent-hooks/claude/post_tool_use.sh` and
  `agent-hooks/claude/user_prompt_submit.sh` (identical bash function
  bodies, duplicated within Claude Code's own file family for no functional
  reason), and again as a JS port in `askfirst-plugin.js`.

**Directory merge, added mid-planning**: `tools/` currently contains exactly
two files — `install-agent-hooks.sh` (the installer, shipped to end users
via a symlink from the R package's `inst/`) and `generate-install-hooks.sh`
(a dev-only generation script, never shipped). Both exist solely to
support `agent-hooks/` content; nothing else in the repo uses `tools/` for
any unrelated purpose. `bindings/r/inst/` currently holds *two separate*
top-level symlinks into the repo root: `agent-hooks -> ../../../agent-hooks`
and `install-agent-hooks.sh -> ../../../tools/install-agent-hooks.sh`.
`bindings/r/R/install_hooks.R` locates the installer at runtime via
`system.file("install-agent-hooks.sh", package = "askfirst")`, independent
of the symlink's target directory name. Numerous literal path references
to `tools/install-agent-hooks.sh` (documentation strings, a human-directed
nudge message, vignette code blocks, comments, and
`test-install-agent-hooks.R`'s `find_repo_root()` check) exist across
`bindings/r/R/{init,install_hooks,hooks_status}.R`,
`bindings/r/vignettes/{using-askfirst,askfirst-development}.Rmd`,
`bindings/r/tests/testthat/test-install-agent-hooks.R`, and
`agent-hooks/manifest.json`'s own `_comment` field — confirmed via a
repo-wide grep; no CI workflow or `DESCRIPTION`/`.Rbuildignore` entry
references `tools/` at all, so the move is self-contained to the files
already identified.

**Naming, considered and rejected during plan review**: whether `agent-hooks/`
(and the "hooks" terminology running through the public R API —
`askfirst_install_agent_hooks()`, `askfirst_hooks_status()`,
`askfirst_hooks_manifest()`, `hooks_dir`/`marker_file` in
`manifest.json`) is still the right name, given opencode's own delivery
format is called a "plugin" and future tools may use neither term. Kept
as-is: both Claude Code's hooks and opencode's plugin are, at the level of
what they actually implement, hook-shaped extension points (opencode's own
SDK types the object every plugin returns as `Hooks`) — "hooks" describes
that shared concept accurately for both tools that exist today. "Plugin"
describes only opencode's *delivery* format (a loaded file vs. a
registered script), not a different underlying mechanism. A rename was
explicitly not pursued now, both because "hooks" isn't actually wrong yet
and because the blast radius (the public R API, not just the directory
name) is large enough to warrant its own dedicated future stage if a
genuinely non-hook-shaped tool integration ever makes the term stop
fitting.

Relevant prior decisions this stage must not contradict:

- **Stage 012**: established `tools/generate-install-hooks.sh` as a
  dev-time generation script that splices canonical `agent-hooks/`
  source files into `tools/install-agent-hooks.sh`'s embedded heredocs,
  specifically to eliminate a different kind of drift (the installer
  silently missing fixes present in the canonical source). This stage
  extends that same splicing pattern one layer earlier, rather than
  inventing a new mechanism.
- **Stage 017, Design Goal 2**: `askfirst-plugin.js` must remain a single,
  dependency-free file installable with no `node_modules` or build step at
  *install* time. This stage's generation step runs at *dev* time only
  (before a change is committed), exactly like `generate-install-hooks.sh`
  already does — it must not introduce any new runtime dependency for
  either installed artifact (the installed `.claude/hooks/*.sh` files or
  `.opencode/plugins/askfirst-plugin.js`).
- **Stage 017's own header comment** on `tools/generate-install-hooks.sh`:
  already documents that `agent-hooks/claude/` and `agent-hooks/opencode/`
  are *not* byte-identical (unlike the pre-017 shell-script-only era) —
  this stage does not reopen that; the two remain genuinely different
  files in different languages, only their *shared prose/data content* is
  deduplicated, not their surrounding code structure.

## Design Goals

1. **Eliminate the `<askfirst-context>` prose duplication first**, since
   it's the largest block or content (~120 lines) and the one most likely
   to drift silently out of sync if edited in only one place — a
   maintainer fixing wording in `session_start.sh` has no automated signal
   today that `askfirst-plugin.js`'s copy also needs the identical edit.
2. **Eliminate the escalation-reminder wording duplication** the same way,
   using a placeholder token neutral to both bash's `%s` and JS's
   `${pkg}` substitution syntax, translated by the generation step into
   each target's native placeholder form.
3. **Eliminate the *bash-internal* duplication of `askfirst_state_dir()`**
   between `post_tool_use.sh` and `user_prompt_submit.sh` — this pair is
   the same language or, with no cross-language translation problem at
   all; a single canonical bash source spliced into both closes a
   duplication that had no justification to begin with.
4. **Do not force a single literal source for the JS port of
   `askfirst_state_dir()`.** Bash and JS cannot execute the same function
   body; attempting genuine code-generation for a ~3-line utility (strip
   leading `/`, replace `/` with `_`) would be disproportionate machinery
   for the size of the thing being shared. Instead, keep the JS
   implementation as a manually-ported function, but establish a shared
   *behavioral contract* — a single fixture file of example
   input/output path pairs consumed by both the bash test suite (if any
   exists for these scripts) and the existing `askfirst-plugin.test.js`
   suite — so the two implementations are verified equivalent even though
   their source code isn't literally shared. (Confirm this scoping
   decision with the user before implementation — see Open Questions.)
5. **Keep the dev workflow change minimal and consistent with stage
   012's existing pattern**: a maintainer edits the new shared source
   files under `agent-hooks/`, runs the (extended, and relocated)
   `generate-install-hooks.sh`, and commits the regenerated canonical
   per-tool files alongside the regenerated `install-agent-hooks.sh` — the
   same commit discipline already documented in that script's own header
   comment.
6. **Merge `tools/` into `agent-hooks/`, simplifying the R package's
   `inst/` symlink structure as a direct consequence.** `tools/`'s two
   files exist only to support `agent-hooks/`; collapsing them into one
   directory removes a top-level directory whose sole purpose was hosting
   scripts for a different directory, and — since `bindings/r/inst/agent-hooks`
   already symlinks the whole `agent-hooks/` tree — lets the now-redundant
   second symlink (`bindings/r/inst/install-agent-hooks.sh`) be removed
   entirely rather than merely repointed, with `install_hooks.R`'s
   `system.file()` call updated to look inside the already-symlinked
   `agent-hooks/` subdirectory instead.

## Proposed Approach

- **Directory merge, done first** (a simple, low-risk mechanical move,
  ahead of the text-consolidation work so the latter only ever touches
  files at their final location):
  - Move `tools/install-agent-hooks.sh` → `agent-hooks/install-agent-hooks.sh`
    and `tools/generate-install-hooks.sh` → `agent-hooks/generate-install-hooks.sh`;
    remove the now-empty `tools/` directory.
  - Update every literal `tools/install-agent-hooks.sh` /
    `tools/generate-install-hooks.sh` path reference to the new location:
    `bindings/r/R/init.R`, `bindings/r/R/install_hooks.R`,
    `bindings/r/R/hooks_status.R` (including the human-directed nudge
    message text `askfirst_init()` actually prints, not just comments),
    `bindings/r/vignettes/using-askfirst.Rmd`,
    `bindings/r/vignettes/askfirst-development.Rmd`,
    `bindings/r/tests/testthat/test-install-agent-hooks.R` (including
    `find_repo_root()`'s existence check, which simplifies once both
    conditions point inside `agent-hooks/`), and `agent-hooks/manifest.json`'s
    `_comment` field.
  - Remove the now-redundant `bindings/r/inst/install-agent-hooks.sh`
    symlink entirely (the file it points to now lives inside
    `agent-hooks/`, already covered by the existing
    `bindings/r/inst/agent-hooks -> ../../../agent-hooks` symlink). Update
    `install_hooks.R`'s two `system.file("install-agent-hooks.sh", package
    = "askfirst")` calls to `system.file("agent-hooks", "install-agent-hooks.sh",
    package = "askfirst")`.
  - Update `generate-install-hooks.sh`'s own internal path variables
    (`REPO_ROOT`-relative references to the installer and to
    `agent-hooks/claude/*.sh`/`agent-hooks/opencode/askfirst-plugin.js`)
    to reflect both files now living in the same directory.
- **New canonical source files** under `agent-hooks/` (exact names to be
  finalized during implementation):
  - `agent-hooks/askfirst-context.txt` — the `<askfirst-context>` prose
    block, verbatim, as currently duplicated between `session_start.sh`
    and `askfirst-plugin.js`.
  - `agent-hooks/askfirst-reminder-messages.txt` (or a small structured
    format, e.g. two clearly-delimited sections) — the level-1 and
    "REPEATED" level-2 escalation wording, using a neutral placeholder
    token (e.g. `{{PKG}}`) in place of bash's `%s` or JS's `${pkg}`.
  - `agent-hooks/askfirst-state-dir.sh` — the canonical bash function body
    for `askfirst_state_dir()`/mangling, spliced into both
    `agent-hooks/claude/post_tool_use.sh` and
    `agent-hooks/claude/user_prompt_submit.sh`. No equivalent shared file
    for the JS port (see Design Goal 4) unless the user's answer to the
    Open Question below says otherwise.
- **Extend `agent-hooks/generate-install-hooks.sh`** (its new,
  post-merge location) to run an earlier splicing pass, before its
  existing pass:
  1. Splice `askfirst-context.txt` into `session_start.sh`'s heredoc
     region and into `askfirst-plugin.js`'s JS template-literal region
     (escaping backticks/`${` sequences for the JS target, none of which
     are expected to occur in the prose but must be handled defensively).
  2. Splice `askfirst-reminder-messages.txt`'s two wording variants into
     `post_tool_use.sh` (translating `{{PKG}}` → `%s`, reordering into
     `printf`'s positional-argument form) and into `askfirst-plugin.js`
     (translating `{{PKG}}` → `${pkg}`).
  3. Splice `askfirst-state-dir.sh` into both `post_tool_use.sh` and
     `user_prompt_submit.sh`'s `askfirst_state_dir()` function bodies.
  4. Then run the existing pass (splice the now-regenerated
     `agent-hooks/claude/*.sh`/`agent-hooks/opencode/askfirst-plugin.js`
     into `agent-hooks/install-agent-hooks.sh`), unchanged in mechanism.
- **Marker convention for the new splice points**: reuse the same
  quoted-heredoc-style delimiter approach already used for
  `SESSION_HOOK`/`POST_HOOK`/`USER_PROMPT_HOOK`/`PLUGIN_HOOK` (a
  recognizable start/end marker pair the awk-based splicer can find),
  applied now *within* the canonical per-tool files themselves rather
  than only within the installer.
- **Verification**: after implementation, `agent-hooks/claude/*.sh` and
  `agent-hooks/opencode/askfirst-plugin.js`'s prose/wording content must
  be byte-for-byte identical (modulo placeholder syntax) to what they
  contain today — this stage changes *where the content is authored*, not
  the content itself or any observable runtime behavior. Existing tests
  (`test-install-agent-hooks.R`'s embedded-content checks,
  `askfirst-plugin.test.js`'s escalation-wording tests) should continue
  to pass unchanged, since they assert on the final rendered text, not on
  how it was assembled.

## Open Questions

- **Should the JS port of `askfirst_state_dir()` also be derived from a
  shared source, or is a shared behavioral-contract fixture (Design Goal
  4) sufficient?** True cross-language code generation for a ~3-line
  utility function seems disproportionate, but this is ultimately the
  maintainer's call on how far "single shared canonical source" should
  extend for logic (as opposed to prose/text). Needs confirmation before
  implementation locks in the lighter-weight approach.
- **Exact file format for `askfirst-reminder-messages.txt`** — plain text
  with a simple delimiter convention (e.g. `--- LEVEL1 ---`/
  `--- LEVEL2 ---` section markers), vs. a small JSON/YAML structure. No
  strong constraint surfaced yet; decide during implementation based on
  how easily the awk-based splicer (already used elsewhere in this
  project) can consume each format.
- **Marker token choice for the new intra-canonical-file splice points**
  (e.g. `<<'CONTEXT_BLOCK'`-style vs. a simpler comment-pair convention
  like `# BEGIN-ASKFIRST-CONTEXT` / `# END-ASKFIRST-CONTEXT`) — the
  existing heredoc-marker convention works well for
  `agent-hooks/install-agent-hooks.sh` (which is itself a shell script
  hosting heredocs), but `askfirst-plugin.js` is not a shell script, so its
  splice markers will need a JS-comment-compatible form instead. Finalize
  during implementation.
- **Whether to also deduplicate the `# askfirst-hook-version: <N>` /
  `// askfirst-hook-version: <N>` marker line itself** (currently a
  separately-maintained literal in every hook/plugin file) as part of this
  same generation pass, since it's another small piece of text kept in
  sync by hand across all four files today — raised here as a possible
  extension of this stage's scope, not yet decided.
