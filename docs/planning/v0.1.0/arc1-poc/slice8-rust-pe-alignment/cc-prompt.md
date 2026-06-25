# CC prompt — arc1-poc / slice8 — alignment with Rust `pretty-expressive` (mjl)

> For CC (implementation seat). **Read `slice-doc.md` first.** Load
> **erlang-guidelines** (`11-anti-patterns` first, then `04-data-and-types`,
> `05-functions`, `15-testing`; `10-performance` for the resolver clauses). For
> the oracle binary, load **rust-guidelines** (`11-anti-patterns` first). Walk
> the ledger; CDC verifies independently. Iteration cap: 5.
>
> **Reference of record: mjl specifically.** Source of truth is
> `rust/mjl/pretty-expressive/src/` (`lib.rs`, `cost.rs`, `measure.rs`,
> `print.rs`). When our behaviour and mjl's differ, **mjl wins** — including its
> computation-width default and its smart-constructor normalisation. Read the
> actual mjl source; do not reconstruct it from this prompt.

## Goal

Bring the BEAM Πₑ engine into **observable alignment** with mjl: add the missing
document-algebra constructors (`fail`, `brk`, `hard_nl`, `reset`, `full`,
`cost`) with mjl's smart-constructor normalisation, change the `limit` default
to mjl's `trunc(1.2 × width)`, and prove the alignment with a **differential
oracle** that runs the same documents through mjl and through `pe` and compares.

Engine-only. Do **not** touch any LFE knowledge layer / `formatter-map`.

## Ground truth — the seams (don't hunt)

**Ours:**
- `src/pe_doc.erl` — builder + DAG. Constructors `text/2 nl/1 concat/3 nest/3
  align/2 choice/3 flatten/2 group/2 vconcat/3`; payloads `{text,_,_} | nl |
  {concat,_,_} | {nest,_,_} | {align,_} | {choice,_,_}`; `flatten_payload/2`.
- `src/pe_mset.erl` — `mset() :: {set,[M,...]} | {tainted,fun()}`. **No empty/
  failed variant.** `merge/3`, `taint/1`, `singleton/1`, `lift/2`.
- `src/pe_measure.erl` — `measure() :: {Last, Cost, CDoc}`; `text_leaf/5`,
  `nl_leaf/_`, `adjust_nest/2`, `adjust_align/2`, `measure_term/5`.
- `src/pe_resolve.erl` — `resolve_node/4` dispatches on payload (lines ~170–175:
  `text/nl/concat/nest/align/choice`). `resolve_align` sets `I=C`;
  `resolve_nest` uses `I+N`.
- `src/pe.erl` — `with_defaults/1`: `limit => maps:get(limit, Opts, Width)`.
- `test/` — `pe_gen` (random DAG generator + `oracle_optimal` brute force);
  `prop_pe_resolve` (`prop_resolver_optimal`).

**mjl:**
- `lib.rs` — `enum DocKind { Newline(Option<String>) Fail Text Concat Alt Align
  Reset Nest Full Cost }`; constructor bodies + the `BitAnd` (concat) and
  `BitOr` (choice) smart constructors; `flatten`, `group`.
- `cost.rs` — `DefaultCostFactory` (already matches `pe_cost_squared`);
  `limit() = computation_width.unwrap_or((1.2*page_width) as usize)`.
- `measure.rs` — `MeasureSet::{Failed, Valid, Tainted}`, `merge`, `dominates`,
  `concat`.
- `print.rs` — the Printer: **authority for how `Full`, `Reset`, `Cost`,
  `Newline` variants resolve.** Read this for `full` (Step 5).

## Design constraints (hold these)

- **Two oracles, both green.** Every new node must (a) keep the existing in-BEAM
  oracle property (`resolver cost =:= pe_gen:oracle_optimal`) — so extend
  `pe_gen` to emit the new nodes — and (b) pass the new mjl differential oracle.
- **`failed` is identity for merge.** Adding `fail` means `pe_mset` gains an
  empty/failed set; `merge(failed, X) = X`, `merge(X, failed) = X`. Mirror
  mjl `measure.rs` `(Failed, o)=>o` exactly. A `fail` node resolves to `failed`.
- **Match mjl's peepholes, but know which are load-bearing.** The `fail`/`full`
  arms are semantic; the rest (`(Text 0,_)`, `(_,Text 0)`, `(Text,Text)` merge,
  cost push-out, nest/align/reset short-circuits) are output/cost-transparent —
  implement them to match mjl, but the oracle is the gate, not the peephole.
- **Do not copy mjl's memo internals** (`memo_weight`, `MEMO_LIMIT`,
  `newline_count`, `Rc` identity). Our memo backends stay as-is.
- **ASCII-only oracle corpus.** Keep generated text ASCII so display width =
  byte length and the string-recomputed cost is unambiguous.
- **`full` is the deferral valve.** If it exceeds budget, defer it (re-entry:
  "port `Full` + its measure-lock from `print.rs`") and land the rest.

## Steps

1. **`fail` + the `failed` mset (keystone).**
   `pe_mset`: add the failed/empty variant; make `merge/3` treat it as identity
   on both sides; decide its interaction with `tainted` (a `failed` beside a
   `{set,_}`/`{tainted,_}` yields the other). `pe_resolve`: a `fail` payload →
   `failed`. `pe_doc`: `fail/1`; `flatten(fail)=fail`; concat
   `(fail,_)|(_,fail)=>fail`; choice `(fail,_)=>rhs`, `(_,fail)=>self`. Tests:
   `fail()` alone has no valid layout; `choice(fail, d)=d`; `concat(fail,d)`
   fails.

2. **`brk` / `hard_nl` (newline variants).**
   `pe_doc`: generalise the `nl` payload to carry a flatten target
   (`{text,Bin} | fail`); `nl/1` → `" "`, `brk/1` → `""`, `hard_nl/1` → `fail`.
   `flatten_payload` for the newline uses that target (so
   `flatten(hard_nl)=fail`). Resolver/measure treat all three identically when
   *not* flattened (a real newline of height 1). Tests mirror mjl's
   `newline` doctest (`[`,`brk`,`a`,`nl`,…) flat vs broken.

3. **`reset` (indent → 0).**
   `pe_doc`: `reset/1` + smart-ctor short-circuit (`fail|align|reset|text`→`d`;
   `cost`→push out). `pe_resolve`: `resolve_reset` = `resolve_align` but with
   `I=0` (resolve `D` at `(C, 0)`), then a `pe_measure:adjust_reset` mirroring
   `adjust_align`. Test: mjl's `reset` doctest (the `'''` multiline-string
   example) reproduced.

4. **`cost` (explicit cost injection).**
   `pe_doc`: `cost/2` carrying a cost value in the active `pe_cost` module's
   representation; `cost(c, fail)=fail`; push-out arms in concat/nest/align/
   reset. `pe_resolve`: `resolve_cost` `combine`s `c` into every measure of the
   inner set. Test: mjl's `cost` doctest (the `DefaultCost(0,2)` example forcing
   the taller layout).

5. **`full` (locked last line) — READ `print.rs` FIRST.**
   `pe_doc`: `full/1` (idempotent: `full(full(d))=full(d)`; `full(fail)=fail`)
   + the concat arm `(full,text)=>fail` ordered **after** `(_,text0)=>self`
   (so `full(x) & text("")` = the full doc). The general constraint — no
   non-empty text after `full` on the same line — is enforced where mjl enforces
   it (`print.rs`); port that representation into `pe_measure`/`pe_resolve`
   (likely an added "last line locked" marker on the measure). Tests: mjl's
   `full` doctests (comment-then-`nl`-then-code ok; comment-then-code fails;
   comment-then-`text("")` ok). **If this step blows the budget, stop, mark
   `full` deferred per the valve, and ensure 1–4 + 6 + 7 stand alone.**

6. **Smart-constructor parity sweep.**
   Audit `pe_doc` concat/choice/nest/align/reset against mjl's `BitAnd`/`BitOr`/
   `nest`/`align`/`reset` arms; add the transparent peepholes
   (`(Text 0,_)=>rhs`, `(_,Text 0)=>self`, `(Text,Text)` merge, cost push-out,
   the `fail|align|reset|text` short-circuits). Keep them pure construction-time.

7. **`limit` default → mjl's.**
   `pe.erl` `with_defaults`: `limit => maps:get(limit, Opts, trunc(1.2 * Width))`.
   Note the change in `docs/planning/v0.1.0/arc1-poc/running-recommendations.md`
   (a reviewed-change entry) and the slice commit. Re-run the corpus latency
   check (slice6 path) and record any movement — a larger `W` explores more
   layouts (the `W⁴` factor), so watch the guard_SUITE tail.

8. **The mjl differential oracle.**
   - **Wire format:** a canonical, ASCII, line- or S-expr-encoded serialisation
     of a `pe_doc` over the full algebra (`text/nl/brk/hard_nl/fail/concat/nest/
     align/reset/full/cost/choice`). Unambiguous; one parser each side.
   - **Rust oracle** under `test/oracle/` (tiny standalone cargo crate depending
     on a pinned mjl): read a doc from stdin/arg, build the mjl `Doc`, render
     with `DefaultCostFactory::new(width, Some(limit))`, print the layout to
     stdout. Width + limit are CLI args.
   - **Erlang driver** (`test/pe_oracle_mjl.erl` or similar): build random docs
     (extend `pe_gen` to the new nodes), serialise, run both `pe:format_binary`
     and the Rust binary at the same `(width, limit)`, recompute
     `{badness, height}` from each output string
     (`badness = Σ_lines max(0, len(line)−width)²`, `height = newlines`), and
     assert **equal cost** across a width sweep (e.g. `W ∈ {20,40,80}`,
     `limit = trunc(1.2*W)`). For docs with a unique optimum, assert **identical
     output**.
   - Make target / rebar3 alias (`make oracle`) building the crate then running
     the property. Keep it out of the default `rebar3 ct` (see slice-doc open
     question 1) unless the operator says otherwise.

9. **Extend the in-BEAM oracle.** Update `pe_gen` so `oracle_optimal` and
   `prop_resolver_optimal` exercise the new node types; the brute-force
   widen→measure→min must understand `fail`/`full`/`reset`/`cost`/newline
   variants so it stays a valid reference.

10. **Closing report.** State, with evidence: which constructors landed; the mjl
    oracle result (equal cost over N random docs × width sweep, identical text
    on unique optima); the `limit`-default latency movement; and the disposition
    of `full` (landed or deferred-with-re-entry).

## Ledger

See `ledger.md` (authored alongside this prompt). Walk it row by row; every row
reaches `done` / `deferred` / `no-op` with reproducible evidence before close.
