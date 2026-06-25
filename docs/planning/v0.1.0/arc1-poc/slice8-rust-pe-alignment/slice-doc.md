# Slice 8 — alignment with the Rust `pretty-expressive` (mjl)

> Design + scope. Companion: `cc-prompt.md`, `ledger.md`. Arc: arc1-poc.
> Slug proposed; rename freely. CDC-authored (Cowork chat seat) for CC.

## Why this slice exists

`mjl/pretty-expressive` (`crates.io`, v1.0.0, `git.midna.dev/mjm/mjl`) is a Rust
port of the **same** Πₑ printer we are porting to the BEAM — itself a port of
the official Racket and OCaml libraries. We read its source side-by-side with
ours and the result is reassuring at the cost layer and instructive at the
algebra layer:

- **The cost factory is byte-identical.** mjl's `DefaultCostFactory` and our
  `pe_cost_squared` compute the same squared-overflow badness
  (`b·(2a+b)`, `a = max(W,c)−W`, `b = stop−max(W,c)`), the same `{0,1}` newline
  height, componentwise `combine`, and lexicographic order. Nothing to
  reconcile here. (Verified: `mjl .../src/cost.rs` vs `src/pe_cost_squared.erl`.)
- **The document algebra diverges — we implement a strict subset.** mjl's
  `DocKind` is `Newline(Option<String>) | Fail | Text | Concat | Alt | Align |
  Reset | Nest | Full | Cost`. Ours (`pe_doc.erl`) is `text | nl | concat |
  nest | align | choice` only. We are missing **`fail`, `brk`/`hard_nl`
  (newline variants), `reset`, `full`, and `cost`**, plus mjl's
  smart-constructor normalisation.
- **One default differs.** Our `limit` (the computation width `W`) defaults to
  the page width (1.0×); mjl defaults to `1.2 × page_width`
  (`(1.2 * page_width as f64) as usize`). raco/`pretty-expressive` ships
  `current-width 102` / `current-limit 120` (≈1.18×). This changes which
  layouts are explored vs. tainted, and therefore can change the chosen
  optimum.

**Decision of record (operator, 2026-06-24):** the alignment target is **mjl
specifically** — match its concrete choices, including its computation-width
default and its node-normalisation smart constructors — not merely the paper.
Scope is **full**: build the differential oracle, add the missing constructors,
**and** change the `limit` default to mjl's.

This is the slice that makes "ours is a faithful Πₑ" a *checked* claim rather
than a read-the-papers belief, and closes the algebra gaps that the LFE
knowledge layer (and comment formatting in particular) will need.

## What "alignment" buys us beyond the existing oracle

slice1 already gives us the strongest correctness gate at the cost level: the
resolver optimum `=:=` an **in-BEAM brute-force oracle** (`pe_gen:oracle_optimal`,
widen→measure→min). That oracle is decisive but has one blind spot — it shares
our own `pe_measure`/`pe_cost` code, so a *systematic* bug living in both the
resolver and the brute-force measure would pass. A **second, independent
implementation** (mjl, different language, different author, same paper) catches
exactly that class. The two oracles are complementary:

| Oracle | Catches | Blind to |
|--------|---------|----------|
| in-BEAM brute force (slice1) | resolver ≠ our own measure spec | a bug shared by resolver + our measure |
| mjl differential (this slice) | our measure/algebra ≠ an independent Πₑ | bugs mjl *also* has (unlikely to coincide) |

## The two-implementation cost model (reported cost is canonical)

> **Corrected in iteration 1.** This section originally said the oracle does not
> need mjl to expose its cost — "a string is enough", because the
> squared-overflow identity is recomputable per line. That holds *only* for
> cost-free documents: an injected `cost` node contributes to the engine's
> internal cost while being **invisible** in the rendered string, so
> string-recompute cannot see it (which is why 8a had to exclude `cost`). The
> property the two engines are specified to share is the **reported optimal
> cost**, and both expose it — mjl via `PrintResult::cost()` (`print.rs:240`),
> us via `pe_measure:cost/1`. The model below is the corrected one.

The canonical comparator is **reported-cost equality**: render the same doc on
both sides at the same `(width, limit)`, take each engine's own
`{badness, height}` for the chosen layout, and compare those. Πₑ guarantees both
engines reach the same optimal *cost*, never the same *string*, so this is the
right invariant — and it re-admits `cost` (an injected cost shows up identically
in both reported costs) and closes the blind spot for any future invisible-cost
feature.

The **string-recomputed** cost — `badness = Σ_lines max(0, width(line) − W)²`,
`height = count('\n')` — remains useful as a *secondary* check: on a cost-free,
in-bounds document it equals the reported cost (a cheap cross-check, used by
`pe_wire_tests` and the samples CSV), and byte identity is expected on
unique-optimum documents. But neither gates the oracle; reported cost does.

**Parity caveat:** "width(line)" must be the same metric on both sides
(`display` columns, not bytes). The generator stays **ASCII-only** so byte
length = display width and the recompute is unambiguous. Unicode-width parity is
a non-goal for this slice.

**Bound caveat (A1-R018):** reported-cost equality holds only where our paper
`LineM` indentation charge is zero, i.e. indentation ≤ width. The corpus is
bounded (nests 0..2, depth-capped, sweep ≥ 40) so this never trips; growing the
corpus to indentation-overflow cases is gated on resolving the divergence.

## The gaps, grounded in code

Each item names the mjl source, our seam, and observable vs. transparent
status. "Transparent" = changes DAG identity but not rendered output or cost;
"semantic" = changes observable behaviour.

1. **`fail` (semantic).** mjl: `DocKind::Fail`; `flatten(fail)=fail`; concat
   `(Fail,_)|(_,Fail)=>fail`; choice `(Fail,_)=>rhs`, `(_,Fail)=>self`; measure
   `MeasureSet::Failed`, merge identity (`(Failed,o)=>o`). **Ours has no empty
   set:** `pe_mset:mset()` is `{set,[M,...]}` (non-empty) `| {tainted,_}`. So
   `fail` requires a new **`failed`** mset variant (or an explicit empty set),
   `merge` identity on it, a `resolve_node` `fail` clause returning it, and
   `pe_doc:fail/1` + the flatten/concat/choice short-circuits. This is the
   structural keystone — `hard_nl` depends on it.

2. **`brk` / `hard_nl` (semantic).** mjl: `Newline(Option<String>)` — `nl`
   flattens to `" "`, `brk` to `""`, `hard_nl` (`None`) **fails** to flatten.
   Ours: a single `nl` whose `flatten_payload(nl) = text(" ")`. Parameterise the
   newline node to carry its flatten target (`{nl, FlatTarget}` where
   `FlatTarget :: {text, Bin} | fail`), add `brk/1` and `hard_nl/1`, and make
   `flatten(hard_nl) = fail`.

3. **`reset` (semantic, low).** mjl: `Reset(Doc)` — indentation set to 0 while
   rendering `d`. Near-twin of our existing `align` (`resolve_align` sets
   `I = C`); `reset` sets `I = 0`. Add `pe_doc:reset/1`, a `resolve_reset`
   clause, and `pe_measure:adjust_reset`. Mirror mjl's smart-ctor
   short-circuits (below).

4. **`full` (semantic, HIGHEST RISK).** mjl: `Full(Doc)` — `d` must not be
   followed by more text on the same line, else the layout fails (the line-
   comment constraint). The construction-time peephole `(Full(_), Text(_,_)) =>
   fail` only covers *immediate* adjacency; the general constraint (text after
   `full` through concats/choices/newlines) is enforced in the **Printer**
   (`mjl .../src/print.rs`), and the `Measure` struct shown in `measure.rs`
   carries only `{last, cost, layout}` with no visible "locked" flag — so the
   representation of the constraint must be read out of `print.rs`, not guessed.
   This is the one item that may require measure-level surgery beyond a new node
   clause. **Designated deferral valve** (see Risk).

5. **`cost` (semantic, low–moderate).** mjl: `Cost(C, Doc)` — adds `c` to the
   doc's cost; `cost(c, fail)=fail`; pushed outward through nest/align/reset/
   concat smart-ctors. Add `pe_doc:cost/2` (carrying a `pe_cost`-module value),
   a `resolve_cost` clause that `combine`s `c` into each measure, and the
   push-out peepholes.

6. **Smart-constructor normalisation (mixed).** Match mjl's peepholes:
   - concat: `(Text 0,_)=>rhs`, `(_,Text 0)=>self`, `(Text,Text)=>merge`,
     cost push-out, plus the `fail`/`full` arms (semantic). The non-fail/full
     arms are **transparent** (output/cost-preserving) — match for DAG-identity
     parity, but the oracle does not depend on them.
   - choice: `(Fail,_)=>rhs`, `(_,Fail)=>self` (semantic).
   - nest/align/reset: short-circuit on `Fail | Align | Reset | Text` → return
     `d`; `Cost(c,d)` → push cost out. (Transparent: nesting/aligning a
     no-newline or indentation-overriding node is identity.)

7. **`limit` default → mjl's (behavioural).** `pe.erl` `with_defaults`:
   `limit => maps:get(limit, Opts, Width)` becomes
   `limit => maps:get(limit, Opts, trunc(1.2 * Width))` — mjl's exact
   truncating arithmetic. This is a deliberate, **ledgered** change to a
   documented default (it is therefore not a silent default rewrite — cf.
   `CLAUDE.md` safety-gate philosophy; the rule forbids *silent* changes, not
   reviewed ones). Record it in `running-recommendations.md` and the changelog.

## Risk and sequencing — `full` is the valve

The honest size of this slice is larger than one mergeable diff. The
recommended landing is **two diffs under one plan**:

- **8a** — the oracle harness + `fail` (with the `failed` mset) +
  `brk`/`hard_nl` + `reset` + `cost` + the smart-ctors + the `limit` default.
  Self-contained; every new node is observable and oracle-checkable.
- **8b** — `full` and whatever measure-level representation its constraint
  needs, read from `print.rs`.

If porting `full` exceeds the five-iteration budget, **`full` is the designated
deferral** with re-entry condition "port `Full` + its measure-lock
representation from `mjl/.../print.rs`"; everything else still lands and the
alignment claim is scoped honestly to "full algebra minus `full`". Do **not**
let `full` silently balloon 8a.

## What "match mjl" does NOT mean (anti-over-matching)

mjl is a Rust program with Rust-specific machinery that is **not** part of the
Πₑ algebra and must not be copied:

- **Memoisation internals.** `memo_weight`, `MEMO_LIMIT`, per-node
  `newline_count` as mjl threads them, and `Rc`-identity caching are mjl's
  memo heuristics. Our memoisation is `pe_memo_{map,ets,pd}` and stays as-is.
  Match the *doc algebra and cost*, not the cache.
- **The 3-tuple vs 2-tuple cost shape.** raco carries `(badness height _)`;
  mjl and we both use a 2-tuple. No change.
- **`to_string()`'s implicit width.** The oracle binary takes `(width, limit)`
  explicitly via `DefaultCostFactory::new(width, Some(limit))`; never rely on
  mjl's default-80.

## Scope / non-goals

- **In:** the six algebra additions (`fail`, `brk`, `hard_nl`, `reset`, `full`,
  `cost`) + smart-ctor normalisation in `pe_doc`; the `failed` mset variant +
  merge identity in `pe_mset`; the matching `resolve_*` clauses + measure
  adjusts; the `limit` default change in `pe.erl`; the **mjl differential
  oracle** (Rust oracle binary + Erlang generator/serialiser/driver + width
  sweep); extension of `pe_gen` + the in-BEAM oracle property to cover the new
  nodes; a closing parity report.
- **Out:** any LFE knowledge-layer / `formatter-map` change (this is engine-only
  — the new combinators are consumed by slice3+ later); the cost factory (already
  identical); mjl's memo internals; Unicode display-width parity (ASCII-only
  oracle corpus); OTP 22–29 backport; coverage gate + CAP audit (carried arc
  deferrals).

## Open questions for the operator (non-blocking; CC may propose)

1. **Oracle's home in the tree + CI.** Recommended: the Rust oracle lives under
   `fmt/test/oracle/` as a tiny standalone cargo crate, built on demand and
   driven by a `make oracle` target / rebar3 alias and a **dedicated** CI job —
   **not** wired into the default `rebar3 ct` (keeps the BEAM unit CI
   Rust-toolchain-free, as `bench/` is kept separate). Override if you want it
   blocking.
2. **mjl pinning.** Pin an exact mjl version/commit (it is pre-1.0 in spirit
   despite the `1.0.0` tag) and record it, so the oracle is reproducible.

## Closing report (A1S8-22)

**Constructors landed (8a).** The BEAM Πₑ engine now spans the mjl document
algebra minus `full`: `fail` (with the `failed`/empty `pe_mset` that is the
merge identity, mirroring `measure.rs` `(Failed,o)=>o`), the three newline
variants `nl`/`brk`/`hard_nl` (flatten targets `" "`/`""`/`fail`), `reset`
(indentation → 0, with `resolve_reset` + `adjust_reset`), and `cost` (explicit
injection via `resolve_cost` + `add_cost`). mjl's smart-constructor
normalisation is reproduced arm-for-arm (`concat_smart/5` in mjl `bitand`
order; `choice`/`nest`/`align`/`reset` short-circuits; cost push-out). The
build-time `flatten` distributes through all of it. Evidence: 12 mjl-doctest
reproductions in `pe_algebra_tests`, the `pe_doc_tests` smart-ctor sweep, and
both oracles below.

**mjl differential oracle.** A pinned mjl `pretty-expressive` (`=1.0.0`) Rust
binary (`test/oracle/`) renders the same documents as `pe`, driven by
`pe_oracle_mjl` over a shared ASCII S-expression wire format. The canonical
comparator is **reported-cost equality** — each engine's own `{badness, height}`
for the chosen layout (mjl `PrintResult::cost()`, us `pe_measure:cost/1`); byte
identity is a secondary statistic (Πₑ shares the optimal *cost*, not the
*string*). Over the width sweep {40, 80, 120}, **6000/6000 cases agree on
reported cost** including cost-bearing documents, with 5956/6000 byte-identical
(the 44 differences are equal-cost ties — we deliberately do not replicate mjl's
`Rc`-identity memo tie-break). One corpus bound remains a documented finding,
not an engine bug: widths start at 40 to keep the newline-cost divergence below
unexercised. A 36-row `bench/results/oracle_samples.csv` (including cost-bearing
rows whose injected cost is invisible in the string but equal in both reported
costs) lets a verifier cross-check independently.

> **Iteration 1 (reported-cost comparator).** 8a compared cost *recomputed from
> the rendered string*, which cannot see an injected `cost` node, so 8a excluded
> `cost` from the corpus (with compensating in-BEAM coverage). Iteration 1
> switched the comparator to the reported optimal cost both engines already
> expose, re-admitting `cost`: the 6000 cost-free cases are unchanged (there
> reported cost == string-recompute) and cost-bearing documents now pass on
> reported cost. The 8a string-recompute result stands as the prior evidence,
> refined — not deleted.

**Newline-cost divergence (kept ours).** mjl's `print.rs` charges a broken
newline `(0,1)` with no indentation penalty; ours charges the paper's LineM
`text_cost(0,I)`. They differ only when an indentation level alone exceeds the
page width. Per operator decision (2026-06-24) we keep the paper-faithful cost
and bound the oracle corpus so the divergence is never exercised. Recorded as
A1-R018.

**`limit`-default latency movement.** Changing the computation-width default
from `Width` to `trunc(1.2 × Width)` (matching mjl `cost.rs`) moves real-LFE
corpus latency within noise — same-process A/B over 510 forms: W60 +6.6%,
W80 −1.3%, W100 +0.6% (best-of-5). The wider limit explores more of the `W⁴`
layout space but the real corpus shows no pathological tail; synthetic
stress/guard rows pin `limit` explicitly and are unaffected. Reviewed, not
silent: recorded in `CHANGELOG.md` and A1-R017.

**`full` disposition: deferred (valve fired).** `full/1` (the locked-last-line
line-comment constraint) is not implemented; the engine carries no `full` node.
Rows A1S8-1..8 and 10..23 stand without it — the slice is honestly scoped to
"full algebra minus `full`". Re-entry condition: **port mjl's `Full` plus its
last-line measure-lock from `print.rs`** (idempotent ctor, `full(fail)=fail`,
concat arm `(full,text)=>fail` ordered after `(_,text0)=>self`, and the
measure-level "no non-empty text after `full` on a line" lock), then reproduce
mjl's three `full` doctests and add it to both oracles' generators.

**Green floor.** `rebar3 compile` (warnings-as-errors) / `xref` / `dialyzer`
clean; `cargo clippy` clean; `rebar3 eunit` 246/0, `rebar3 proper` 8/8,
`rebar3 ct` 2/2.
