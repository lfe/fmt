# Slice 5: LFE layout refinements

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S5-1 | Slice starts from committed slice4 state and does not fold unrelated work into the diff | `git status`; `git log`; code review | serious | collaboration discipline | planned | | |
| A1S5-2 | `pe_lfe` adds a focused abstraction for block-valued argument layout | code review; `rebar3 compile` | serious | A1-R013 | planned | | |
| A1S5-3 | Known block argument forms include `lambda`, `match-lambda`, `case`, `receive`, and `cond` | code review; eunit tests | serious | A1-R013 | planned | | |
| A1S5-4 | `lfe_08_ets_new` no longer shows pathological rightward drift for `match-lambda` as an argument | targeted golden/indent test | serious | slice3 caveat | planned | | |
| A1S5-5 | Stress block-argument samples reflect the refined layout | eunit structural tests over `block_arg_*` samples | correctness | slice4 corpus / A1-R013 | planned | | |
| A1S5-6 | Ordinary generic calls still use generic S-expression fallback | regression test | serious | scope control | planned | | |
| A1S5-7 | Top-level/body-position block forms keep their existing readable block behavior | regression tests for `lambda`, `match-lambda`, `case`, `receive`, `cond` | correctness | scope control | planned | | |
| A1S5-8 | `pe_lfe` adds focused function-binding layout for `flet` and `fletrec` | code review; `rebar3 compile` | serious | A1-R014 | planned | | |
| A1S5-9 | Function bindings shaped `(name (args...) body...)` render clause-like | focused eunit test | serious | A1-R014 | planned | | |
| A1S5-10 | Non-function binding shapes retain safe fallback behavior | focused eunit test | correctness | scope control | planned | | |
| A1S5-11 | `lfe_20_eval_receive` formats `fletrec` local function binding naturally | targeted golden/indent test | serious | slice3 caveat | planned | | |
| A1S5-12 | Stress `fletrec_bindings_12` reflects the refined binding layout | eunit structural test | correctness | slice4 corpus / A1-R014 | planned | | |
| A1S5-13 | Stress benchmark row work moves construction, `dag_size`, resolve, render, and metric extraction inside the monitored timeout boundary | code review; targeted test if practical | serious | A1-R016 | planned | | |
| A1S5-14 | Timeout/error rows still emit stable CSV rows when construction or formatting fails/times out | eunit test or explicit code-review evidence | serious | A1-R016 | planned | | |
| A1S5-15 | Existing `lfe-knowledge` and `lfe-stress` benchmark modes remain available | run or smoke-test commands | correctness | benchmark continuity | planned | | |
| A1S5-16 | Slice5 adds a refined benchmark command, e.g. `escript bench/pe_bench lfe-refined` | run benchmark | serious | slice5 evidence | planned | | |
| A1S5-17 | Slice5 benchmark writes a new artifact, e.g. `bench/results/lfe_refined.csv`, without silently repurposing slice3/slice4 CSVs | inspect files and ledger | serious | evidence hygiene | planned | | |
| A1S5-18 | Refined benchmark includes all 20 real samples at widths 60, 80, and 100, or records a justified amendment | CSV row count | correctness | viability evidence | planned | | |
| A1S5-19 | Refined benchmark includes affected stress samples, or all stress samples, with clear labels | CSV row count/content | correctness | A1-R013 / A1-R014 | planned | | |
| A1S5-20 | Closing report summarizes shape improvements and stable counter changes without over-reading timing | closing report review | serious | methodology | planned | | |
| A1S5-21 | No resolver semantic changes are introduced | code review; targeted diff review | serious | scope control | planned | | |
| A1S5-22 | No parser/source-fidelity work is introduced | code review; ledger review | correctness | scope control | planned | | |
| A1S5-23 | Zero-warning compile + xref + dialyzer clean | `rebar3 compile`; `rebar3 xref`; `rebar3 dialyzer` | serious | engineering bar | planned | | |
| A1S5-24 | Unit/integration/property floor green | `rebar3 eunit`; `rebar3 ct` if CT is used; `rebar3 proper` if PropEr is present/added | serious | engineering bar | planned | | |
| A1S5-25 | OTP 22-29 compatibility remains explicitly deferred if not handled | ledger review | polish | deferred from arc | planned | | |
| A1S5-26 | Coverage gate + CAP strength audit remains explicitly deferred if not handled | ledger review | serious | deferred from arc | planned | | |

## Amendments

Record scope amendments here before closure. Each amendment should explain what
changed, why it changed, and which ledger rows it affects.

## Caveat Checklist

At closure, fill in:

- exact layout-rule changes made in `pe_lfe`;
- rendered evidence for `lfe_08_ets_new`;
- rendered evidence for `lfe_20_eval_receive`;
- affected stress samples and whether their layout improved;
- refined benchmark artifact path and row count;
- stable counter changes worth noticing;
- any timeout/error rows in refined benchmark output;
- any remaining generic-fallback awkward shapes;
- deferrals: parser/source fidelity, Unicode width, OTP backport, coverage/CAP.

## Closure

Closed at commit: pending.

CDC verification: pending.
