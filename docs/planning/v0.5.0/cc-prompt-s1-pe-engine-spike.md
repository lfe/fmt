# CC prompt — fmt v0.5.0 · S1: Πₑ engine core + memo-backend experiment

You are CC. Stand up the **core of a BEAM-native port of Πₑ** (PrettyExpressive,
Porncharoenwase et al., OOPSLA 2023) — the generic, optimal, expressive pretty
printer — as a runnable spike, **and** an experiment harness that produces the
numbers we will analyze next: **threaded-map vs ETS vs process-dictionary** for
the resolver's memo, plus a linearity/perf sweep. Target **OTP 28**. Lean and
direct.

**Why it exists:** `lfe/fmt` will format LFE on top of this engine; the engine is
the reusable, novel-on-BEAM piece (no expressive+optimal printer exists for the
BEAM today). This slice proves the algorithm is correct on the BEAM and settles
the memo-backend question with measurements rather than priors.

## Read first (specification — do not re-derive)

- `docs/planning/v0.5.0/pretty-expressive-port-plan.md` — §2 (the algorithm:
  Σₑ, cost factory, measures, measure sets, resolver), §3 (Erlang design,
  module list), §5 (the spike). This is the spec; follow it.
- `docs/research/[2023] Porncharoenwase - A Pretty Expressive Printer.pdf` —
  Fig. 6 (cost-factory contracts), Figs. 12–13 (measures), Fig. 14 (measure
  sets, merge ⊎ / dedup / taint / lift), Fig. 15 (the resolver ⇓RS / ⇓RSC).
  Match these figures; they are the ground truth for behavior.
- The term-DAG store design lives in `erlsci/graffeo`'s
  `workbench/term-dag-tier-from-fmt.md` §2 (the lean representation). If that
  path isn't available to you, the port plan §3.1 carries the same design.

Load **collaboration-framework** (ledger discipline) and **erlang-guidelines**
(`11-anti-patterns` first, then `01-core-idioms`, `02-api-design`,
`04-data-and-types`, `05-functions-and-pattern-matching`, `15-testing`,
`17-tooling`). Validate at the edge, crash in the interior; tagged returns on
the public surface; `-spec` on every exported function.

## OTP target

Write idiomatic **OTP 28**. We (LFE maintainers) ultimately support OTP 22–29,
but **do not** spend effort on old-OTP compatibility now. Where you use a
27/28-only construct (e.g. `-doc`/`-moduledoc` attributes, `maybe`, triple-quoted
strings, sigils), mark the line/region with a `%% OTP28+` comment so the later
backport slice can find them mechanically. The OTP 22–29 backport is a **deferred
ledger row**, not this slice's job.

## Modules (exact surface)

Core engine (`src/`):

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

%% pe_cost — cost factory behaviour + default
-callback le(Cost, Cost) -> boolean().
-callback combine(Cost, Cost) -> Cost.
-callback text_cost(C :: non_neg_integer(), L :: non_neg_integer()) -> Cost.
-callback nl_cost(I :: non_neg_integer()) -> Cost.
%% pe_cost_squared: default factory, width-parameterised; cost = {Badness, Height};
%%   text_cost squared-overflow (b*(2a+b)); nl_cost(_) = {0,1}; le = lexicographic (=<).

%% pe_measure — {Last, Cost, CDoc}; CDoc is a choiceless doc term for rendering
-spec compose(measure(), measure()) -> measure().            %% ◦  (Fig 12)
-spec adjust_nest(non_neg_integer(), measure()) -> measure().
-spec adjust_align(non_neg_integer(), measure()) -> measure().
-spec dominates(measure(), measure()) -> boolean().          %% ⪯ : last≤ ∧ cost≤

%% pe_mset — Set | Tainted; Pareto frontier sorted by cost ascending
-spec merge(mset(), mset(), module()) -> mset().             %% ⊎ (Fig 14), Set>Tainted, left-biased on Tainted
-spec taint(mset()) -> mset().
-spec lift(mset(), fun((measure()) -> measure())) -> mset().
-spec optimal(mset()) -> measure().                          %% head = least cost

%% pe_resolve — the resolver, parameterised by cost factory + memo module + W
-spec resolve(dag(), #{cost := module(), memo := module(),
                       width := non_neg_integer(), limit := non_neg_integer()})
      -> {measure(), Stats :: map()}.                        %% Stats: #{memo_size, calls, tainted}

%% pe_memo — behaviour + 3 backends (pe_memo_map, pe_memo_ets, pe_memo_pd)
-callback new() -> handle().
-callback find(key(), handle()) -> {ok, mset()} | error.
-callback put(key(), mset(), handle()) -> handle().          %% map: new map; ets/pd: same handle

%% pe_render — render a choiceless CDoc faithfully (⇓R)
-spec render(CDoc :: term(), C :: non_neg_integer(), I :: non_neg_integer()) -> iolist().

%% pe — façade
-spec format(dag(), map()) -> iolist().                      %% opts: width, limit, memo, cost, indent
```

Contract points — do not deviate:

- **Children inline in the payload**, never as a side structure:
  `{text, binary(), Width} | nl | {concat, id(), id()} | {nest, N, id()} |
  {align, id()} | {choice, id(), id()}`. This is what makes ordered **and**
  repeated children (`concat(D, D)`) free. No `flatten` node survives `freeze`
  (it is expanded at build time).
- **ids are dense, assigned bottom-up** (children interned before parents), so
  `child id < parent id` is an invariant — a free topological order. The frozen
  store is a **tuple**, read with `element/2`. No maps in the read path for node
  access.
- **Hash-consing** (dedup by content, a build-time `#{payload => id}` map) — off
  the hot path; preserves sharing and dedups repeats.
- **`pe_resolve` threads a memo handle** and returns it, so the *same* resolver
  code runs over all three backends: `pe_memo_map` genuinely threads a new map;
  `pe_memo_ets`/`pe_memo_pd` thread a constant handle and mutate. This is the
  apples-to-apples comparison — one resolver, three backends.
- **`pe_memo_ets` owns a private table per `resolve/2` call and deletes it before
  returning** (use `try … after ets:delete(Tid) end`). No table leak across calls.
- **Width is display width**, not `byte_size` (compute once at `text/2`
  construction; `string:length/1` is fine for now).
- **`optimal` and `taint` both take the head** of the frontier (frontier is
  sorted by cost ascending; head = least cost). Keep that invariant.

## Oracle & tests (this is where correctness is proven)

The Erlang **brute-force oracle** replaces any external reference: widen a doc to
all choiceless docs, render each at `(0,0)`, compute cost via the factory, take
the min. Assert the resolver's optimal cost **equals** the oracle's, across
several widths, on small docs.

- **eunit:** hand-worked fixtures —
  - `pe_doc`: hash-cons dedup (identical subtrees → same id); `children/2`
    ordered; `concat(D,D)` → `children == [D, D]`; `child id < parent id`;
    `flatten` rewrites `nl`→space, distributes through `choice`, returns the same
    id when nothing changes.
  - `pe_cost_squared`: reproduce the paper's **Fig. 7** reference costs (width 6
    → vertical wins; the two layouts' costs match the figure).
  - `pe_measure`/`pe_mset`: `compose`/`adjust_*`/`dominates`; `merge` keeps the
    Pareto invariant (sorted by cost asc, no element dominates another); `taint`
    and `Set>Tainted` preference; `lift`.
  - `pe_render` + `pe:format/2`: end-to-end on the Fig. 7 doc and a few others.
  - `pe_memo_ets`: table created and **deleted** per call (`ets:info` before/after
    shows no residual table).
- **PropEr (size-bounded, ≤~10 doc nodes — match graffeo's discipline):**
  - `prop_resolver_optimal`: resolver cost `=:=` oracle cost over random small
    docs × widths (with `W` large enough to avoid taint).
  - `prop_mset_pareto`: `merge` of two frontiers yields a valid Pareto frontier.
  - `prop_factory_contracts`: the four Fig. 6 contracts hold for
    `pe_cost_squared` (monotone `combine`; `text_cost` additive decomposition;
    `text_cost(c,0)=text_cost(0,0)`; `le` total).
- **CT:**
  - `memo_parity_SUITE`: the three backends produce **identical** optimal output
    on the same docs/widths.
  - `linearity_SUITE`: the paper's `shared <> shared` chain (`mk(n)`) resolves
    with memo size / call count **linear in DAG size**, not exponential.

## Experiment harness (the deliverable we analyze)

A runnable harness (`bench/` escript, or `pe_bench` module invoked by an
escript) that prints a table and is reproducible:

1. **Generator:** nested S-expression-like docs parameterised by size (depth ×
   breadth), using `group` at each level so the resolver faces real choices, with
   sharing where natural. Plus 2–3 **hand-built real LFE snippets** (translate by
   hand from `rebar3_lfe`'s `formatting-gallery` — the knowledge layer doesn't
   exist yet) at width 80.
2. **Sweep:** for each `{backend ∈ {map, ets, pd}, size, width}` run
   `pe_resolve` and record `{time_us (via timer:tc, best of N), memo_size,
   calls, tainted?, lines}`.
3. **Report:** a table to stdout (and a copy under `bench/results/` as text or
   CSV) suitable for us to read directly. Include the linearity series.

Do **not** draw the conclusion yourself — produce the numbers; we analyze the
memo-backend tradeoff and the latency picture together afterward.

## Engineering bar

- `rebar3 compile` **zero warnings**; `rebar3 dialyzer` clean.
- `rebar3 eunit` + `rebar3 ct` green; PropEr properties pass.
- `proper` as a `{deps,…}` under the `test` profile; otherwise **no runtime
  deps** (pure OTP).
- `-spec` on every exported function; `-doc`/`-moduledoc` on the public surface
  (marked `%% OTP28+`).
- Coverage gate and a full CAP-style strength audit are the **next phase** (we
  run them after this closes) — not a row here, by design.

## Out of scope / handled elsewhere

- The **LFE knowledge layer** (formatter-map, conventions) — later arc.
- The **fused resolve/render** optimization (Appendix C) — measures carry the
  choiceless `CDoc` for now; fusion is a later perf slice.
- **OTP 22–29 backport** — deferred row; markers in place.
- README / architecture docs — leave them; CDC owns docs.
- If the 5-iteration cap strains, raise an amendment to split **S1a** (pe_doc +
  pe_cost + pe_measure + pe_mset + oracle) from **S1b** (pe_resolve + memo
  backends + render + harness).

## Working ledger (Verify commands authoritative)

Update Status/Evidence (commit SHA + Verify output) per row as you land each;
per-row closing walk (a disposition for every row — `done`/`deferred`/`no-op`,
never a prose summary). Iteration cap: 5.

| ID | Criterion | Verify | Significance | Status |
|----|-----------|--------|--------------|--------|
| S1-1  | `pe_doc` constructors + `freeze` + `get/2` via `element/2` | `rebar3 eunit --module=pe_doc_tests` | correctness | open |
| S1-2  | hash-consing: identical subtrees intern to same id | eunit `hashcons_test` | correctness | open |
| S1-3  | ordered + repeated children: `concat(D,D)` → `[D,D]` | eunit `children_order_repeat_test` | correctness | open |
| S1-4  | dense bottom-up ids: child id < parent id | PropEr `prop_topo_ids` | correctness | open |
| S1-5  | `flatten` build-time rewrite, identity-preserving, distributes thru `choice` | eunit `flatten_test` | correctness | open |
| S1-6  | `pe_cost_squared` satisfies the four Fig. 6 contracts | PropEr `prop_factory_contracts` | serious | open |
| S1-7  | Fig. 7 reference costs reproduced | eunit `fig7_cost_test` | correctness | open |
| S1-8  | `pe_measure` compose/adjust/dominates correct | eunit `pe_measure_tests` | correctness | open |
| S1-9  | `pe_mset` merge keeps Pareto invariant | PropEr `prop_mset_pareto` | correctness | open |
| S1-10 | merge `Set>Tainted` + left-biased taint + lift | eunit `pe_mset_tests` | correctness | open |
| S1-11 | resolver optimal `=:=` oracle, across widths | PropEr `prop_resolver_optimal` + CT | correctness | open |
| S1-12 | memo keeps `shared<>shared` linear in DAG size | CT `linearity_SUITE` | serious | open |
| S1-13 | 3 memo backends produce identical optimal output | CT `memo_parity_SUITE` | correctness | open |
| S1-14 | `pe_memo_ets` private table created + deleted per call | eunit `ets_lifecycle_test` (`ets:info` before/after) | serious | open |
| S1-15 | `pe_render` faithful + `pe:format/2` end-to-end | eunit `pe_render_tests` + CT | correctness | open |
| S1-16 | experiment harness emits `{backend,size,width,time,memo,tainted}` table + LFE snippets + linearity series | run escript; output present under `bench/results/` | serious | open |
| S1-17 | zero-warning compile + dialyzer clean | `rebar3 compile`; `rebar3 dialyzer` | serious | open |
| S1-18 | OTP 22–29 compatibility | n/a | polish | deferred — re-entry: backport slice; `%% OTP28+` markers in place |
| S1-19 | coverage gate + CAP strength audit | n/a | serious | deferred — re-entry: post-S1 strength-analysis phase (operator-run) |

## When done

Hand back: the engine core working (constructors → resolve → render); the
oracle ±0 result (resolver optimum equals brute force) with the width set
covered; the linearity confirmation (memo size/calls vs DAG size); the
**experiment table** (map vs ets vs pd × size × width, with timings, memo sizes,
tainted flags) and its file under `bench/results/`; the green floor
(compile/dialyzer/eunit/ct/proper); and the **per-row ledger walk**. Do not
interpret the memo-backend numbers — that's the analysis phase we run next. Flag
explicitly if you split to S1a/S1b.
