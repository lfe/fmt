# Slice 1: history-transfer — ledger

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state (re-runs / reads the DAG and diffs, not
> summaries). Implementer never marks its own rows CDC-verified. Iteration
> cap: 5. Project `v0.1.0` · arc `arc7-import` · slice
> `slice1-history-transfer`.

## Ledger

> CC self-assessment below. SHAs: base `05fc025`; merge `d879c90` ("Import
> Fezzik…"); corpus re-point `3177954`. The rewritten Fezzik root is `c5bfc71`
> (was `0f74364`, "Started work on LFE formatter", 2026-06-13) — `filter-repo`
> rewrites SHAs, so commits are located by message/date, never old hash.
> Worktree: `../fmt-fezzik-import` on branch `feature/fezzik-import`.

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A7S1-1 | `filter-repo` extract contains exactly the 8 Fezzik paths and their history (~29 commits) | `git -C /tmp/fezzik-extract ls-files`; `… log --oneline \| wc -l` | correctness | slice spec | done | `ls-files` = exactly the 8 paths (3 `src/r3lfe_format*.erl`, 3 `test/r3lfe_*_SUITE.erl`, `test/r3lfe_format_lexer_SUITE_data/tq_corpus.lfe`, `docs/design/022-lfe-format/…`). `log --oneline \| wc -l` = **43** total commits touching the imported paths; **29** touch the 3 engine `src` files (the "~29" figure). Root `c5bfc71` (=`0f74364`). | extracted from tip `4a509c1` (operator-confirmed; plan's `c28de51`+1, A7·S6) |
| A7S1-2 | merge lands all Fezzik commits in `fmt`'s DAG with original authorship/dates; `git log --follow` reaches `0f74364` on each module | `git log --follow src/r3lfe_formatter.erl \| tail`; check first commit `0f74364` + dates | serious | migration plan §2 | done | Merge `d879c90`, `--allow-unrelated-histories`. Root `c5bfc71` author/date **identical** to original `0f74364` (Duncan McGreggor, 2026-06-13). `--follow` reaches the **root `c5bfc71`** on the **lexer** (the file present at the root commit). Formatter `--follow` reaches its birth `ce03797` (Arc A3, 2026-06-14); cst its birth `e3bbade` (arc2, 2026-06-13) — a file cannot be followed before it existed; the DAG root for all is `0f74364`→`c5bfc71`. | see clarification — criterion's literal "reaches 0f74364 on each module" holds for the lexer; others reach their own birth |
| A7S1-3 | imported 3 modules compile in `fmt` under original `r3lfe_*` names, zero warnings | `rebar3 compile` | serious | slice spec | done | `rebar3 compile` exit 0, **zero warnings** under fmt's `warnings_as_errors, warn_unused_import, warn_export_vars`. Beams built: `r3lfe_format_cst/lexer/formatter.beam`. **No erl_opts friction** — compiled clean as-is, no behaviour change needed. | |
| A7S1-4 | the 3 CT suites are present and runnable; `lfe` oracle dep resolves; `_SUITE_data` present | `rebar3 ct --suite=...` (dry list) | serious | slice spec | done | All 3 suites run via `rebar3 ct --suite=…`. `lfe` test-dep fetched + resolves (`code:lib_dir(lfe)` = `_build/test/lib/lfe`); `lfe_io` oracle available. `tq_corpus.lfe` present in `_SUITE_data`. | |
| A7S1-5 | corpus sweep re-pointed off `_integration` onto `code:lib_dir(lfe)` corpus; exercises a disclosed non-trivial file count (not 1) | read `ct:log` file count; inspect the discovery edit | serious | slice1 finding (anti silent-drop) | done | Commit `3177954`, discovery source only. `ct:log`: **"Corpus sweep: 32 total .lfe files"**, **"Wide sweep over 32 .lfe files"** (0 skipped); inline oracles **"over 82 inputs"**. 6 discovery sites re-pointed across all 3 suites. | see Amendments 1 & 2 (lexer site + ASCII filter) |
| A7S1-6 | `rebar3 ct` green — all three Fezzik suites pass | `rebar3 ct` | serious | engineering bar | done | Full `rebar3 ct` → **All 274 tests passed** (formatter 214 + cst/lexer 58 = 272 Fezzik, + 2 pe `*_SUITE`). exit 0. | |
| A7S1-7 | `rebar3 xref` clean (no dangling refs from imported code) | `rebar3 xref` | serious | engineering bar | done | `rebar3 xref` exit 0, no undefined-function/dangling warnings, at `3177954`. | |
| A7S1-8 | `rebar3 dialyzer` clean | `rebar3 dialyzer` | serious | engineering bar | done | `rebar3 dialyzer` exit 0, analyzed 20 files, **no warnings**. `-dialyzer({no_underspecs, …})` travelled with `format/1`. | |
| A7S1-9 | `pe_*` modules and `docs/planning/v0.5.0/` provably untouched by the import | `git diff <base>..HEAD -- src/pe_*.erl docs/planning/v0.5.0` → empty | serious | scope control | done | `git diff --stat 05fc025 -- 'src/pe_*.erl' 'test/pe_*' docs/planning/v0.5.0` → **empty**. Full `git diff --name-status 05fc025` = only the 8 Fezzik paths' files + the 3 re-pointed `test/r3lfe_*_SUITE.erl`. No `pe_*` / `docs/planning` touched. | pe docs already live at `docs/planning/v0.5.0` on this branch base |
| A7S1-10 | no `r3lfe_* → lfmt_*` rename leaked into this slice; no tags created | `grep -rn lfmt_fezzik src test` → empty; `git tag` shows no new tag | serious | scope control | done | `grep -rn 'lfmt_fezzik\|lfmt_' src test` → **empty**. `git tag -l` → **empty** (no tags). Modules keep `r3lfe_*` names. | rename = v0.3.0; `0.1.0` tag = slice2; `0.2.0` tag = v0.2.0 project |
| A7S1-11 | closing report states the exact corpus the sweep runs over + any degraded/skipped suite | closing-report check | serious | methodology | done | See **Caveats** below: exact corpus enumerated; large-file latency test re-pointed (ran, not skipped); no suite degraded. | |
| A7S1-12 | OTP 28 toolchain compatibility | covered by A7S1-3/-6 under fmt's OTP 28 | polish | engineering bar | done | compile + `ct` (274) + xref + dialyzer all green under **OTP 28** (rebar3 3.27.0, erts 16.1.1). | Fezzik targeted OTP 24+; no compat fixes needed |

## Amendments (CC-raised refinements)

Two scope refinements to the "one sanctioned discovery edit" (A7S1-5). Both stay
within "edit discovery source, not the oracles", and both are disclosed rather
than folded in silently:

1. **Lexer suite discovery also re-pointed.** The slice prompt named only
   `r3lfe_formatter_SUITE` (`conf_wide_sweep`, `corpus_sweep`, large-file) and
   `r3lfe_format_cst_SUITE`. But `r3lfe_format_lexer_SUITE`'s
   `round_trip_integration_files` discovers `_integration` too **and asserts
   `length(Files) > 0`** — so against the absent dir it would *fail hard*, not
   pass hollowly. Re-pointed its `integration_lfe_files/0` onto the same
   `code:lib_dir(lfe)` corpus. Required for A7S1-6 (all three suites green).

2. **ASCII restriction on the inline-oracle corpus (`full_corpus/0`).**
   Discovered during the work: the formatter emits Unicode **codepoints** (> 127)
   in its output iolist for multibyte-UTF-8 sources, and re-reads them correctly
   **only** via `unicode:characters_to_binary`. The inline oracle helpers
   (`assert_idempotent` / `assert_token_preservation` / `assert_ast_equiv`) use
   `iolist_to_binary`, which mangles those codepoints (the re-read then throws
   `invalid_encoding`). Exactly the 2 multibyte files in the dep corpus
   (`core-macros.lfe`, `clj-tests.lfe`) trip this; all 29 ASCII files pass both
   paths, and **all 31 pass the Unicode-safe sweeps**. The CST + lexer oracles
   (lex/parse only, no `format`) are Unicode-safe — all 58 pass on the full 31.
   Fix kept in discovery source: `full_corpus/0` filters to 7-bit-ASCII files;
   the 2 Unicode files remain exercised by `corpus_sweep_all` / `conf_wide_sweep`.
   **The oracle helpers were not edited** (out of scope). The latent
   `iolist_to_binary` vs `unicode:characters_to_binary` mismatch in the inline
   helpers is a Fezzik test-harness defect flagged for a later slice.

## Caveats

- **Exact corpus the sweeps now run over (A7S1-11):** the `lfe` test-dep's
  bundled corpus via `code:lib_dir(lfe)` — **20** `examples/*.lfe` + **11**
  `test/*.lfe` + the bundled `tq_corpus.lfe` = **32 files**, **0 skipped**
  (`corpus_sweep_all`, `conf_wide_sweep`). Up from the hollow **1** fixture.
- **Inline oracles (`oracle_idempotency/_token/_comment/_ast`)** run over **82**
  inputs = inline snippets + **29** ASCII dep files + `tq_corpus.lfe`. The 2
  multibyte files are excluded from this path only (Amendment 2) — still covered
  by the sweeps.
- **Large-file latency test:** re-pointed at the dep's `test/guard_SUITE.lfe`
  (**47135 bytes**); it **ran** (logged "guard_SUITE.lfe: 47135 bytes"), not
  skipped. No degraded/skipped suite in this slice.

## What Worked

- **Reproducing the oracle in a standalone probe before touching the suite.**
  The first `rebar3 ct` failed on `clj-tests.lfe`; rather than guess, replicating
  all four oracles (incl. `normalize_module_decls`) over the full corpus pinned
  the failure to exactly 2 files and to `iolist_to_binary` vs
  `unicode:characters_to_binary` — turning a vague "AST-equiv failed" into a
  precise, scoped, disclosable edit.
- **Confirming the extraction tip with the operator first.** The plan's `c28de51`
  had advanced to `4a509c1`; one question avoided importing stale history.
- **Verifying history by message/date, not SHA.** `filter-repo` rewrites hashes;
  matching `c5bfc71`↔`0f74364` on author+date+message kept the claim honest.

## Closure

Self-assessed complete at commit `3177954` (corpus re-point) on
`feature/fezzik-import`, atop merge `d879c90`, base `05fc025`. Date 2026-06-26.
Total rows: **12**. Done: **12**. Deferred: **0**. No-op: **0**.
CC self-assessment only — **CDC verification pending** (append in
`cdc-verification.md`; these `done` rows are "proposed done" until independently
re-run against the DAG and diffs).
