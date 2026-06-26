# CC prompt — fmt v0.5.0 · arc1-poc / slice1-resolver

You are CC. Stand up the **core of a BEAM-native port of Πₑ** (PrettyExpressive,
Porncharoenwase et al., OOPSLA 2023) — the generic, optimal, expressive pretty
printer — far enough to get **one correct, memo-backed resolver**, and an
experiment harness that produces the numbers we analyze next: **threaded-map vs
ETS vs process-dictionary** for the resolver's memo, plus a linearity/perf sweep.
Target **OTP 28**. Lean and direct.

**Why it exists (arc1 = `poc`):** the honest question this arc answers is whether
an expressive-and-optimal printer is *viable on the BEAM* — the paper's own data
shows Πₑ is slowest exactly on S-expression workloads, which is what LFE is. This
slice de-risks that: prove the algorithm is correct on the BEAM and settle the
memo-backend question with measurements, not priors.

**Slice focus (the narrow theme):** a **correct, memo-backed resolver, and the
memo-backend decision.** Everything here exists to serve that — `pe_doc` /
`pe_cost` / `pe_measure` / `pe_mset` are the substrate the resolver needs, the
oracle is how we trust it, the harness is how we measure it. There is **no text
rendering in this slice** — correctness is checked at the cost/measure level
(the paper's ⇓M). Rendering, the public façade, and real-LFE inputs are
**slice2**.

## Read first (specification — do not re-derive)

- `docs/planning/v0.5.0/pretty-expressive-port-plan.md` — §2 (algorithm: Σₑ,
  cost factory, measures, measure sets, resolver), §3 (Erlang design, modules),
  §5 (the spike). This is the spec.
- `docs/research/[2023] Porncharoenwase - A Pretty Expressive Printer.pdf` —
  Fig. 6 (cost-factory contracts), Figs. 12–13 (measures + ⇓M measure
  computation), Fig. 14 (measure sets: merge ⊎ / dedup / taint / lift), Fig. 15
  (resolver ⇓RS / ⇓RSC). Match these figures.
- term-DAG store design: `erlsci/graffeo`'s `workbench/term-dag-tier-from-fmt.md`
  §2 (or port plan §3.1 if that path is unavailable).

Load **collaboration-framework** (ledger discipline) and **erlang-guidelines**
(`11-anti-patterns` first, then `01-core-idioms`, `02-api-design`,
`04-data-and-types`, `05-functions-and-pattern-matching`, `15-testing`,
`17-tooling`). Validate at the edge, crash in the interior; tagged returns on the
public surface; `-spec` on every exported function.

## OTP target

Write idiomatic **OTP 28**. We support OTP 22–29 in LFE, but **do not** spend
effort on old-OTP compatibility now. Mark any 27/28-only construct
(`-doc`/`-moduledoc`, `maybe`, triple-quoted strings, sigils) with a `%% OTP28+`
comment so the later backport slice finds them mechanically. The OTP 22–29
backport is a **deferred ledger row**.

## Modules (exact surface)

```erlang
%% pe_doc — builder + frozen term DAG (hash-consed, ordered & repeatable children)
-spec new() -> builder().
-spec text(binary(), builder()) -> {id(), builder()}.        %% display width computed here
-spec nl(builder()) -> {id(), builder()}.
-spec concat(id(), id(), builder()) -> {id(), builder()}.
-spec nest(non_neg_integer(), id(), builder()) -> {id(), builder()}.
-spec align(id(), builder()) -> {id(), builder()}.
-spec choice(id(), id(), builder()) -> {id(), builder()}.
-spec flatten(id(), builder()) -> {id(), builder()}.          %% build-time nl->space rewrite, memoised, identity-preserving
-spec group(id(), builder()) -> {id(), builder()}.            %% choice(flatten(D), D)
-spec vconcat(id(), id(), builder()) -> {id(), builder()}.    %% concat(A, concat(nl, B))
-spec freeze(builder(), id()) -> dag().
-spec get(dag(), id()) -> payload().                          %% element(Id+1, Nodes) — O(1)
-spec children(dag(), id()) -> [id()].                        %% ordered; may repeat
-spec root(dag()) -> id().
-spec size(dag()) -> pos_integer().

%% pe_cost — cost factory behaviour + default + a test factory
-callback le(Cost, Cost) -> boolean().
-callback combine(Cost, Cost) -> Cost.
-callback text_cost(C :: non_neg_integer(), L :: non_neg_integer()) -> Cost.
-callback nl_cost(I :: non_neg_integer()) -> Cost.
%% pe_cost_squared : DEFAULT (production). cost = {Badness, Height}; text_cost
%%   squared-overflow b*(2a+b); nl_cost(_) = {0,1}; le = lexicographic (=<).
%% pe_cost_overflow : TEST-ONLY. paper Example 3.4 sum-of-overflow — proves the
%%   factory is genuinely pluggable and reproduces the paper's Fig. 7 numbers.

%% pe_measure — {Last, Cost, CDoc}; CDoc = choiceless doc term (for parity/debug)
-spec compose(measure(), measure()) -> measure().                 %% ◦  (Fig 12)
-spec adjust_nest(non_neg_integer(), measure()) -> measure().
-spec adjust_align(non_neg_integer(), measure()) -> measure().
-spec dominates(measure(), measure()) -> boolean().               %% ⪯ : last≤ ∧ cost≤
-spec measure_term(CDoc :: term(), C :: non_neg_integer(),
                   I :: non_neg_integer(), CostMod :: module()) -> measure().  %% ⇓M (Fig 13) — used by the oracle

%% pe_mset — Set | Tainted; Pareto frontier sorted by cost ascending
-spec merge(mset(), mset(), CostMod :: module()) -> mset().       %% ⊎ (Fig 14); Set>Tainted; left-biased on Tainted
-spec taint(mset()) -> mset().
-spec lift(mset(), fun((measure()) -> measure())) -> mset().
-spec optimal(mset()) -> measure().                               %% head = least cost

%% pe_resolve — the resolver, parameterised by cost factory + memo module + W
-spec resolve(dag(), #{cost := module(), memo := module(),
                       width := non_neg_integer(), limit := non_neg_integer()})
      -> {measure(), Stats :: map()}.                             %% Stats: #{memo_size, calls, tainted}

%% pe_memo — behaviour + 3 backends (pe_memo_map, pe_memo_ets, pe_memo_pd)
-callback new() -> handle().
-callback find(key(), handle()) -> {ok, mset()} | error.
-callback put(key(), mset(), handle()) -> handle().               %% map: new map; ets/pd: same handle
```

Contract points — do not deviate:

- **Children inline in the payload**, never a side structure:
  `{text, binary(), Width} | nl | {concat, id(), id()} | {nest, N, id()} |
  {align, id()} | {choice, id(), id()}`. This makes ordered **and** repeated
  children (`concat(D, D)`) free. No `flatten` node survives `freeze` (expanded
  at build).
- **ids dense, assigned bottom-up** (children interned before parents) ⇒
  `child id < parent id` invariant (a free topological order). The frozen store
  is a **tuple**, read with `element/2`; no map in the node read path.
- **Hash-consing** (`#{payload => id}` build-time map) — off the hot path;
  preserves sharing, dedups repeats.
- **`pe_resolve` threads a memo handle and returns it**, so the *same* resolver
  code runs over all three backends: `pe_memo_map` genuinely threads a new map;
  `pe_memo_ets`/`pe_memo_pd` thread a constant handle and mutate. This is the
  apples-to-apples comparison — one resolver, three backends.
- **`pe_memo_ets` owns a private table per `resolve/2` call and deletes it before
  returning** (`try … after ets:delete(Tid) end`). No leak across calls.
- **Width is display width**, not `byte_size` (`string:length/1` at `text/2`).
- **`optimal` and `taint` both take the head** of the frontier (sorted by cost
  ascending; head = least cost).

## Oracle & tests (correctness, at the cost level)

The **brute-force oracle** (test code) is the correctness gate and needs **no
rendering**: widen a dag into all choiceless doc terms, compute each one's
measure via `pe_measure:measure_term/4` (⇓M, Fig. 13) at `(0,0)`, take the min
by cost. Assert the resolver's optimal **cost** `=:=` the oracle's, across
several widths, on small docs (`W` large enough to avoid taint).

- **eunit:**
  - `pe_doc`: hash-cons dedup (identical subtrees → same id); `children/2`
    ordered; `concat(D,D)` → `[D,D]`; `child id < parent id`; `flatten` rewrites
    `nl`→space, distributes through `choice`, returns the same id when nothing
    changes.
  - `pe_cost`: `pe_cost_overflow` (Example 3.4) reproduces the paper's **Fig. 7**
    costs `(20,0)` and `(8,3)` for the two layouts rendered at **column 3**,
    width 6. (This is the unambiguous, paper-verifiable cross-check; the default
    `pe_cost_squared` is exercised via the oracle property.)
  - `pe_measure`: `compose`/`adjust_*`/`dominates`/`measure_term`.
  - `pe_mset`: `merge` keeps the Pareto invariant (sorted by cost asc, no element
    dominates another); `taint`; `Set>Tainted`; `lift`.
  - `pe_memo_ets`: table created and **deleted** per call (`ets:info` shows no
    residual table after `resolve/2`).
- **PropEr (size-bounded, ≤~10 doc nodes):**
  - `prop_resolver_optimal`: resolver cost `=:=` oracle cost over random small
    docs × widths.
  - `prop_mset_pareto`: `merge` of two frontiers yields a valid Pareto frontier.
  - `prop_factory_contracts`: the four Fig. 6 contracts hold for
    `pe_cost_squared` (monotone `combine`; `text_cost` additive decomposition;
    `text_cost(c,0)=text_cost(0,0)`; `le` total).
  - `prop_topo_ids`: `child id < parent id` for all freshly built dags.
- **CT:**
  - `memo_parity_SUITE`: the three backends produce the **identical optimal
    measure** (cost, last, CDoc) on the same docs/widths.
  - `linearity_SUITE`: the paper's `shared <> shared` chain (`mk(n)`) resolves
    with memo size / call count **linear in DAG size**, not exponential.

## Experiment harness (the deliverable we analyze)

A runnable harness (`bench/` escript, or `pe_bench` invoked by an escript) that
prints a reproducible table:

1. **Generator:** synthetic nested S-expression-like docs parameterised by size
   (depth × breadth), using `group` at each level so the resolver faces real
   choices, with sharing where natural. (No real-LFE inputs in this slice —
   that's slice2.)
2. **Sweep:** for each `{backend ∈ {map, ets, pd}, size, width}` run
   `pe_resolve` and record `{time_us (timer:tc, best of N), memo_size, calls,
   tainted?, height}`. (`height` comes from the cost — no rendering needed.)
3. **Report:** a table to stdout and a copy under `bench/results/` (text or CSV).
   Include the linearity series (size → calls, memo_size, time).

Do **not** draw the conclusion — produce the numbers; we analyze the
memo-backend tradeoff and the latency picture together afterward.

## Engineering bar

- `rebar3 compile` **zero warnings**; `rebar3 dialyzer` clean.
- `rebar3 eunit` + `rebar3 ct` green; PropEr passes.
- `proper` as a `{deps,…}` under the `test` profile; otherwise **no runtime
  deps** (pure OTP).
- `-spec` on every exported function; `-doc`/`-moduledoc` on the public surface
  (marked `%% OTP28+`).
- Coverage gate and a full CAP-style strength audit are the **next phase** (we
  run them after this closes) — deferred rows by design.

## Out of scope / handled elsewhere

- **`pe_render` + `pe:format/2` façade + real-LFE inputs** → **slice2** (correctness
  here is cost-level; no text output).
- **Fused resolve/render** (Appendix C) — measures carry `CDoc`; fusion is a
  later perf slice.
- **OTP 22–29 backport** — deferred row; `%% OTP28+` markers in place.
- README / architecture docs — CDC owns docs.
- If the 5-iteration cap strains, raise an amendment to split **slice1a**
  (`pe_doc` + `pe_cost` + `pe_measure` + `pe_mset` + oracle) from **slice1b**
  (`pe_resolve` + memo backends + harness).

## Working ledger (Verify commands authoritative)

Update Status/Evidence (commit SHA + Verify output) per row as you land each;
per-row closing walk (a disposition for every row — `done`/`deferred`/`no-op`,
never a prose summary). Iteration cap: 5.

| ID | Criterion | Verify | Significance | Status |
|----|-----------|--------|--------------|--------|
| A1S1-1  | `pe_doc` constructors + `freeze` + `get/2` via `element/2` | `rebar3 eunit --module=pe_doc_tests` | correctness | open |
| A1S1-2  | hash-consing: identical subtrees intern to same id | eunit `hashcons_test` | correctness | open |
| A1S1-3  | ordered + repeated children: `concat(D,D)` → `[D,D]` | eunit `children_order_repeat_test` | correctness | open |
| A1S1-4  | dense bottom-up ids: child id < parent id | PropEr `prop_topo_ids` | correctness | open |
| A1S1-5  | `flatten` build-time rewrite, identity-preserving, distributes thru `choice` | eunit `flatten_test` | correctness | open |
| A1S1-6  | `pe_cost_squared` satisfies the four Fig. 6 contracts | PropEr `prop_factory_contracts` | serious | open |
| A1S1-7  | Fig. 7 costs `(20,0)`/`(8,3)` reproduced (Example-3.4 factory, col 3, w=6) | eunit `fig7_cost_test` | correctness | open |
| A1S1-8  | `pe_measure` compose/adjust/dominates/`measure_term` correct | eunit `pe_measure_tests` | correctness | open |
| A1S1-9  | `pe_mset` merge keeps Pareto invariant | PropEr `prop_mset_pareto` | correctness | open |
| A1S1-10 | merge `Set>Tainted` + left-biased taint + lift | eunit `pe_mset_tests` | correctness | open |
| A1S1-11 | resolver optimal cost `=:=` oracle, across widths | PropEr `prop_resolver_optimal` + CT | correctness | open |
| A1S1-12 | memo keeps `shared<>shared` linear in DAG size | CT `linearity_SUITE` | serious | open |
| A1S1-13 | 3 memo backends produce identical optimal measure | CT `memo_parity_SUITE` | correctness | open |
| A1S1-14 | `pe_memo_ets` private table created + deleted per call | eunit `ets_lifecycle_test` (`ets:info` before/after) | serious | open |
| A1S1-15 | harness emits `{backend,size,width,time,memo,calls,tainted,height}` table + linearity series under `bench/results/` | run escript; output present | serious | open |
| A1S1-16 | zero-warning compile + dialyzer clean | `rebar3 compile`; `rebar3 dialyzer` | serious | open |
| A1S1-17 | OTP 22–29 compatibility | n/a | polish | deferred — re-entry: backport slice; `%% OTP28+` markers in place |
| A1S1-18 | coverage gate + CAP strength audit | n/a | serious | deferred — re-entry: post-slice1 strength-analysis phase (operator-run) |

## When done

Hand back: the engine core working (constructors → `resolve/2` → optimal
measure); the **oracle ±0** result (resolver optimum cost equals brute force)
with the width set covered; the **linearity** confirmation (memo size/calls vs
DAG size); the **experiment table** (map vs ets vs pd × size × width, with
time, memo, calls, tainted, height) and its file under `bench/results/`; the
green floor (compile/dialyzer/eunit/ct/proper); and the **per-row ledger walk**.
Do not interpret the memo-backend numbers — that's the analysis phase we run
next. Flag explicitly if you split to slice1a/slice1b.
