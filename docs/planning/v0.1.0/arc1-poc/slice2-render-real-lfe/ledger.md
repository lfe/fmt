# Slice 2: render + real-LFE viability samples

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S2-1 | `pe_render` renders `text`, `nl`, and `concat` as iodata with correct columns | `rebar3 eunit --module=pe_render_tests` | correctness | slice2 spec | open | | |
| A1S2-2 | `pe_render` implements `nest` and `align` with separate indentation/column semantics | eunit `nest_align_*_test` | correctness | paper semantics | open | | |
| A1S2-3 | `pe_render:render_binary/1` returns stable binaries without caller-side flattening | eunit `render_binary_test` | serious | slice2 spec | open | | |
| A1S2-4 | `pe` facade exposes `resolve/2`, `format/2`, and `format_binary/2` with defaults `{cost=pe_cost_squared,memo=pe_memo_map,width=80,limit=width}` | `rebar3 eunit --module=pe_tests` | serious | slice2 spec | open | | |
| A1S2-5 | facade options override defaults without changing `pe_resolve:resolve/2` contract | eunit `format_opts_override_test` | serious | slice2 spec | open | | |
| A1S2-6 | `pe_lfe_samples` exposes exactly 20 stable samples with id/label/source/tags metadata | `rebar3 eunit --module=pe_lfe_samples_tests` | correctness | selected corpus | open | | |
| A1S2-7 | sample set includes Ackermann plus the 19 selected example-derived forms from `slice-doc.md` | eunit `sample_ids_test` | correctness | selected corpus | open | | |
| A1S2-8 | all 20 sample builders return frozen DAGs with positive size and stable roots | eunit `sample_builds_test` | correctness | selected corpus | open | | |
| A1S2-9 | all 20 samples resolve and render at width 80 with non-empty output | eunit `samples_render_width_80_test` | correctness | viability | open | | |
| A1S2-10 | all 20 samples resolve and render at width 100 with non-empty output | eunit `samples_render_width_100_test` | correctness | viability | open | | |
| A1S2-11 | rendered sample outputs are deterministic across repeated runs | eunit `samples_deterministic_test` | serious | viability | open | | |
| A1S2-12 | benchmark emits `id,label,width,time_us,memo_size,calls,tainted,badness,height,bytes,lines` columns | run harness; inspect header | serious | viability | open | | |
| A1S2-13 | benchmark runs all 20 samples at widths 80 and 100 | CSV row count = 40 plus header | serious | viability | open | | |
| A1S2-14 | benchmark writes `bench/results/lfe_samples.csv` and prints a stdout table | run harness; file exists | serious | viability | open | | |
| A1S2-15 | benchmark uses monotonic/fair timing discipline and does not interpret backend/algorithm viability | code review `bench/pe_bench` or new harness | serious | methodology | open | | |
| A1S2-16 | renderer/facade/sample code keeps production modules free of test-only LFE knowledge-layer helpers | code review `src/` vs `test/` | serious | scope control | open | | |
| A1S2-17 | zero-warning compile + xref + dialyzer clean | `rebar3 compile`; `rebar3 xref`; `rebar3 dialyzer` | serious | engineering bar | open | | |
| A1S2-18 | unit/integration floor green | `rebar3 eunit`; `rebar3 ct` if CT is used; `rebar3 proper` if PropEr is added | serious | engineering bar | open | | |
| A1S2-19 | closing report names any heavily-tainted, slow, or awkwardly modelled sample | closing report row/caveat check | serious | methodology | open | | |
| A1S2-20 | OTP 22-29 compatibility | n/a | polish | deferred from arc | deferred | | re-entry: backport slice; keep OTP27/28 markers mechanically greppable |
| A1S2-21 | coverage gate + CAP strength audit | n/a | serious | deferred from arc | deferred | | re-entry: post-slice2 strength-analysis phase |

## What Worked

_(Filled in at slice close.)_

## Closure

Closed at commit `<SHA>` on `<date>`. CDC verification: pending. Total rows:
21. Done: `<n>`. Deferred: `<n>`. No-op: `<n>`.
