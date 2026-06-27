# Slice 1: history-transfer

> Project: `v0.1.0`
> Arc: `arc7-import`
> Slice: `slice1-history-transfer`
> Status: planned for CC
> Prior slice: none (first slice of the migration)
> Next slice: `slice2-docs-and-tag` (0.1.0 docs + tag); arc7 docs + the `0.2.0`
> tag are a separate **v0.2.0** project

## Purpose

Relocate the Fezzik formatter engine from `rebar3_lfe` into `fmt` **with full
git history preserved**, and prove it lives correctly in its new home: imported
modules compile, the three Common Test suites pass, and the corpus sweep stays
*meaningful* rather than collapsing to a single fixture.

This slice does **not** rename anything (that is v0.3.0), does **not** place the
docs into the planning tree or create tags (that is slice2), and does **not**
split or publish (that is v0.4.0). Its single job is a faithful, verifiable
transfer.

## Scope

In scope:

- `git filter-repo` extraction of the Fezzik paths (below) from a throwaway
  clone of `rebar3_lfe`, preserving authorship and dates.
- `git merge --allow-unrelated-histories` of that extracted history into `fmt`
  (on a feature branch / worktree).
- Getting the imported `r3lfe_*` modules to compile in `fmt` **under their
  original names**, zero warnings.
- Getting the three imported CT suites to run and pass via `rebar3 ct`.
- **One sanctioned code edit:** re-pointing the corpus-sweep file discovery off
  the absent `<repo>/_integration/**` path onto the `lfe` test-dep's bundled
  corpus, so the sweep exercises a real, portable set of `.lfe` files.

Out of scope:

- Renaming `r3lfe_*` → `lfmt_fezzik*` (v0.3.0).
- Moving the arc1-6 docs into `docs/planning/v0.1.0` and creating the `0.1.0` tag
  (slice2). The arc7 docs + `0.2.0` tag are a separate v0.2.0 project.
- Splitting the renderer, hex publish, `rebar3_lfe` rewire (v0.4.0).
- Any change to `pe_*` modules or `docs/planning/v0.5.0/`.

## What transfers

The `filter-repo` path set (verified against `rebar3_lfe` HEAD):

```text
src/r3lfe_format_lexer.erl
src/r3lfe_format_cst.erl
src/r3lfe_formatter.erl
test/r3lfe_formatter_SUITE.erl
test/r3lfe_format_cst_SUITE.erl
test/r3lfe_format_lexer_SUITE.erl
test/r3lfe_format_lexer_SUITE_data        (incl. tq_corpus.lfe)
docs/design/022-lfe-format                (whole tree — arc1-6 placed in slice2; arc7 by the v0.2.0 project)
```

This slice imports the **full** engine history in one operation (it can't be
scoped to "just the A6 state" — git history is continuous). 29 commits touch the
three core engine files; history runs back to `0f74364` ("Started work on LFE
formatter", 2026-06-15). The later 0.2.0-tip commit rides along in the same
import; the v0.2.0 project tags it and places its arc7 docs. The three modules are
self-contained (they call only each other + stdlib). The
formatter/cst suites use `lfe_io` as an AST-equivalence oracle, so they need the
`lfe` test dep — already present in `fmt`'s `rebar.config`
(`{lfe, "~> 2.2"}`, test profile). The suites are **Common Test**, not eunit.

## The corpus-sweep portability problem (the crux of this slice)

`r3lfe_formatter_SUITE` (`conf_wide_sweep`, `corpus_sweep`) and
`r3lfe_format_cst_SUITE` discover their corpus with:

```erlang
IntDir   = filename:join([TestDir, "..", "_integration"]),
AllFiles = filelib:wildcard(filename:join([IntDir, "**", "*.lfe"])),
```

and assert only `Checked > 0` / `Exercised > 0`. In `rebar3_lfe`, `_integration/`
holds many real `.lfe` files (checkouts, `_build`). **That directory does not
exist in `fmt` and is not imported.** Left as-is, the sweep would pass *hollowly*
over the single bundled `tq_corpus.lfe` — green, but testing ~nothing. That is a
silent-drop, and naming it is the point of this slice.

The fix: re-point discovery at the `lfe` test-dep's bundled corpus via
`code:lib_dir(lfe)` → its `examples/` and `test/` `.lfe` files (the same corpus
`arc2-fidelity` uses: ~20 example files, 3093 lines, plus the test suite
sources). This ships with the dep, is reproducible on any machine, and keeps the
idempotence + token-preservation oracles exercising real LFE. The closing report
must state the resulting file count.

The large-file latency test (`["..", "_integration", "lfe", "test",
"guard_SUITE.lfe"]`) already degrades gracefully ("not found, skipping"); prefer
re-pointing it at `code:lib_dir(lfe)` too, but a disclosed skip is acceptable.

## Success criteria

- The extracted clone contains **exactly** the 8 paths above and their history;
  nothing else.
- After merge, all 29 Fezzik commits are in `fmt`'s DAG with original
  authorship/dates; `git log --follow` works on each imported file back to
  `0f74364`.
- `rebar3 compile` zero-warning with the imported modules under original names.
- `rebar3 ct` green — all three Fezzik suites pass.
- The corpus sweep exercises a disclosed, non-trivial file count (not 1), via
  the `lfe`-dep corpus.
- `rebar3 xref` and `rebar3 dialyzer` clean.
- `pe_*` and `docs/planning/v0.5.0/` are provably untouched by the import.
- No `r3lfe_*` → `lfmt_*` renaming has leaked into this slice; no `0.1.0`/`0.2.0`
  tags created yet.

## Design notes

- `git filter-repo` is **not installed** in this environment — `pipx install
  git-filter-repo` (or `brew install git-filter-repo`) first.
- The Fezzik tip is on `rebar3_lfe`'s **`release/0.5.x`** branch (HEAD `c28de51`
  as of writing), not `main` — clone/merge that branch, and confirm the tip with
  Duncan before extracting (the "better brute" 0.2.0 work may land first).
- Do the import on a `fmt` worktree / feature branch
  (`feature/fezzik-import`) so the main checkout is undisturbed. Worktrees are
  for **isolation only**; the history transfer is `filter-repo` + merge.
- `filter-repo` **rewrites SHAs** — the commit known as `41fcc55` gets a new
  hash. Preserve no old-hash references; slice2 re-locates commits by message
  for tagging.
- Do **not** use `--path-rename` in the extraction; the `r3lfe_* → lfmt_*`
  rename must land as a visible v0.3.0 commit, not be folded into the rewrite.
- This slice is the one place a Fezzik suite is edited for portability; keep the
  edit surgical and behaviour-preserving (discovery source only, not the
  oracles themselves).

## Handoff

When complete, CC provides:

- the import branch with the merge commit (history preserved);
- compile + `ct` + `xref` + `dialyzer` output showing green;
- the corpus-sweep file count under the new discovery, in the closing report;
- a per-row ledger walk with command evidence;
- a caveat section naming any suite that degraded (e.g., a skipped large-file
  latency check) and the exact corpus the sweep now runs over.
