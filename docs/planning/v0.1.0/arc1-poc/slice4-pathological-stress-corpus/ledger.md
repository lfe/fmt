# Slice 4: Pathological stress corpus

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S4-1 | Stress corpus module exists with stable metadata and build surface | code review; `rebar3 compile` | serious | slice4 spec | planned | | |
| A1S4-2 | Corpus exposes stable IDs, labels, categories, and sizes | eunit corpus metadata tests | correctness | benchmark reproducibility | planned | | |
| A1S4-3 | Corpus contains long proper-list stress cases | code review; eunit representative render | serious | A1-R007 | planned | | |
| A1S4-4 | Corpus contains long improper/dotted-list stress cases | code review; eunit representative render | serious | A1-R007 | planned | | |
| A1S4-5 | Corpus contains long generic-call fallback stress cases | code review; eunit representative render | serious | A1-R007 | planned | | |
| A1S4-6 | Corpus contains deep generic S-expression stress cases | code review; eunit representative render | serious | A1-R007 | planned | | |
| A1S4-7 | Corpus contains at least one shared-subtree or shared-DAG stress case | code review; structural counter evidence | serious | A1-R001 / paper risk | planned | | |
| A1S4-8 | Corpus contains quote/backquote/unquote tower stress cases | code review; eunit representative render | correctness | LFE syntax risk | planned | | |
| A1S4-9 | Corpus contains long `let`/`let*`/`flet`/`fletrec` binding-list cases | code review; eunit representative render | serious | A1-R007 / A1-R014 | planned | | |
| A1S4-10 | Corpus contains nested `case`/`receive`/`cond` or clause-like forms | code review; eunit representative render | serious | A1-R007 | planned | | |
| A1S4-11 | Corpus contains block-valued call-argument cases related to the slice3 `lfe_08` caveat | code review; eunit representative render | serious | A1-R013 | planned | | |
| A1S4-12 | Corpus contains forced no-fit or mostly-tainted rows by construction | code review; benchmark evidence | serious | A1-R001 | planned | | |
| A1S4-13 | Stress samples build deterministically and do not depend on wall-clock/random input | eunit deterministic build tests | serious | reproducibility | planned | | |
| A1S4-14 | Benchmark mode for stress corpus exists and is documented in command form | run `escript bench/pe_bench lfe-stress` or documented equivalent | serious | slice4 spec | planned | | |
| A1S4-15 | Benchmark writes `bench/results/lfe_stress.csv` without overwriting prior benchmark artifacts | run benchmark; inspect files | serious | evidence hygiene | planned | | |
| A1S4-16 | CSV header includes `id,label,category,size,width,limit,status,time_us,memo_size,calls,tainted,badness,height,bytes,lines,dag_size` or a justified equivalent | inspect CSV; eunit header test | correctness | analysis usability | planned | | |
| A1S4-17 | Benchmark covers normal and aggressive widths, including 20, 40, 60, 80, and 100 unless amended with rationale | CSV row inspection | serious | A1-R001 / A1-R007 | planned | | |
| A1S4-18 | Benchmark runs each row in a monitored worker with timeout/error reporting | code review; timeout/error test if practical | serious | stress safety | planned | | |
| A1S4-19 | Timeout or worker error produces a CSV row and does not abort the remaining run | targeted test or controlled benchmark evidence | serious | stress safety | planned | | |
| A1S4-20 | CSV includes a deterministic `dag_size` or equivalent structural-size counter with documented meaning | code review; CSV inspection | correctness | analysis usability | planned | | |
| A1S4-21 | Representative bounded stress cases render successfully in ordinary tests | `rebar3 eunit` | correctness | regression safety | planned | | |
| A1S4-22 | At least one forced no-fit canary records non-zero badness or an explicitly better all-tainted/no-fit signal | eunit or benchmark evidence | serious | A1-R001 | planned | | |
| A1S4-23 | Benchmark stdout summarizes worst rows by calls, memo size, tainted count, badness, and timeout/error status | run benchmark; inspect stdout | polish | operator usefulness | planned | | |
| A1S4-24 | Closing report states whether forced no-fit/all-tainted-like scenarios were observed, and names proxy limitations if exact all-tainted instrumentation is unavailable | closing report review | serious | methodology | planned | | |
| A1S4-25 | Zero-warning compile + xref + dialyzer clean | `rebar3 compile`; `rebar3 xref`; `rebar3 dialyzer` | serious | engineering bar | planned | | |
| A1S4-26 | Unit/integration/property floor green | `rebar3 eunit`; `rebar3 ct` if CT is used; `rebar3 proper` if PropEr is present/added | serious | engineering bar | planned | | |
| A1S4-27 | OTP 22-29 compatibility remains explicitly deferred if not handled | ledger review | polish | deferred from arc | planned | | |
| A1S4-28 | Coverage gate + CAP strength audit remains explicitly deferred if not handled | ledger review | serious | deferred from arc | planned | | |

## Amendments

Record scope amendments here before closure. Each amendment should explain what
changed, why it changed, and which ledger rows it affects.

## Caveat Checklist

At closure, fill in:

- stress families included and any families consciously deferred;
- rows with the highest `calls`, `memo_size`, `tainted`, and `badness`;
- any `timeout` or `error` rows;
- whether forced no-fit/all-tainted-like scenarios were observed;
- whether exact all-tainted-path instrumentation exists or the report is using
  non-zero badness/tainted forced rows as a proxy;
- benchmark timing caveats;
- any visual-quality caveats discovered but intentionally deferred.

## Closure

Closed at commit: pending.

CDC verification: pending.
