# Porting Πₑ (PrettyExpressive) to the BEAM — research synthesis + port plan

> Status: **research draft, for Duncan's review.** Distilled from the
> Porncharoenwase/Pombrio/Torlak OOPSLA 2023 paper (`workbench/[2023] …
> A Pretty Expressive Printer.pdf`) and a full read of the reference Racket
> formatter source (`racket/fmt`, ~1500 LOC) and the `pretty-expressive`
> usage it exercises. Confidence is marked inline. Nothing here is committed;
> it exists to make the next decisions concrete.

## 0. The decision this serves

We are building a **standalone Erlang library** — a BEAM-native port of the
Πₑ pretty printer (the engine) plus an LFE formatter (the knowledge layer)
built on top — which `rebar3_lfe` will consume as a dependency, its `format`
provider becoming a thin wrapper (the `raco fmt` analog). To our knowledge no
expressive-*and*-optimal pretty printer exists for the BEAM today; the closest
relatives (`erlfmt_algebra`, Elixir's `Inspect.Algebra`, OTP's `prettypr`) are
all Wadler-family greedy-`group` printers. This would be the first.

The library splits cleanly in two, and this document is about the **engine**
only:

- **Engine** (`pretty-expressive` port): generic, knows nothing about LFE or
  any form. Document algebra Σₑ + a user-supplied *cost factory* + the
  resolver Πₑ that finds the optimal layout. This is the reusable, novel-on-
  BEAM piece.
- **Knowledge** (the LFE formatter): a composable `formatter-map` over a
  palette of layout combinators. Separate document; depends on the engine.

## 1. Why Πₑ and not a Wadler-style algebra

The reason to pay for Πₑ rather than adopt the greedy `erlfmt_algebra` is that
the *clean, declarative, extensible knowledge layer* — the entire point of the
rewrite — depends on three engine features that Wadler `group` does not give:

- **arbitrary choice** (`<|>`): offer *any* two layouts, not just flat-vs-
  broken of one group;
- **a cost factory**: the optimality objective is data, supplied by the caller;
- **global optimality**: the engine picks the cost-minimal layout over the
  whole document, not a greedy local fit.

In `racket/fmt`'s `conventions.rkt` these are used pervasively and
substantively (`alt`, `cost`, and the `fail` document appear throughout
`format-#%app`, `format-define`, `format-parameterize`, `format-struct`).
Strip them out and the per-form definitions collapse back into imperative
fitting decisions — i.e. back toward the 1387-line `r3lfe_formatter.erl` we
are trying to retire. So the engine choice is not free: the conventions-grade
cleanliness *requires* the expressive solver. (Confidence: high — read from
source.)

## 2. Πₑ in one page (what we are porting)

### 2.1 The language Σₑ (Fig. 4)

Seven core constructs. Everything else is derived sugar.

```
d ::= text s          -- a string with no newline
    | nl              -- a newline (becomes a single space under flatten)
    | d <> d          -- UNALIGNED concatenation (traditional PPL)
    | nest n d        -- increase indentation level by n
    | align d         -- set indentation level to the current column
    | flatten d       -- replace all nl in d with a space
    | d <|> d         -- ARBITRARY choice between two layouts
```

Σₑ is proven strictly more expressive than both the "traditional" (Wadler/
Leijen) and "arbitrary-choice" (Bernardy) families, because it has *both*
unaligned `<>` (undefinable in the arbitrary-choice PPL) and arbitrary `<|>`
+ `align` (undefinable in the traditional PPL). Derived forms we'll want:
`group d = d <|> flatten d`; `d <$> d = d <> nl <> d` (vertical concat);
`d <+> d` = aligned concat (= `<> align`); plus `space`, `empty`, `hard-nl`,
and a `fail` document (an empty choice — a layout that can never be selected;
used to forbid a layout alternative).

Two subtleties that bit the authors and will bite us (both verified against
the semantics, Figs. 8–9):

- `align` *overrides* the indentation level (sets `i := c`); `nest` is
  *relative* (`i := i + n`). They do not compose the way intuition suggests
  (paper Example 3.2). Indentation level must be tracked explicitly,
  separately from column position.
- `<>` is genuinely unaligned: the right operand starts at the *column where
  the left operand ended*, not at a fixed indent. This is what makes document
  structure mirror AST structure (the whole ergonomic argument of §5.3).

### 2.2 The cost factory (Fig. 6) — the optimality objective as a parameter

A cost factory is a totally-ordered monoid with translational invariance.
The caller supplies a cost type `τ` and four operations:

```
≤F   : τ → τ → bool          -- total order (compare costs)
+F   : τ → τ → τ             -- combine costs (associative; identity textF(0,0))
textF: nat → nat → τ         -- cost of text of length l starting at column c
nlF  : (nat → τ)             -- cost of a newline + i indent spaces  (impl form)
```

Contracts that must hold (these are what license the pruning — do not skip
them): `≤F` total; `+F` monotone in both args; `textF` monotone in `c`;
`textF(c, l1+l2) = textF(c,l1) +F textF(c+l1,l2)`; `textF(c,0) = textF(0,0)`.
(The paper's Fig. 6 lists `nlF` as a constant; §7 and the Racket impl upgrade
it to the procedure form `nlF(i)` so the newline+indent cost is customizable.
We port the procedure form.)

The **default factory** (paper Example 3.5; confirmed verbatim in
`racket/fmt/main.rkt`'s `cost-factory`): cost = `(badness, height)` compared
lexicographically, where `badness` is the **sum of squared overflow past the
width** and `height` is the newline count, with a final tiebreaker. Concretely:

```
τ = (badness, height, tiebreak)         -- the Racket impl adds a 3rd "count"
+F = componentwise +
≤F = lexicographic
textF(c, l):  if c+l > width:  a = max(width,c) - width
                               b = (c+l) - max(width,c)
                               (b*(2a+b), 0, 0)     -- = (a+b)² − a², the squared-overflow delta
              else:            (0, 0, 0)
nlF(i): (0, 1, 0)
```

The `b·(2a+b)` identity is how you accumulate *squared* overflow additively
one text-placement at a time (`(a+b)² − a²`). The third component is pure
preference: form definitions emit `cost (0,0,k)` to bias the solver between
layouts that tie on width and height. This is the knob the knowledge layer
turns; the engine just sums and compares.

### 2.3 Measures, measure sets, and the resolver (Figs. 12–15)

The engine never renders during search. It computes **measures**. A measure is
`⟨last, cost, doc⟩` (plus two *ghost* fields `maxx`/`maxy` used only in the
correctness proof — we omit them in the implementation):

- `last` = length of the last line of this layout
- `cost` = its cost under the factory
- `doc` = the *choiceless* document that produced it (kept so we can render the
  winner at the end; the impl fuses render into resolve — Appendix C)

Operations (Fig. 12): `m_a ◦ m_b` concatenates two measures (cost `+F`, doc
`<>`, last from `m_b`); `adjustNest`/`adjustAlign` wrap the doc; **domination**
`m_a ⪯ m_b ⟺ last_a ≤ last_b ∧ cost_a ≤F cost_b` — if `m_a` dominates `m_b`,
`m_b` is pruned.

A **measure set** is either `Set([m₁..mₙ])` — a **Pareto frontier**, kept as a
list sorted by cost strictly ascending (equivalently `last` strictly
descending), no element dominating another — or `Tainted(m)`, a singleton
fallback used when every layout blows the computation-width limit `W`.

The resolver `⟨d,c,i⟩ ⇓RS S` (Fig. 15) is widening + measure computation fused,
with pruning baked into the **merge** `⊎` (a merge-sort-style merge of two
Pareto frontiers that drops dominated measures as it goes; left-biased on
`Tainted`). `text`/`nl` produce a singleton `Set` (or `Tainted` if past `W`);
`nest`/`align` `lift` the recursive result; `<|>` is `S_a ⊎ S_b`; `<>` resolves
the left set, then for each left measure concatenates the resolved right set
(`⇓RSC`) and merges all results. Top level: resolve at `⟨d,0,0⟩`, take the
least-cost measure (head of the frontier), render its `doc`.

Key efficiency facts (verified, §6.6–6.7):

- The frontier has at most `W+1` measures (Lemma 6.8) — bounded width is what
  makes it polynomial.
- Anything resolved past column/indent `W` is `Tainted` (Lemma 6.9), so the
  engine should **delay** (thunk) computation beyond `W` and lean on
  memoization.
- Complexity `O(n·W⁴)` general, `O(n·W³)` aligned-only, where **n is the DAG
  size** (not tree size). DAG-ness is load-bearing — see §3.1.
- `flatten` is a memoized rewrite that replaces `nl`→`space`, preserving
  identity when nothing changes; each node flattened at most once, `O(n)` new
  nodes, sharing preserved.

## 3. The Erlang port — design

### 3.1 The crux: documents are a DAG, and the BEAM has no pointer identity

This is the single most important design decision and the thing most likely to
make or break performance, so it leads.

Πₑ's polynomial complexity assumes the document is a **properly shared DAG**
and that resolve results are **memoized per `(node, c, i)`**. In Racket/OCaml a
document is a heap object with identity (`eq?`), so memoization keys on object
identity for free, and `<|>` sharing is just two parents pointing at one child.

On the BEAM there is no stable identity for immutable terms: two
structurally-equal documents are indistinguishable, and there is no
`eq?`-hash. If we represent documents as plain nested terms and memoize on
*structural* equality, we (a) pay deep-compare/deep-hash costs and (b) silently
re-expand shared subdocuments into a tree — which is exactly the `O(2ⁿ)`
blow-up the paper warns about (Example 6.3, Fig. 3).

**Therefore: make sharing explicit.** Represent a document as a node in an
explicit DAG store:

- A `doc()` value is an **integer node id**. Construction goes through smart
  constructors that intern nodes into a builder context (a `#{node => id}`
  reverse map for **hash-consing**, plus an `id => node` forward map). Equal
  subdocuments get the same id automatically → real sharing, including across
  `<|>`.
- Node payloads: `{text, S} | nl | {concat, A, B} | {nest, N, D} | {align, D}
  | {flatten, D} | {choice, A, B}` where `A,B,D` are ids.
- The memo table keys on `{Id, C, I}` → measure set. With `C,I ≤ W` this is
  bounded; beyond `W` we don't memoize (we taint/delay).

Open choice (needs the spike to settle): where the memo + node store live.
Options, roughly in increasing order of BEAM-idiom risk:

1. **Threaded state** — a `#state{nodes, memo}` record threaded functionally
   through resolve. Pure, testable, no side effects; the memo map can get large
   but dies with the call. *Leaning toward this for the reference port.*
2. **`ets` table** per format call (private, owned by the calling process,
   deleted at end). Faster mutation, mutable-aliasing hazards, must guarantee
   cleanup even on crash (spawn a owner or `try…after`).
3. **Process dictionary** — fast, idiomatic-for-memo in some BEAM code, but
   hostile to testing and the framework's "let it crash / known-good state"
   posture. Avoid unless the spike shows we must.

My recommendation is to build the reference implementation with **(1)
threaded state** for correctness and clarity, then measure; only move hot
paths to `ets` if the spike demands it. (Confidence: medium — this is the
genuine BEAM-specific engineering risk; the spike exists largely to de-risk
it.)

#### Graph representation: `digraph` / graffeo (map backend) — store vs. view

First, the prior question this hangs on: **what graph-theoretic operations do
we actually need?** Current answer: **none that are required.** What we have is
a **hash-consed expression DAG** that we **fold** with a `(node, c, i)`-keyed
memo. The three operations are intern-with-sharing on build, visit-typed-
children during resolve, and a memoized `nl→space` rewrite for `flatten`. Each
node has 0–2 *typed, ordered* children. Walking the digraph_utils catalogue
against that:

- `topsort` — does *not* linearise our DP, because the DP is keyed on
  `(node, c, i)`, not node alone; the same node resolves under many contexts.
  (A node-level order doesn't help.)
- `is_acyclic` — documents are acyclic by construction; only useful as a debug
  assertion.
- `reachable` / DAG-size — a plain traversal/fold; no library needed.
- `components` / `condensation` / `cyclic_strong_components` — about cycles;
  we have none.

So until something proves otherwise, the engine needs **zero** graph
algorithms. The DAG is a device for *sharing + memoization*, not a thing we run
graph algorithms over.

Second, the representation. Two candidates beyond a plain map: stdlib
`digraph` (ETS-backed, mutable, with the lifecycle/teardown hazard) and
**graffeo's map-backed value tier** (`graffeo_map`) — which is the relevant new
fact: it gives an *immutable* graph value with **no ETS overhead**, removing
the single strongest objection I had to the graph-library route. Credit where
due; that genuinely changes the calculus from "unmotivated" to "worth
weighing."

But two *representational* mismatches remain, and they're structural rather
than performance, so the map backend doesn't dissolve them (both confirmed
from `graffeo_map.erl`, where `out = #{From => #{To => Meta}}`):

1. **Children are ordered; graffeo edges are not.** Our `<>` has a left and a
   right operand; `out_neighbours/2` returns `maps:keys/1` — order unspecified.
   We'd have to carry operand position in edge metadata and re-sort on every
   child access, in the `O(n·W⁴)` inner loop.
2. **Children can repeat; graffeo is a *simple* graph.** At most one edge per
   ordered `(From, To)` pair (the adjacency is keyed by target, so a second
   edge overwrites). But the canonical sharing case in the paper is literally
   `shared <> shared` (Example 6.3) — a node with *two* references to the same
   child. A simple graph cannot hold two parent→child edges; you'd have to
   encode multiplicity in metadata. The very structure that motivates the DAG
   fights the simple-graph model.

Both mismatches dissolve the same way: **keep children inline in the node
payload** (`{concat, LeftId, RightId}`), not as graph edges. Then order and
repetition are free (it's a tuple), and the canonical store is a plain
`#{id => node}` map. At that point neither `digraph` nor `graffeo_map` is
buying us anything *for the store* — their edge machinery is redundant when the
edges live in the payload — and the plain map wins on simplicity in the hot
path. Note hash-consing (the `#{node => id}` reverse map) is ours either way;
no graph library provides it.

Where graffeo **does** fit, soundly, is as a **derived analytical view**, not
the canonical store. If/when we want graph analysis — an acyclicity audit, the
DAG-size-vs-tree-size check for the linearity spike (§5.3), sharing metrics, or
a future algorithm — project the inline-children map into a `graffeo_map`
(vertex per node id; one edge per distinct child-reference, with position +
multiplicity in edge meta) and run graffeo over *that*. The hot path stays lean
and plain; graffeo earns its keep exactly where graphs-as-graphs do, on our own
library. That projection is also the natural place an answer to "what graph ops
do we need" would finally crystallise — driven by the analysis we choose to
run, not by the resolver. (Confidence: high that children belong inline and the
store is a plain map; the graffeo-as-derived-view path is a real option, not a
commitment.)

### 3.2 The cost factory as a behaviour

```erlang
-callback le(Cost, Cost) -> boolean().          %% ≤F  (total order)
-callback combine(Cost, Cost) -> Cost.          %% +F
-callback text_cost(C :: non_neg_integer(),
                    L :: non_neg_integer()) -> Cost.   %% textF
-callback nl_cost(I :: non_neg_integer()) -> Cost.     %% nlF(i)
```

Ship `pe_cost_default` implementing the squared-overflow factory of §2.2,
parameterised by `Width` (and `Limit`/`W` for the computation bound). Keep the
factory a *module + config* pair so the LFE layer can swap objectives (soft
limits, line-count-only, etc.) without touching the engine — that flexibility
is a selling point for the standalone library.

A note on the contracts: they are not decorative. The `+F` monotonicity and
the `textF` additive-decomposition contracts are what make the Pareto merge
*correct*. We should encode them as PropEr properties over the default factory
(and any user factory) rather than trust them — this is a natural fit for the
`erlang-guidelines` PropEr discipline.

### 3.3 Modules (proposed)

- `pe_doc` — smart constructors + the DAG store (`text/1, nl/0, concat/2,
  nest/2, align/2, flatten/1, choice/2`, plus derived `group/1, vconcat/2,
  aconcat/2, space/0, empty/0, fail/0`). Owns hash-consing.
- `pe_cost` — the behaviour (§3.2) + `pe_cost_default`.
- `pe_measure` — measures + `◦`, `adjust_nest`, `adjust_align`, `⪯`.
- `pe_mset` — measure sets: `merge/2 (⊎)`, `dedup/1`, `taint/1`, `lift/2`,
  the `Set | Tainted` representation, the sorted-frontier invariant.
- `pe_resolve` — the resolver `⇓RS`/`⇓RSC` + memoization + the `W`
  delay/taint logic.
- `pe_render` — render a chosen choiceless doc to an `iolist()` (fused into
  resolve in the optimized path per Appendix C; keep a separate slow renderer
  for testing/oracle).
- `pe` — public API façade: `format(Doc, Opts) -> iolist()` with `width`,
  `limit (W)`, `indent`, `cost_factory` options.

### 3.4 Representation choices to settle in the spike

- Measure set as a plain sorted list (paper's representation) vs. something
  fancier. Frontier ≤ `W+1` elements, so a list is fine; start there.
- Cost as a tuple `{Badness, Height, Tiebreak}` with lexicographic compare —
  trivial and matches the Racket factory exactly.
- `flatten` as the memoized `nl`→`space` rewrite over the DAG store.
- Strings: `text` payloads as binaries; render to `iolist()`; never build big
  flat strings during search (we only need *lengths* during resolve, so store
  `{Binary, byte_size}` or compute length once at construction).

## 4. Risks, named honestly

1. **Performance on deep S-expression documents — the real one.** The paper's
   own benchmarks (Table 2) show Πₑ is *slowest exactly on the S-expression
   workload* that LFE is: `SExpFull15` = 3.0 s and `SExpFull16` = 5.3 s at the
   default width (and 5.4 s / 14.2 s at `W=1000`), versus 45–91 ms for
   Wadler/Leijen on the same inputs. Those are 4k–8k-line synthetic blow-ups,
   so typical files (hundreds of lines) should be well under a second — but
   this is precisely the dimension our use case stresses, and the `W⁴` term
   means width matters. **The spike must measure real LFE files, not toy
   inputs**, and we should decide an acceptable ceiling (e.g. "≤ 200 ms for a
   1000-line module at width 80") up front. (Confidence: high that this is the
   risk to watch; it's in the authors' own data.)

2. **Memoization without pointer identity** (§3.1). The whole complexity
   argument rests on DAG sharing + memo. Get the hash-consing/identity story
   wrong and we silently fall to exponential. De-risked by the spike's
   pathological-sharing case (port Example 6.3 and confirm it stays linear).

3. **BEAM is not OCaml.** The reference impl is OCaml; Racket is the slower of
   the two and still ships. BEAM's term-copying and lack of mutable structs add
   constant-factor overhead to the inner merge/dedup loop. Mitigation:
   keep measures small (3 fields, no ghosts), keep the frontier a flat list,
   avoid per-step allocation where possible.

4. **Correctness of the merge/dedup invariants.** Subtle (left-bias on taint,
   strict vs non-strict ordering in `dedup`). Mitigation: property tests
   against a brute-force `eval` oracle (widen → render all → min by cost) on
   small documents, asserting Πₑ's output equals the true optimum. The paper
   was Lean-verified; we get assurance via differential testing against the
   naive evaluator.

## 5. The minimal validation spike (next deliverable)

Smallest thing that proves the port works *and* de-risks the two big unknowns.
Build only `pe_doc` (with hash-consing), `pe_cost_default`, `pe_measure`,
`pe_mset`, `pe_resolve`, and a slow `pe_render`. Then:

1. **Correctness vs. oracle.** Hand-build ~10 documents exercising every
   construct incl. `align`, nested `choice`, and `fail`; for each, compare
   `pe:format/2` against a brute-force widen-render-min oracle at several
   widths. Must match exactly.
2. **The squared-overflow factory** reproduces the paper's Fig. 7 costs
   (`(8,3)` vs `(20,0)` at width 6) — a direct, cheap sanity check that our
   `textF` is right.
3. **Sharing stays linear.** Port Example 6.3's `mk(n)` and a *properly
   shared* choice DAG; confirm resolve time grows with DAG size, not tree size
   (the memo/identity test).
4. **Real LFE, real numbers.** Hand-translate 2–3 real LFE forms from the
   `rebar3_lfe` `formatting-gallery` into Σₑ documents (by hand — the
   knowledge layer doesn't exist yet) and measure wall-clock at width 80.
   Compare output to the gallery's expected layout. This is the go/no-go on
   risk #1.

Exit criterion: oracle-correct on all spike docs, linear on the sharing test,
and within our latency ceiling on the real-LFE sample. If (4) fails the
ceiling, we revisit — possibly a hybrid (Πₑ for known forms, greedy fallback
for huge unknown blobs), or `ets` memo, before committing to the full library.

## 6. Open questions for Duncan

- **Latency ceiling**: what's "fast enough" for `rebar3 lfe format` on a
  typical and a worst-case file? This sets the spike's go/no-go bar.
- **Repo layout / naming**: this note is in `workbench/`. Do you want the
  engine as its own OTP app in this repo (e.g. `apps/pretty_expressive` +
  `apps/lfe_fmt`), or two repos? And your arc/slice numbering applied from the
  start, or hold until after the spike?
- **Package identity**: the engine is generically useful (not LFE-specific).
  Publish it to Hex under its own name so non-LFE BEAM projects can use it, with
  `lfe_fmt` as a separate package depending on it? (This matches your "others
  will want to use it" rationale.)
- **Cost factory surface**: expose the cost factory as a public extension point
  in v1, or keep it internal (default-only) until the LFE layer proves out?
