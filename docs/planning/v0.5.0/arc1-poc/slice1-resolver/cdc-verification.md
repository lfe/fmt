# CDC verification - arc1-poc / slice1-resolver

Verifier: Codex Desktop
Date: 2026-06-23
Reviewed commits: 95ecbc2, acc3878, 7c69f1e

## Summary

No correctness blockers found in the slice1 resolver implementation. CC's
18-row ledger is row-complete: 16 rows verified done, 2 rows validly deferred,
0 no-op, 0 silent drops.

The core claims reproduced: tuple-backed hash-consed DAG, build-time flatten,
paper cost cross-check, measure/mset substrate, resolver-vs-oracle property,
memo backend parity, linear memo/call growth on the shared DAG stressor, ETS
cleanup, compile, eunit, PropEr, Common Test, xref, dialyzer, and benchmark
artifact generation.

## Commands Reproduced

```text
rebar3 compile
  PASS - compiled fmt with warnings_as_errors.

rebar3 eunit
  PASS - 38 tests, 0 failures.

rebar3 proper -m prop_pe_doc
  PASS - prop_topo_ids, 100 tests.

rebar3 proper -m prop_pe_cost
  PASS - prop_factory_contracts, 100 tests.

rebar3 proper -m prop_pe_mset
  PASS - prop_mset_pareto, 100 tests.

rebar3 proper -m prop_pe_resolve
  PASS - prop_resolver_optimal, 100 tests.

rebar3 proper -m prop_pe_resolve -n 300
  PASS - prop_resolver_optimal, 300 tests.

rebar3 ct
  PASS - linearity_SUITE and memo_parity_SUITE; all 2 tests passed.

rebar3 xref
  PASS - no xref warnings.

rebar3 dialyzer
  PASS - analyzed 12 files, no warnings.

escript bench/pe_bench
  PASS - emitted stdout tables and rewrote bench/results/sweep.csv and
  bench/results/linearity.csv.
```

## Ledger Walk

| ID | CDC Status | Evidence |
|----|------------|----------|
| A1S1-1 | verified done | `rebar3 eunit` includes `pe_doc_tests`; 38 total tests green. |
| A1S1-2 | verified done | `hashcons_test` present in `test/pe_doc_tests.erl`; eunit green. |
| A1S1-3 | verified done | `children_order_repeat_test` present; eunit green. |
| A1S1-4 | verified done | `rebar3 proper -m prop_pe_doc` passed 100 tests. |
| A1S1-5 | verified done | Flatten tests present in `pe_doc_tests`; eunit green. |
| A1S1-6 | verified done | `rebar3 proper -m prop_pe_cost` passed 100 tests. |
| A1S1-7 | verified done | Fig. 7 assertions present in `pe_cost_tests`; eunit green. |
| A1S1-8 | verified done | `pe_measure_tests` present; eunit green. |
| A1S1-9 | verified done | `rebar3 proper -m prop_pe_mset` passed 100 tests. |
| A1S1-10 | verified done | `pe_mset_tests` present; eunit green. |
| A1S1-11 | verified done | `rebar3 proper -m prop_pe_resolve -n 300` passed; concrete resolver tests green. |
| A1S1-12 | verified done | `rebar3 ct` passed `linearity_SUITE`; memo/call growth test present. |
| A1S1-13 | verified done | `rebar3 ct` passed `memo_parity_SUITE`; full-measure equality checked. |
| A1S1-14 | verified done | ETS lifecycle and crash cleanup tests present; eunit green. |
| A1S1-15 | verified done | `escript bench/pe_bench` emitted tables and rewrote both CSV artifacts. |
| A1S1-16 | verified done | `rebar3 compile`, `rebar3 dialyzer`, and `rebar3 xref` all passed. |
| A1S1-17 | valid deferred | OTP 22-29 compatibility is explicitly deferred to the backport slice; OTP28+ marker found. |
| A1S1-18 | valid deferred | Coverage gate and CAP audit are explicitly deferred to post-slice1 strength analysis. |

## Review Notes

- The arity amendments in the ledger are justified: width must be threaded into
  the cost factory for overflow costs, and `compose`/`dominates` need the cost
  module.
- The `nl_leaf` implementation charges `nl_cost + text_cost(0, Indent)`, which
  matches the paper's line measure rule while keeping `nl_cost` itself literal.
- Lazy `Tainted` is a deliberate implementation choice and is covered by the
  linearity and parity tests.
- Running the benchmark is reproducible but not bit-for-bit stable: timing
  columns change on each run. The committed CSVs should be treated as sample
  output from one run, not as a golden test oracle.
- The benchmark harness uses short `timer:tc` repeats in the same process, as
  requested by the slice prompt. That is enough for this raw comparison slice,
  but the later viability analysis should avoid over-reading microsecond-level
  timing differences.

## Closure

CDC verification accepts slice1 as closed at the stated scope: cost/measure-level
resolver PoC, no rendering, no public facade, no real-LFE inputs. Slice2 should
pick up rendering/facade/real-input validation and should revisit the disclosed
all-tainted `optimal/1` cost before relying on large tainted workloads.
