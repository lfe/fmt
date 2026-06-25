# Slice 1: resolver (arc1-poc / slice1-resolver)

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op` — `open` is not final.
>
> Working split (pre-authorised by the slice prompt): **slice1a** = substrate +
> oracle (`pe_doc`, `pe_cost`, `pe_measure`, `pe_mset`, oracle, props); **slice1b**
> = `pe_resolve` + memo backends + CT + bench harness. Rows are tagged [1a]/[1b].

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S1-1  | [1a] `pe_doc` constructors + `freeze` + `get/2` via `element/2` | `rebar3 eunit --module=pe_doc_tests` | correctness | spec | done | 10 tests, 0 failures | |
| A1S1-2  | [1a] hash-consing: identical subtrees intern to same id | eunit `hashcons_test` | correctness | spec | done | pe_doc_tests:hashcons_test passes | |
| A1S1-3  | [1a] ordered + repeated children: `concat(D,D)` → `[D,D]` | eunit `children_order_repeat_test` | correctness | spec | done | pe_doc_tests:children_order_repeat_test passes | |
| A1S1-4  | [1a] dense bottom-up ids: child id < parent id | PropEr `prop_topo_ids` | correctness | spec | done | `rebar3 proper -m prop_pe_doc`: OK 100 tests | |
| A1S1-5  | [1a] `flatten` build-time rewrite, identity-preserving, distributes thru `choice` | eunit `flatten_*_test` | correctness | spec | done | 4 flatten tests pass (nl→space, identity, thru choice, thru nest) | |
| A1S1-6  | [1a] `pe_cost_squared` satisfies the four Fig. 6 contracts | PropEr `prop_factory_contracts` | serious | spec | done | `rebar3 proper -m prop_pe_cost`: OK 100 tests | |
| A1S1-7  | [1a] Fig. 7 costs `(20,0)`/`(8,3)` reproduced (Example-3.4 factory, col 3, w=6) | eunit `fig7_cost_test` | correctness | spec | done | pe_cost_tests: `{20,0}`/`{8,3}` (+squared `{400,0}`/`{26,3}`) | |
| A1S1-8  | [1a] `pe_measure` compose/adjust/dominates/`measure_term` correct | eunit `pe_measure_tests` | correctness | spec | done | 8 tests incl `measure_term_fig7` → last 1, cost `{8,3}` | |
| A1S1-9  | [1a] `pe_mset` merge keeps Pareto invariant | PropEr `prop_mset_pareto` | correctness | spec | done | `rebar3 proper -m prop_pe_mset`: OK 100 tests | |
| A1S1-10 | [1a] merge `Set>Tainted` + left-biased taint + lift | eunit `pe_mset_tests` | correctness | spec | done | 8 tests pass | |
| A1S1-11 | [1b] resolver optimal cost `=:=` oracle, across widths | PropEr `prop_resolver_optimal` + CT | correctness | spec | done | `rebar3 proper -m prop_pe_resolve`: OK 300 tests; pe_resolve_tests concrete optima | |
| A1S1-12 | [1b] memo keeps `shared<>shared` linear in DAG size | CT `linearity_SUITE` | serious | spec | done | memo/calls plateau +1/level (37→46 for n=7→14), within `(n+1)(W+1)` bound | |
| A1S1-13 | [1b] 3 memo backends produce identical optimal measure | CT `memo_parity_SUITE` | correctness | spec | done | full-measure equality across 5 docs × 7 widths | |
| A1S1-14 | [1b] `pe_memo_ets` private table created + deleted per call | eunit `ets_lifecycle_test` (`ets:info` before/after) | serious | spec | done | `ets:all()` count unchanged after call + after mid-call crash | |
| A1S1-15 | [1b] harness emits `{backend,size,width,time,memo,calls,tainted,height}` table + linearity series under `bench/results/` | run escript; output present | serious | spec | done | `escript bench/pe_bench` → stdout tables + `bench/results/{sweep,linearity}.csv` | |
| A1S1-16 | zero-warning compile + dialyzer clean | `rebar3 compile`; `rebar3 dialyzer` | serious | spec | done | compile zero-warning (warnings_as_errors); dialyzer 12 files clean; xref clean | |
| A1S1-17 | OTP 22–29 compatibility | n/a | polish | spec | deferred | | re-entry: backport slice; `%% OTP28+` markers in place |
| A1S1-18 | coverage gate + CAP strength audit | n/a | serious | spec | deferred | | re-entry: post-slice1 strength-analysis phase (operator-run) |

## Amendments (CC-raised refinements to the prompt's sketched surface)

These honour the prompt's **contract points** and ledger criteria exactly; they
refine the *sketched* `Modules (exact surface)` arities where the sketch could
not support a stated requirement. Flagged here for CDC.

1. **Width threading.** The cost factory must know the page width to compute
   overflow, but the prompt's `text_cost(C,L)`/`nl_cost(I)` carry none while
   `resolve` opts carry `width` and `cost` (a bare module) *separately*. So the
   callbacks become `text_cost(W,C,L)`/`nl_cost(W,I)`; `pe_measure:compose/3`
   and `dominates/3` take the cost module (they use `combine`/`le`);
   `measure_term/5` additionally takes `W`. `pe_mset:merge/3` is unchanged
   (matches the prompt). `resolve/2` opts are unchanged.
2. **`nl_cost` vs the `LineM` rule.** `nl_cost(_,_) = {0,1}` as specified, but
   the paper's `LineM` (Fig. 13) charges a newline `nlF +F textF(0,i)` — the
   indentation spaces' cost. `pe_measure:nl_leaf/3` adds that `text_cost(W,0,I)`
   term, so indentation overflow is charged while `nl_cost` stays `{0,1}`.
3. **Lazy `Tainted`.** `Tainted` carries a `fun(() -> measure())` thunk so that
   resolving beyond `W` is *delayed* (Lemma 6.9) — forced only if the whole
   document is tainted. This is what bounds the memo and makes `shared<>shared`
   linear (A1S1-12). The prompt's `taint/1` taking the head is preserved.
4. **Transparent `mset`.** `pe_mset:mset()` is a transparent `{set,_}|{tainted,_}`
   type (not opaque) so the resolver's hot path pattern-matches the two shapes
   directly; the prompt's operations (`merge`/`taint`/`lift`/`optimal`) are all
   provided. `pe_measure` gains accessors (`last`/`cost`/`doc`) and resolver
   leaf constructors (`text_leaf`/`nl_leaf`).

## Known caveat (disclosed, not a silent drop)

The resolver's **search** is linear/bounded as required (A1S1-12: memo & calls
plateau). But `resolve/2` finally calls `optimal/1`, which on an *all-tainted*
document forces the tainted thunk — a leftmost widening that is `O(tree size)`,
i.e. `O(2^n)` for `mk(n)`. This shows up as growing `time_us` in the linearity
series even though `memo`/`calls` stay flat. It is the unavoidable cost of
producing one concrete measure for a document with no fitting layout, and it is
paid at most once. The proper fix (memoised `leftmost` / fused resolve-render,
Appendix C) is **slice2's perf concern** — flagged here, not hidden. Normal
inputs (a fitting layout exists) return a `Set` and never force.

## What Worked

- **Bottom-up, test-as-you-go.** Each module landed green before the next
  (`pe_doc` → `pe_cost` → `pe_measure` → `pe_mset` → oracle → `pe_memo` →
  `pe_resolve`), so the resolver was built on a verified substrate.
- **Reading the figures, not re-deriving.** Pulling Figs. 6–7 and 12–15 from
  the PDF directly settled the two subtle points (the `LineM` indentation cost;
  the delay-beyond-W that makes sharing linear) before any code was written.
- **Differential oracle.** `prop_resolver_optimal` against a brute-force
  widen→measure→min oracle (300 cases) is the high-leverage correctness gate —
  it would catch any merge/dedup/compose error the eunit examples miss.
- **One resolver, three backends.** Threading a memo handle (immutable for map,
  constant-with-mutation for ets/pd) gave a genuine apples-to-apples comparison
  and a parity test for free.

## Closure

Closed at commit acc3878 on 2026-06-22. CDC verification: pending
(operator-run). Total rows: 18. Done: 16. Deferred: 2 (A1S1-17 OTP 22–29
backport; A1S1-18 coverage gate + CAP audit). No-op: 0.

Slice1a checkpoint: commit 95ecbc2 (rows A1S1-1..10).
