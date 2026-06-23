# Slice 2: render + real-LFE viability samples

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S2-1 | `pe_render` renders `text`, `nl`, and `concat` as iodata with correct columns | `rebar3 eunit --module=pe_render_tests` | correctness | slice2 spec | done | 11 tests, 0 failures (text/nl/concat/nl_reindents) | |
| A1S2-2 | `pe_render` implements `nest` and `align` with separate indentation/column semantics | eunit `nest_align_*_test` | correctness | paper semantics | done | `nest_relative`/`align_absolute`/`nest_and_align_differ`/`align_multiline` pass | |
| A1S2-3 | `pe_render:render_binary/1` returns stable binaries without caller-side flattening | eunit `render_binary_test` | serious | slice2 spec | done | `render_binary_stable_test`; `render/1` returns iolist | |
| A1S2-4 | `pe` facade exposes `resolve/2`, `format/2`, and `format_binary/2` with defaults `{cost=pe_cost_squared,memo=pe_memo_map,width=80,limit=width}` | `rebar3 eunit --module=pe_tests` | serious | slice2 spec | done | 6 tests; defaults verified (`format_defaults`, `limit_defaults_to_width`) | |
| A1S2-5 | facade options override defaults without changing `pe_resolve:resolve/2` contract | eunit `format_opts_override_test` | serious | slice2 spec | done | width + memo overrides; `resolve_passthrough_test` matches `pe_resolve` | |
| A1S2-6 | `pe_lfe_samples` exposes exactly 20 stable samples with id/label/source/tags metadata | `rebar3 eunit --module=pe_lfe_samples_tests` | correctness | selected corpus | done | `sample_count_test`=20; `sample_metadata_test` (id/label/source/tags non-empty) | |
| A1S2-7 | sample set includes Ackermann plus the 19 selected example-derived forms from `slice-doc.md` | eunit `sample_ids_test` | correctness | selected corpus | done | `sample_ids_test`: exact 20-id list lfe_01..lfe_20 | |
| A1S2-8 | all 20 sample builders return frozen DAGs with positive size and stable roots | eunit `sample_builds_test` | correctness | selected corpus | done | `sample_builds_test`: size>0, root valid + stable on rebuild | |
| A1S2-9 | all 20 samples resolve and render at width 80 with non-empty output | eunit `samples_render_width_80_test` | correctness | viability | done | non-empty + paren-balanced for all 20 | |
| A1S2-10 | all 20 samples resolve and render at width 100 with non-empty output | eunit `samples_render_width_100_test` | correctness | viability | done | non-empty + paren-balanced for all 20 | |
| A1S2-11 | rendered sample outputs are deterministic across repeated runs | eunit `samples_deterministic_test` | serious | viability | done | identical bytes across repeated `format_binary` | |
| A1S2-12 | benchmark emits `id,label,width,time_us,memo_size,calls,tainted,badness,height,bytes,lines` columns | run harness; inspect header | serious | viability | done | `pe_lfe_bench:columns/0` + CSV header match exactly (`columns_test`, `csv_header_and_count_test`) | |
| A1S2-13 | benchmark runs all 20 samples at widths 80 and 100 | CSV row count = 40 plus header | serious | viability | done | `row_count_test`=40; `lfe_samples.csv` = 41 lines | |
| A1S2-14 | benchmark writes `bench/results/lfe_samples.csv` and prints a stdout table | run harness; file exists | serious | viability | done | `escript bench/pe_bench lfe` → stdout table + `bench/results/lfe_samples.csv` (40 rows) | |
| A1S2-15 | benchmark uses monotonic/fair timing discipline and does not interpret backend/algorithm viability | code review `bench/pe_bench` or new harness | serious | methodology | done | `timer:tc` (monotonic) best-of-5, fresh process per repeat (PF-03); emits numbers only | |
| A1S2-16 | renderer/facade/sample code keeps production modules free of test-only LFE knowledge-layer helpers | code review `src/` vs `test/` | serious | scope control | done | `grep -rl lfe src/` → none; `pe_lfe_samples`/`pe_lfe_bench` in `test/` only | |
| A1S2-17 | zero-warning compile + xref + dialyzer clean | `rebar3 compile`; `rebar3 xref`; `rebar3 dialyzer` | serious | engineering bar | done | compile zero-warning; xref clean; dialyzer 14 files clean | |
| A1S2-18 | unit/integration floor green | `rebar3 eunit`; `rebar3 ct` if CT is used; `rebar3 proper` if PropEr is added | serious | engineering bar | done | 79 eunit + 5 PropEr + 2 CT, 0 failures | |
| A1S2-19 | closing report names any heavily-tainted, slow, or awkwardly modelled sample | closing report row/caveat check | serious | methodology | done | see Caveats section | |
| A1S2-20 | OTP 22-29 compatibility | n/a | polish | deferred from arc | deferred | | re-entry: backport slice; keep OTP27/28 markers mechanically greppable |
| A1S2-21 | coverage gate + CAP strength audit | n/a | serious | deferred from arc | deferred | | re-entry: post-slice2 strength-analysis phase |

## Amendments (CC-raised refinements)

1. **Spec-interpreter combinators.** Rather than builder-threading combinators
   with the exact suggested arities (`txt/2`, `sexp/3`, …), `pe_lfe_samples`
   uses a small **spec vocabulary** (pure data constructors `a/1`, `str/1`,
   `sx/1`, `lst/1`, `tup/1`, `blk/2`, `cl/2`, `q/1`/`bq/1`/`uq/1`) interpreted by
   one `build_spec/2`. Each sample is then readable data, not 50 lines of
   threaded `{Id, B}` plumbing. The required accessor surface
   (`all`/`by_id`/`build`/`id`/`label`/`source`, plus `tags`) is exact. All
   helpers are test-only (A1S2-16).

## Caveats (A1S2-19)

From `bench/results/lfe_samples.csv` (map backend, `limit = width`) and a read
of the rendered output. Numbers, not a verdict:

- **No sample is all-tainted or degenerate.** `badness = 0` for all 20 forms at
  both widths — every form found a fitting layout, so the disclosed slice1
  `O(2^n)` tainted-`optimal` path is never hit here. The non-zero `tainted`
  counts (0–175) are over-wide *sub*-layouts pruned during search, not failures.
- **Runtime is uniformly sub-millisecond** (`time_us` 130–673 at width 80;
  130–673 at width 100). No sample dominates; the slowest cluster is
  `lfe_16_account`, `lfe_13_get_page`, `lfe_17_eval_expr`, `lfe_07_bq_expand`
  (~0.5–0.7 ms), all structurally the deepest.
- **One awkwardly-modelled form: `lfe_07_bq_expand`.** It wraps a `defun` inside
  `(eval-when-compile …)` using the call/`sexp` combinator, so the inner `defun`
  body aligns far to the right instead of indenting. This is a hand-modelling
  artifact of the generic combinators — a real knowledge layer would treat
  `eval-when-compile` as a vertical block. Not an engine defect.
- **General shape note:** the `sexp` combinator aligns args under the first arg,
  which drifts deeply-nested children rightward and increases breaking at width
  80. A real LFE knowledge layer would mix `align`/`nest` per form; here it is a
  uniform choice for the fixtures.

## What Worked

- **Spec-interpreter for fixtures.** Modelling the 20 forms as data over a tiny
  combinator vocabulary kept them readable and uniform, and made "build + render
  + balance-check all 20" a one-line test.
- **Render cross-checked through the facade.** Driving samples via
  `pe:format_binary/2` exercised resolve→render end-to-end; paren-balance +
  determinism caught any structural slip cheaply.
- **Reusing the slice1 engine unchanged.** No resolver semantics were touched;
  the renderer is a thin `⇓R` over the choiceless doc the measure already
  carries.

## Closure

Closed at commit `<slice2 SHA>` on 2026-06-22. CDC verification: pending
(operator-run). Total rows: 21. Done: 19. Deferred: 2 (A1S2-20 OTP 22–29
backport; A1S2-21 coverage gate + CAP audit). No-op: 0.
