# Slice 7: frontier-width instrumentation (the niceness bet)

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S7-1 | `opts()` gains optional `frontier_stats => boolean()` (default false); existing callers unaffected | code review; compile; existing tests | serious | slice7 spec | planned | | |
| A1S7-2 | `stats()` gains optional `frontier => map()`, present iff flag on | code review; eunit on/off shape | serious | slice7 spec | planned | | |
| A1S7-3 | Frontier width sampled as `length(Ms)` at memo-put seam, `{set,Ms}` only | code review | correctness | seam | planned | | |
| A1S7-4 | `frontier` map reports ≥ `max`,`mean`,`p99`,`count`,`histogram`,`max_at` | eunit hand-computable DAG | correctness | metric | planned | | |
| A1S7-5 | Result invariance: optimal measure identical flag on vs off | PropEr over `pe_gen` DAGs | serious | non-perturbation | planned | | |
| A1S7-6 | Counter invariance: memo_size/calls/tainted identical on vs off | PropEr/eunit | serious | non-perturbation | planned | | |
| A1S7-7 | Zero overhead when off: no per-element work on off path; guard documented | code review; optional bench | serious | hot-path hygiene | planned | | |
| A1S7-8 | Oracle correctness holds with flag on | rerun `pe_oracle`/`prop_pe_resolve` flag-on | serious | correctness | planned | | |
| A1S7-9 | `escript bench/pe_bench frontier` mode exists + documented | run it | serious | slice7 spec | planned | | |
| A1S7-10 | Bench covers real corpus (via `pe_lfe_read`) + knowledge + stress, flag on | CSV inspection | serious | viability evidence | planned | | reuses slice6 bridge |
| A1S7-11 | `bench/results/frontier.csv` new; existing CSVs untouched; incl. `W` and `max/W` | CSV + header test; `git status` | serious | evidence hygiene | planned | | |
| A1S7-12 | Per-form granularity for real files (attribute the guard_SUITE tail) | CSV rows | serious | diagnosis | planned | | |
| A1S7-13 | Closing report: niceness-bet verdict (`max |mset|` vs W) + guard_SUITE node-count-vs-frontier diagnosis | report review | serious | methodology / the decision | planned | | |
| A1S7-14 | Zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | engineering bar | planned | | |
| A1S7-15 | eunit + PropEr + ct floor green | eunit/proper/ct | serious | engineering bar | planned | | |
| A1S7-16 | OTP 22–29 backport; coverage + CAP audit remain deferred | ledger review | serious | deferred from arc | planned | | |

## Amendments

_Record scope amendments here before closure._

## Caveat Checklist (fill at closure)

- Niceness-bet verdict — max and p99 `|mset|` across the corpus; `max ÷ W`:
- guard_SUITE diagnosis — node-count (benign) or frontier-width (W-factor biting)?
- Any form/file with a fat frontier (id, width, W):
- Off-path overhead check (timing on vs off, or code-review rationale):
- Invariance evidence (result + counters, on vs off):
- Recommendation — hold on plain Πₑ, or promote arc2 / pretty-canny:

## Closure

Closed at commit: _pending_.
CDC verification: _pending_.
