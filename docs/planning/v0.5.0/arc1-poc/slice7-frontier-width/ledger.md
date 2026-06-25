# Slice 7: frontier-width instrumentation (the niceness bet)

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S7-1 | `opts()` gains optional `frontier_stats => boolean()` (default false); existing callers unaffected | code review; compile; existing tests | serious | slice7 spec | done | `opts()` += `frontier_stats => boolean()`; `resolve/2` reads it via `maps:get(_,_,false)`; `pe`/`pe_lfe`/bench callers pass no such key; compile clean; all prior tests green | |
| A1S7-2 | `stats()` gains optional `frontier => map()`, present iff flag on | code review; eunit on/off shape | serious | slice7 spec | done | `with_frontier/2`; `frontier_absent_when_off_test` / `frontier_present_when_on_test` | |
| A1S7-3 | Frontier width sampled as `length(Ms)` at memo-put seam, `{set,Ms}` only | code review | correctness | seam | done | `sample_frontier/3` at the `error ->` memo-put branch; `{set,Ms}` clause uses `length(Ms)`; `{tainted,_}` clause contributes nothing | |
| A1S7-4 | `frontier` map reports ≥ `max`,`mean`,`p99`,`count`,`histogram`,`max_at` | eunit hand-computable DAG | correctness | metric | done | `frontier_choice_test` (max=2, histogram `#{1=>5,2=>1}`, count=memo_size=6, p99=2, mean=7/6, max_at `{_,0,0}`); `frontier_choiceless_test` (all width-1) | |
| A1S7-5 | Result invariance: optimal measure identical flag on vs off | PropEr over `pe_gen` DAGs | serious | non-perturbation | done | `prop_frontier_invariant` (300 tests): `MeasureOff =:= MeasureOn` | |
| A1S7-6 | Counter invariance: memo_size/calls/tainted identical on vs off | PropEr/eunit | serious | non-perturbation | done | `prop_frontier_invariant`: `StatsOff =:= maps:remove(frontier, StatsOn)`; `invariance_anchor_test` | |
| A1S7-7 | Zero overhead when off: no per-element work on off path; guard documented | code review; optional bench | serious | hot-path hygiene | done | `sample_frontier(_,_, #rs{frontier_stats=false})` is a single field read returning `RS` — no `length/1`, no map update; documented in the function comment | |
| A1S7-8 | Oracle correctness holds with flag on | rerun `pe_oracle`/`prop_pe_resolve` flag-on | serious | correctness | done | `prop_frontier_oracle` (300 tests): resolver cost `=:=` `pe_gen:oracle_optimal` with `frontier_stats=>true` | |
| A1S7-9 | `escript bench/pe_bench frontier` mode exists + documented | run it | serious | slice7 spec | done | `main(["frontier"])` wired + documented in escript header; 1665-row run | |
| A1S7-10 | Bench covers real corpus (via `pe_lfe_read`) + knowledge + stress, flag on | CSV inspection | serious | viability evidence | done | `run_frontier/0` = knowledge (20) + stress + real (cl/clj/test\*) per-form, `frontier_stats=>true`; 1665 rows | reuses slice6 bridge |
| A1S7-11 | `bench/results/frontier.csv` new; existing CSVs untouched; incl. `W` and `max/W` | CSV + header test; `git status` | serious | evidence hygiene | done | `frontier.csv` only new CSV (`git status`); columns incl. `wlimit` + `max_over_w`; `frontier_columns_test`/`frontier_csv_header_test` | |
| A1S7-12 | Per-form granularity for real files (attribute the guard_SUITE tail) | CSV rows | serious | diagnosis | done | real rows carry `index` + `head`; guard_SUITE attributable (max `\|mset\|`=5, count up to 3859 → node-count) | |
| A1S7-13 | Closing report: niceness-bet verdict (`max |mset|` vs W) + guard_SUITE node-count-vs-frontier diagnosis | report review | serious | methodology / the decision | done | see Caveat Checklist / Closure | |
| A1S7-14 | Zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | engineering bar | done | compile zero-warning; xref clean; dialyzer 15 files clean | |
| A1S7-15 | eunit + PropEr + ct floor green | eunit/proper/ct | serious | engineering bar | done | 216 eunit + 7 PropEr + 2 CT, 0 failures | |
| A1S7-16 | OTP 22–29 backport; coverage + CAP audit remain deferred | ledger review | serious | deferred from arc | deferred | | carried arc deferrals |

## Amendments

1. **Widths 40/80/100.** The frontier bench sweeps `W ∈ {40, 80, 100}` (40 added
   to pressure layout — narrower → more breaking → more chances for a wide
   frontier). `limit = width` per row, so `W` in the CSV is the `wlimit` column
   and `max_over_w = max/W`.
2. **Column extensions.** Beyond the prompt's named set, the CSV adds `index`,
   `head` (per-form attribution for real files), `status` (monitored
   timeout/error rows), and `memo_size`/`tainted` (so a fat frontier can be
   separated from sheer node count). All floats (`mean`, `max_over_w`) get a
   `field/1` formatting clause.
3. **`safe_dag/1`** in the bench mirrors slice6's `safe_format_binary`
   genericise-on-crash guarantee but returns the dag (for the resolve-only
   frontier path). Never triggered on the corpus.

## Caveat Checklist (closure)

- **Niceness-bet verdict — max and p99 `|mset|`, `max ÷ W`:** across **1665
  resolves** (knowledge + stress + every real-file form, W ∈ {40,80,100}) the
  per-memo-entry frontier width never exceeds **7**. Distribution of per-resolve
  max: `1`→449, `2`→634, `3`→362, `4`→153, `5`→38, `6`→20, `7`→5. Corpus
  `max p99 = 7`; `max (max/W) = 0.10`. Only 63/1665 (3.8%) reach max ≥ 5; mean
  frontier per entry is ≈1.2. **The bet holds emphatically** — the `W⁴` bound's
  `W`-factor is, in practice, a small single-digit constant `<< W`.
- **guard_SUITE diagnosis — node-count, not frontier-width.** guard_SUITE's
  widest form has `max |mset| = 5` (tame), but a single form reaches **3859**
  memo entries (`count`). Its ~51 ms is **benign node count** (linear in a large
  file), not the `W`-factor biting. It is not even in the corpus top-8 widest
  frontiers (those are `clj.lfe` forms at width 7).
- **Forms with the widest (still-small) frontiers:** `clj.lfe` (form indices 6,
  19, 110) and `ltest-macros.lfe` (index 3) at `max |mset| = 7`; one stress
  sample (`nested_case_8`) at 6. All `<< W`.
- **Off-path overhead check:** by construction — `sample_frontier/3`'s
  flag-off clause is one record-field read returning `RS` (no `length/1`, no map
  update); guarded at the single memo-put seam. Counter/result invariance
  (below) confirms the on path is observation-only.
- **Invariance evidence:** `prop_frontier_invariant` (300 random DAGs, `limit =
  width` so taint occurs) proves identical optimal measure and identical
  `memo_size`/`calls`/`tainted` on vs off, with `frontier` present iff on;
  `prop_frontier_oracle` (300) keeps resolver = oracle with the flag on.
- **Recommendation — HOLD on plain Πₑ.** The frontiers are tame everywhere
  measured, which both *explains* slice6's fast whole-file latency and shows
  there is no hidden `W⁴` tail on real Lisp. The symbolic-PWL / arc2 /
  pretty-canny optimisation is **demoted to optional** — promote it only if a
  future corpus (much larger files, machine-generated macro expansions, or far
  narrower target widths) is shown to produce genuinely fat frontiers. This
  closes the niceness bet in plain Πₑ's favour.

## Closure

Closed at commit `4e379ff` on 2026-06-24. CDC verification: pending
(operator-run). Total rows: 16. Done: 15. Deferred: 1 (A1S7-16 OTP backport +
coverage/CAP). No-op: 0.

Headline for the running log: **max `|mset|` = 7, `max/W` = 0.10** across the
real corpus (1665 resolves); guard_SUITE's tail is node-count (≤5 frontier, up
to 3859 nodes/form), not the `W`-factor. Niceness bet holds → arc2/symbolic-PWL
is optional, not triggered.
