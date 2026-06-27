# CC prompt — fmt v0.1.0 · arc7-import / slice1-history-transfer

You are CC. This slice **migrates the Fezzik LFE formatter from `rebar3_lfe`
into `fmt`, preserving full git history**, and proves it lives correctly in its
new home. Fezzik is mature, done work (it went seven arcs in `rebar3_lfe`); this
is a faithful transfer, not new construction. Do **not** rename modules, place
docs, create tags, split, or publish — those are later slices/projects.

Target OTP 28 (matches `fmt`). You operate in the real environment and run
`git` directly (the Cowork sandbox can't mutate git; you can).

## Read first

- `workbench/fezzik-migration-plan.md` — §2 (history mechanism), §3 (commands),
  §1 (inventory).
- `docs/planning/v0.1.0/arc7-import/arc-plan.md`.
- This slice's `slice-doc.md` and `ledger.md`.

Load **collaboration-framework** (ledger discipline — read before writing code,
not as an end-of-slice checklist) and **erlang-guidelines** (`11-anti-patterns`,
then `15-testing`, `17-tooling`).

## Slice focus

> Get Fezzik's three engine modules + three CT suites + lexer fixtures + the
> whole design-docs tree into `fmt` with history intact, compiling and passing
> under their **original `r3lfe_*` names**, with the corpus sweep re-pointed so
> it tests real LFE rather than collapsing to one fixture.

## Step 1 — extract with history (throwaway clone)

`git filter-repo` is likely not installed: `pipx install git-filter-repo` (or
`brew install git-filter-repo`).

The Fezzik tip lives on `rebar3_lfe`'s **`release/0.5.x`** branch (HEAD
`c28de51` as of writing), not `main` — confirm the actual tip with Duncan before
extracting, then clone that branch:

```sh
cd /tmp
git clone --branch release/0.5.x --single-branch \
  /Users/oubiwann/lab/lfe/rebar3_lfe fezzik-extract
cd fezzik-extract
git filter-repo \
  --path src/r3lfe_format_lexer.erl \
  --path src/r3lfe_format_cst.erl \
  --path src/r3lfe_formatter.erl \
  --path test/r3lfe_formatter_SUITE.erl \
  --path test/r3lfe_format_cst_SUITE.erl \
  --path test/r3lfe_format_lexer_SUITE.erl \
  --path test/r3lfe_format_lexer_SUITE_data \
  --path docs/design/022-lfe-format
```

Do **not** pass `--path-rename` — the namespace rename is a v0.3.0 commit, not
part of this rewrite. Verify the extract holds exactly those paths
(`git -C /tmp/fezzik-extract ls-files`) and ~29 commits
(`git -C /tmp/fezzik-extract log --oneline | wc -l`).

## Step 2 — merge into fmt as unrelated history

```sh
cd /Users/oubiwann/lab/lfe/fmt
git worktree add ../fmt-fezzik-import -b feature/fezzik-import
cd ../fmt-fezzik-import
git remote add fezzik /tmp/fezzik-extract
git fetch fezzik
git merge --allow-unrelated-histories fezzik/release/0.5.x \
  -m "Import Fezzik formatter from rebar3_lfe (history preserved)"
git remote remove fezzik
```

Confirm `git log --follow src/r3lfe_formatter.erl` reaches `0f74364` with
original dates. (SHAs are rewritten — that's expected; never reference old
hashes.)

## Step 3 — make it compile + run under original names

The three modules call only each other + stdlib; they should compile directly.
The formatter/cst suites use `lfe_io` (AST-equivalence oracle) — `fmt` already
has `{lfe, "~> 2.2"}` in the test profile, so no `rebar.config` dep change is
needed. Resolve any `warnings_as_errors` friction from `fmt`'s stricter
`erl_opts` (`warn_unused_import`, `warn_export_vars`) without changing
formatter behaviour. Keep modules at their `r3lfe_*` names.

## Step 4 — re-point the corpus sweep (the one sanctioned edit)

`r3lfe_formatter_SUITE` (`conf_wide_sweep`, `corpus_sweep`, the large-file
latency test) and `r3lfe_format_cst_SUITE` discover `.lfe` files under
`<repo>/../_integration/**` and assert only `Checked > 0`. That directory does
**not** exist in `fmt`, so the sweep would pass hollowly over the single bundled
`tq_corpus.lfe`. Re-point discovery at the `lfe` test-dep's bundled corpus:

```erlang
LfeDir   = code:lib_dir(lfe),
Examples = filelib:wildcard(filename:join([LfeDir, "examples", "*.lfe"])),
LfeTests = filelib:wildcard(filename:join([LfeDir, "test", "*.lfe"])),
AllFiles = Examples ++ LfeTests ++ [TqFile],
```

Edit **only the discovery source**, not the idempotence/token-preservation
oracles themselves. `ct:log` the resulting file count and report it. Re-point
the large-file latency test at `code:lib_dir(lfe)` too, or disclose a skip.

## Engineering bar

- `rebar3 compile` zero warnings.
- `rebar3 ct` green (all three Fezzik suites).
- Corpus sweep exercises a disclosed, non-trivial file count (state N).
- `rebar3 xref` clean.
- `rebar3 dialyzer` clean.
- `git diff` shows **no** change to any `pe_*` module or `docs/planning/v0.5.0/`.
- `grep -rn 'lfmt_fezzik' src test` → empty (no rename leaked into this slice).

## Working ledger

Update `ledger.md` as you work. Every row must reach `done`, `deferred`, or
`no-op`; `done` needs command-output evidence. If you must amend scope, raise it
explicitly (Amendments section) rather than silently changing the target. Do not
mark your own rows CDC-verified — that is CDC's pass.

## When done

Hand back:

- the `feature/fezzik-import` branch with the history-preserving merge commit;
- green compile / ct / xref / dialyzer output;
- the corpus-sweep file count under the new discovery;
- the per-row ledger walk with evidence;
- caveats: any degraded/skipped suite, and the exact corpus the sweep now runs.

Leave docs placement, tagging, renaming, splitting, and publishing to their own
slices. Produce a clean, history-preserving import — nothing more.
