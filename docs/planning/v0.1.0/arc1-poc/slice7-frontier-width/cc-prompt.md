# CC prompt — arc1-poc / slice7 — frontier-width instrumentation

> For CC (implementation seat). Read `slice-doc.md` first. Load
> **erlang-guidelines** (`11-anti-patterns` first, then `06-processes` not
> needed; do load `04-data-and-types`, `05-functions`, `15-testing`,
> `10-performance` for the hot-path/zero-overhead reasoning). Walk the ledger;
> CDC verifies independently. Iteration cap: 5. **Queued behind slice6** — it
> reuses `test/pe_lfe_read.erl`.

## Goal

Measure the **Pareto frontier width (`|mset|`) distribution per memo entry** on
the real LFE corpus, to settle the niceness bet and diagnose the guard_SUITE
latency tail. Instrument `pe_resolve` behind an opt flag with **zero overhead
when off** and **provable result-invariance**.

## The seam (don't hunt — it's here)

`pe_resolve:resolve_node/4`, the `error ->` branch where a freshly computed
`Set` is stored (`Memo:put(Key, Set, …)`, ~lines 105–112). When
`Set = {set, Ms}`, the frontier width is `length(Ms)`. That is the single
sampling point. `pe_mset` exposes the shape; you do **not** need to edit
`pe_mset` (frontier width is `length/1` of the set list — add a tiny accessor
there only if you prefer not to pattern-match the `{set, _}` shape in the
resolver, your call, but keep it a pure read).

## Design

- Extend `opts()` with an optional `frontier_stats => boolean()` (default
  `false`). Extend `stats()` with an optional `frontier => map()` present only
  when the flag is on.
- Add a frontier accumulator to the `#rs{}` record (e.g. a `width => count`
  frequency map plus running `max` and `max_at :: Key`). Update it **only** in
  the flag-on branch at the memo-put seam, for `{set, Ms}` sets. Tainted sets
  contribute nothing (they are already counted by `tainted`).
- In `resolve/2`, when the flag is on, fold the accumulator into the returned
  `stats()` under `frontier => #{max, mean, p50, p90, p99, count, histogram,
  max_at}` (percentiles derived from the frequency map). When off, omit the key.
- **Zero-overhead-off discipline:** guard every accumulation behind the flag so
  the off path executes no new per-node work (no extra `length/1`, no map
  update). A single boolean field read per memo-put is acceptable; per-element
  work is not, when off.

## Ledger

| ID | Criterion | Verify | Significance | Status |
|----|-----------|--------|--------------|--------|
| A1S7-1 | `opts()` gains optional `frontier_stats => boolean()` (default false); existing callers unaffected | code review; `rebar3 compile`; existing tests green | serious | planned |
| A1S7-2 | `stats()` gains optional `frontier => map()`, present iff flag on | code review; eunit on/off shape | serious | planned |
| A1S7-3 | Frontier width sampled as `length(Ms)` at the memo-put seam for `{set, Ms}` sets only | code review | correctness | planned |
| A1S7-4 | `frontier` map reports at least `max`, `mean`, `p99`, `count`, `histogram`, `max_at` | eunit on a known DAG with hand-computable frontier | correctness | planned |
| A1S7-5 | **Result invariance:** optimal measure is identical flag-on vs flag-off | PropEr: `resolve(D,off).measure == resolve(D,on).measure` over random DAGs (reuse `pe_gen`) | serious | planned |
| A1S7-6 | **Counter invariance:** `memo_size`/`calls`/`tainted` identical flag-on vs flag-off | PropEr / eunit | serious | planned |
| A1S7-7 | **Zero overhead off:** off path adds no per-element work; document the guard placement; (optional) a coarse timing sanity check off vs pre-slice baseline | code review; optional bench | serious | planned |
| A1S7-8 | Oracle correctness still holds with flag on | existing `pe_oracle`/`prop_pe_resolve` rerun with flag on | serious | planned |
| A1S7-9 | Bench mode `escript bench/pe_bench frontier` exists + documented | run it | serious | planned |
| A1S7-10 | Bench covers the **real corpus** via `pe_lfe_read` (cl.lfe, clj.lfe, test/*.lfe) plus knowledge + stress corpora, flag on | CSV inspection | serious | planned |
| A1S7-11 | `bench/results/frontier.csv` written (new artifact; existing CSVs untouched) with per-resolve `max`, `mean`, `p99`, `count`, `W`(=width/limit), and a `max/W` ratio | CSV + header test; `git status` | serious | planned |
| A1S7-12 | Per-form granularity for real files (so the guard_SUITE tail is attributable to specific forms) | CSV has per-file and/or per-form rows | serious | planned |
| A1S7-13 | Closing report states the verdict: is `max |mset|` single-digit and `<< W` on real LFE (bet holds) or fat somewhere (bet fails, name where) — and whether guard_SUITE's cost is node-count or frontier-width | report review | serious | planned |
| A1S7-14 | Zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | planned |
| A1S7-15 | eunit + PropEr + ct floor green | `rebar3 eunit`; `rebar3 proper`; `rebar3 ct` | serious | planned |
| A1S7-16 | OTP 22–29 backport; coverage gate + CAP audit remain explicitly deferred | ledger review | serious | planned |

## Steps

1. **Resolver.** Add `frontier_stats` to opts (default false), the accumulator
   field to `#rs{}`, the flag-guarded sample at the memo-put seam, and the
   `frontier` fold in `resolve/2`. Keep the off path untouched in cost.

2. **Invariance tests.** Extend `prop_pe_resolve` (or a new `prop_pe_frontier`)
   with the on/off result + counter invariance properties (A1S7-5/6), and rerun
   the oracle property with the flag on (A1S7-8). Add a focused eunit on a small
   DAG whose frontier you can compute by hand (A1S7-4).

3. **Bench mode** in `test/pe_lfe_bench.erl`: `run_frontier/0`, resolving each
   form of the knowledge + stress corpora and each top-level form of the real
   files (via `pe_lfe_read:read_file/1` + `code:lib_dir(lfe)`) with
   `frontier_stats => true`; aggregate per form/file; write
   `bench/results/frontier.csv` including `W` and `max/W`. Wire
   `main(["frontier"])` in `bench/pe_bench`.

4. **Run + analyse** on Duncan's MBP: `rebar3 eunit && escript bench/pe_bench
   frontier`. In the closing report, give the headline: the max and p99 frontier
   width across the corpus, the `max/W` ratio, and the guard_SUITE verdict
   (node-count vs frontier-width). Recommend hold/promote on arc2 accordingly.

## Done when

Ledger row-complete; `frontier.csv` holds frontier distributions over the real
corpus; invariance properties green; the closing report delivers the niceness-
bet verdict and the guard_SUITE diagnosis. Report commit SHA + the headline
`max |mset|` / `max÷W` figures. This is the input to the (near-formality) bar
decision and the arc1→arc2 fork.
