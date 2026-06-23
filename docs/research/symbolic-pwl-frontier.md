# Symbolic Piecewise-Linear Frontiers for Width-Independent Optimal Pretty-Printing

*A research draft toward an LFE formatter engine, extending the PrettyExpressive printer (Πₑ).*

**Author:** Duncan _(set formal byline/affiliation)_
**Collaborator:** Claude (Anthropic), in a peer design session
**Status:** Working draft, June 2026. Results are hand-derived from small worked
examples and structural argument, **not** machine-checked proofs. Confidence is
marked inline as *(verified)*, *(reasoned)*, or *(conjecture/bet)* throughout.

---

## Abstract

The PrettyExpressive printer Πₑ [Porncharoenwase et al. 2023] resolves a document
to a provably cost-optimal layout, but its time complexity is `O(n·W⁴)` in the
page width `W`, and its published benchmarks show it is *slowest precisely on
S-expression workloads* — exactly the shape of Lisp source. This is an obstacle
to using it as the engine of a fast formatter for Lisp Flavoured Erlang (LFE).

We observe that Πₑ's per-node Pareto frontier is, read correctly, a *function*
`g(c) = min cost to lay this subtree out so its last line ends at column c`, and
that Πₑ pays its `W`-factor by representing this function as **`W+1` point
samples**, one per column. We develop an alternative in which `g` is carried
**symbolically** as a compact piecewise-linear object, composed analytically
rather than sampled. With a piecewise-linear (sum-of-overflow) cost function,
each layout *class* has a cost-versus-start-column that is a two-piece "hockey
stick," and we show — by working the algebra through the constructors of an
aligned Lisp pretty-printing language — that:

1. the representation is **closed** under unaligned concatenation, nesting, and
   alignment *(verified for the no-align fragment; verified by worked example for
   align including nested align)*;
2. two pruning principles — Pareto-domination on `(last-column, cost)` and
   *collapse-after-break* (a subtree followed by a forced newline keeps only its
   minimum-cost layout) — bound the surviving frontier to roughly the **nesting
   depth of the document's right spine**, `D`, rather than to `W` *(reasoned,
   corroborated by worked examples)*; and
3. the dependence on start column is captured **without enumerating columns**:
   frontier membership changes only at `O(D)` content-determined breakpoints, so
   the whole construction is **width-independent** *(verified for nest; verified
   by worked example for align)*.

The net is an estimated `O(n·D²)` with `D` small and bounded for real code — the
`W`-factor disappears for the `group + nest + align` fragment that covers the
canonical LFE example `gps1.lfe` in full. We are explicit about what we have
*not* established: there is no worst-case proof; the *fill* layout style (several
items sharing a line) is unaddressed and is the prime suspect for reintroducing
blowup; and the whole approach is, in the end, a **bet that real Lisp is
"nice"** — a bet Πₑ deliberately declined in exchange for unconditional bounds.
We relate the construction to Knuth–Plass line breaking and to Yelland's
piecewise-linear formatter, and sketch a BEAM implementation in which
piecewise-linear functions are slope-sorted segment lists and the whole engine
parallelises per top-level form.

---

## Contents

1. [Introduction](#1-introduction)
2. [Background: Πₑ and the origin of the W-factor](#2-background-π-and-the-origin-of-the-w-factor)
3. [The reframing: a frontier is a function of start column](#3-the-reframing-a-frontier-is-a-function-of-start-column)
4. [A piecewise-linear symbolic representation](#4-a-piecewise-linear-symbolic-representation)
5. [The compositional algebra](#5-the-compositional-algebra)
6. [Bounding the frontier: two pruning principles](#6-bounding-the-frontier-two-pruning-principles)
7. [Width-independence: the start-column parameterisation](#7-width-independence-the-start-column-parameterisation)
8. [Worked examples](#8-worked-examples)
9. [Complexity and comparison](#9-complexity-and-comparison)
10. [Limitations and open questions](#10-limitations-and-open-questions)
11. [Related work](#11-related-work)
12. [Implementation outlook (BEAM) and project placement](#12-implementation-outlook-beam-and-project-placement)
13. [Conclusion and next steps](#13-conclusion-and-next-steps)

---


## 1. Introduction

### 1.1 The problem

A code formatter for a parenthesised language wants two things that are in
tension: **optimal** layout (choose, among all the ways a form *could* be laid
out, one that minimises overflow past the page width and then minimises the
number of lines) and **speed** (run on a whole project in the blink of an eye).

The PrettyExpressive printer Πₑ [Porncharoenwase, Pombrio, Torlak 2023] is, to
our knowledge, the only published pretty printer that is simultaneously
*expressive* (arbitrary layout choice, both aligned and unaligned concatenation),
*provably optimal* (it minimises a user-supplied cost objective), and reasonably
*efficient* on paper (`O(n·W⁴)`, where `n` is the document's DAG size and `W` the
computation width limit). It is the engine beneath the Racket code formatter
`raco fmt`.

The obstacle, for us, is in its own evaluation. Πₑ's benchmark table shows it is
*slowest exactly on the S-expression workload* — several seconds for a
multi-thousand-line synthetic S-expression document, versus tens of milliseconds
for a greedy Wadler/Leijen printer on the same input. S-expressions are not an
adversarial corner case for a Lisp formatter; they are the entire input. So the
very workload Πₑ handles worst is the one an LFE formatter must handle best.

### 1.2 The idea

The `W`-factor in Πₑ is not intrinsic to the problem; it is intrinsic to a
*representation choice*. Πₑ summarises each subtree by a **Pareto frontier** of
"measures," and bounds that frontier to at most `W+1` points by, in effect,
sampling one representative per possible column `0..W`. Read the frontier as a
function

> `g(c)` = the least cost to lay this subtree out starting at column `c`
> (carrying, for each `c`, the trade-off between that cost and the column the
> layout *exits* at),

and the `W+1` points are simply `g` **sampled at every column**. The sampling is
the `W`-factor.

This paper asks: can we carry `g` **symbolically** — as a compact closed-form
object — and compose subtrees by composing their `g`'s *analytically*, never
enumerating columns? If `g` has enough structure (it is piecewise-linear, for a
piecewise-linear cost), the answer for the fragment of layouts that Lisp actually
uses appears to be yes, and the dependence on `W` disappears.

This is, in spirit, the move that turns naïve `O(n²)` optimal line breaking into
near-linear Knuth–Plass [Knuth & Plass 1981]: exploit convexity of the cost so
that the "minimise over all previous positions" step collapses. Yelland [2016]
applied a version of it to pretty-printing with piecewise-linear cost functions;
Πₑ deliberately declined it (to gain full expressiveness and document sharing,
at the price of the `W`-factor). We revisit the trade-off specifically for Lisp.

### 1.3 Contributions

- **A reframing** (§3): Πₑ's Pareto frontier is a cost-to-column function;
  its `W`-factor is the cost of point-sampling that function.
- **A symbolic representation** (§4): with a piecewise-linear cost, each layout
  *class* is captured by a "hockey-stick" cost-versus-start-column and an affine
  or constant exit column; the start-column dependence is confined to a single
  term (in the unaligned fragment).
- **A compositional algebra** (§5) over `text`, `nl`, unaligned concatenation,
  `nest`, `align`, and `choice`/`group`, shown closed under composition.
- **Two pruning principles** (§6): Pareto-domination on `(exit-column, cost)`,
  and *collapse-after-break*; together they bound the surviving frontier to the
  document's right-spine nesting depth `D`, not to `W`.
- **A width-independence argument** (§7): the start-column family changes only at
  `O(D)` content-determined breakpoints, including under (nested) alignment.
- **Worked examples** (§8) grounded in real LFE (`gps1.lfe`), a complexity
  estimate (§9, `O(n·D²)`, width-independent), an honest account of limitations
  (§10, chiefly *fill*), related work (§11), and a BEAM implementation outlook
  (§12) that slots the work into a contingent future engine arc.

### 1.4 Status and honesty

Everything here was developed in a single collaborative design session as a
**research sketch**. The closure and width-independence claims are established by
hand-derivation on small examples plus structural argument; none is a formal
proof, and we flag each as *(verified)* (worked through concretely and checked),
*(reasoned)* (structural argument we believe but did not exhaustively check), or
*(conjecture/bet)*. The honest one-line summary: *for the layout fragment
canonical LFE actually emits, the width factor appears to vanish; we have not
proved it, and we have not handled the `fill` style.*


## 2. Background: Πₑ and the origin of the W-factor

We recall only what we need; see Porncharoenwase et al. [2023] for the full
treatment.

### 2.1 The language Σₑ

A document is built from seven constructs:

```
d ::= text s        -- a literal string with no newline
    | nl            -- a newline (becomes a single space when flattened)
    | d <> d        -- UNALIGNED concatenation: right operand begins
                    --   at the column where the left operand ended
    | nest n d      -- increase the indentation level by n
    | align d       -- set the indentation level to the current column
    | flatten d     -- replace every nl in d by a space
    | d <|> d       -- arbitrary choice between two layouts
```

Derived forms include `group d = flatten d <|> d` (lay flat if it fits, else as
written), vertical concatenation `d <$> d = d <> nl <> d`, and aligned
concatenation `d <+> d`. The two concatenations differ in where the right operand
continues: `<>` continues at the left operand's *ending column* (so material
flows on the same line); a break inside the right operand returns to the
*indentation level*, which `nest` shifts relatively and `align` pins to the
current column.

### 2.2 The cost factory

Πₑ is parameterised by a **cost factory**: a cost type with a total order `≤`, an
associative combiner `+`, a function `textF(c, l)` giving the cost of placing `l`
characters starting at column `c`, and a newline cost `nlF(i)`. The factory must
satisfy monotonicity and an additive-decomposition contract
`textF(c, l₁+l₂) = textF(c, l₁) + textF(c+l₁, l₂)`, which is what lets a line's
cost be accumulated character by character. The default factory used by `raco
fmt` is *squared overflow then height*: `cost = (Σ overflow², #newlines)` compared
lexicographically.

### 2.3 Measures, the Pareto frontier, and the resolver

To avoid rendering every candidate layout, Πₑ computes **measures**. A measure
records a layout's last-line length `λ`, its cost, and (a handle to) the
choiceless document that produced it. Under a fixed printing context `(c, i)` a
subdocument resolves to a **measure set**: a *Pareto frontier* of `(λ, cost)`
pairs in which no measure dominates another (`mₐ ⪯ m_b` iff `λₐ ≤ λ_b` and
`costₐ ≤ cost_b`), kept sorted. The resolver fuses widening (expanding `<|>`),
measure computation, and pruning, with the choice operator handled by *merging*
two frontiers and concatenation handled by resolving the right operand once per
left-operand measure.

### 2.4 Where the W-factor comes from

Two facts conspire. First, the frontier at any node has **at most `W+1`
measures** (the paper's Lemma 6.8): a column position beyond the *computation
width limit* `W` is "tainted" and collapsed, so distinct surviving measures
correspond to distinct exit columns `0..W`. Second, concatenation resolves the
right operand once **per left measure** — up to `W+1` times. Together with the
per-merge work this yields the `O(n·W⁴)` bound (`O(n·W³)` for the aligned-only
sublanguage). The robustness is real: the `W+1` cap holds *unconditionally*, even
for documents whose `<|>` structure encodes exponentially many distinct layouts.
The cost of that robustness is that the frontier is always re-derived at column
granularity.

### 2.5 The convexity lineage we are drawing on

Optimal line breaking — choosing breakpoints in a *flat* sequence of words to
minimise summed squared "badness" — is the same kind of least-cost dynamic
program, and Knuth & Plass [1981] solve it in near-linear time because the
badness cost is convex, which makes the "minimise over all previous breakpoints"
step collapse (the modern framing is the Monge/quadrangle inequality with
SMAWK-style row-minima, or the convex-hull trick for linear costs). Yelland
[2016] brought this to pretty-printing, representing cost as a *piecewise-linear
function of the starting column* and composing those functions symbolically —
obtaining sub-quadratic time with no `W`-factor, at the price of restricting the
left operand of aligned concatenation to be literal text and of weaker document
sharing. Πₑ rejected that restriction. The question of this paper is whether, for
the *Lisp* fragment, we can recover Yelland's `W`-freedom without his restriction.


## 3. The reframing: a frontier is a function of start column

Fix a subdocument `d`. Πₑ resolves it *at a particular context* `(c, i)` and
returns a frontier — a finite Pareto set of `(λ, cost)` pairs. But `c` is not
intrinsic to `d`; it is supplied by whatever sits to `d`'s left. So the honest
object attached to `d` is not one frontier but a **family of frontiers indexed by
the start column**:

> `F_d : c ⟼ { Pareto-optimal (λ, cost) pairs achievable by laying d out
>             starting at column c }`

(the indentation level `i` is a second parameter; we hold it fixed and return to
it when we treat `nest` and `align`).

Πₑ materialises `F_d` by **sampling**: it picks the relevant `c`, and within that,
bounds the frontier to one point per exit column `0..W`. Both the choice of `c`
and the `W+1` cap are samplings of a function that — we will argue — has cheap
closed form.

### 3.1 What the function looks like, qualitatively

For each *layout class* of `d` (a fixed set of break decisions), laying it out
from column `c` produces a definite `(λ(c), cost(c))`. As `c` slides right:

- a class's **cost** is flat while everything fits, then grows once some line is
  pushed past the page width — *monotone non-decreasing* in `c`;
- a class's **exit column** `λ` either tracks `c` (if the class ends on a line
  that began at, or flows from, `c`) or is pinned (if it ends on a line that
  began at a fixed indent).

`F_d(c)` is then the lower-left staircase (Pareto frontier) of these per-class
points, and the staircase *deforms continuously* as `c` moves: classes enter and
leave the frontier at certain columns, but between those columns the membership is
constant.

### 3.2 The two questions this raises

Carrying `F_d` symbolically is viable only if two counts stay small and, in
particular, **independent of `W`**:

1. **How many layout classes survive** in `F_d` at once? (the "height" of the
   staircase). §6 argues this is governed by nesting depth `D`, not `W`.
2. **How many distinct `c`-intervals** are there — i.e., how often does the
   staircase change membership as `c` sweeps? (the "width" of the
   parameterisation). §7 argues this is `O(D)` content-determined breakpoints,
   not `O(W)`.

If both hold, `F_d` is an object of size `O(D)`, composable in `O(D²)` per node,
and the formatter is width-independent. The rest of the paper builds the
representation (§4–5) and then defends these two counts (§6–7).

### 3.3 Why this is a bet, stated up front

Πₑ's `W+1` cap is *unconditional*: no matter how pathological the `<|>` structure,
the sampled frontier never exceeds `W+1` points. Our symbolic frontier's size is
the *true* number of Pareto-distinct classes, which is smaller than `W+1` for
"nice" documents but has **no finite bound for adversarial choice** (a document
can encode exponentially many genuinely distinct layouts). So this is not a
universal improvement; it is a representation that wins precisely when the input
is structurally tame — few surviving classes, shallow nesting. The wager of the
paper is that **real Lisp source is tame in exactly this way**, and that we, as
the authors of the formatting conventions, never need to emit the adversarial
shapes. §10 returns to where that wager is and is not safe.


## 4. A piecewise-linear symbolic representation

### 4.1 Choosing the cost: piecewise-linear overflow

We adopt a **piecewise-linear** cost: per line, the overflow
`max(0, end_column − W)`, summed over lines (the primary objective), with the
number of newlines as a secondary lexicographic objective (height). This is
Πₑ-compatible (it is the paper's Example-3.4 factory) and, crucially, keeps every
function we manipulate piecewise-linear, so composition is a merge of
slope-sorted segments rather than algebra over parabolas. The squared-overflow
default is strictly convex and aesthetically nicer about *large* overflows, but it
makes each per-class cost piecewise-*quadratic* and multiplies the segment count;
we treat the choice of cost as a deliberate lever and discuss the trade in §10.

With this cost, `textF(c, l) = max(0, c + l − W)`: zero until the text would cross
the margin, then unit slope. This single shape — a **hockey stick** — is the
atom from which everything is built.

### 4.2 Layout classes

Represent a subdocument as a small set of **classes**, one per relevant
combination of break decisions. Each class is one of:

- a **flat** class: a single line of total width `W_flat`. Started at column `c`
  it costs `textF(c, W_flat)` and exits at `λ(c) = c + W_flat`.
- a **broken** class: ≥ 1 newline, summarised — in the unaligned fragment — by a
  first-line width `w₁`, a constant remainder cost `K` (the overflow of all
  *later* lines, which begin at fixed indents and so do not depend on `c`), a
  constant exit column `λ`, and a height `h`.

### 4.3 The key invariant: c lives in the first line

In the unaligned (`nest`-only) fragment, **only the first line of a layout begins
at the start column `c`**; every continuation line begins at a fixed indentation
level. Hence for any class:

```
cost(c) = K + max(0, c + w₁ − W)
          └constant┘  └─── the only c-dependent term ───┘
```

a **two-piece hockey stick**: constant baseline `K` for `c ≤ W − w₁`, then unit
slope. The exit column is `λ = c + W_flat` (flat) or a constant (broken). A class
is therefore captured by the tuple

> `(w₁  ⟹ threshold W − w₁ , baseline K , λ , height h)`

with no reference to individual columns. The whole `c`-dependence of the universe
is the location and height of one ramp per class. (Under `align`, several lines
become `c`-anchored and `cost(c)` becomes a *sum* of hockey sticks; we develop
this in §5.5 and §7.3. The piece count is then the class's line count — still
content-bounded, never `W`-bounded.)

### 4.4 What we carry, concretely

A subdocument's symbolic frontier `F_d` is:

- an optional flat descriptor: the scalar `W_flat`;
- a set of broken descriptors `(w₁, K, λ, h)` (unaligned) or
  `(w₁, shape, h)` where `shape` is a short list of `(offset, width)` per
  `c`-anchored line (aligned);

pruned to the Pareto-optimal set across the whole `c`-family (§6). Because each
descriptor is `O(1)` (unaligned) or `O(lines)` (aligned) and the set has size
`O(D)` (§6), `F_d` is small and, as the next sections show, composes without ever
touching `W`.


## 5. The compositional algebra

We define how each Σₑ constructor acts on the symbolic frontier. Throughout,
"class" means a descriptor from §4; an operator maps frontier(s) to a frontier,
followed by the pruning of §6.

### 5.1 text and nl

`text s` (width `w`, no newline) is a single flat class `W_flat = w`. `nl` at
indent `i` is `{ flat: 1 (a single space), broken: (w₁ = 0, K = textF(0,i),
λ = i, h = 1) }`. Both are immediate.

### 5.2 Unaligned concatenation `a <> b` — closed (verified)

Compose class-by-class; in every case the result is again a class of the §4 form,
with `c` still confined to the first line:

- **a broken, b flat.** `a` ends at the constant `λ_a`; `b` (width `W_b`) extends
  that last line. Result: broken `(w₁_a, K_a + textF(λ_a, W_b), λ_a + W_b, h_a)`.
- **a broken, b broken.** `b`'s first line joins `a`'s last line at `λ_a`; `b`'s
  remainder and exit follow. Result:
  `(w₁_a, K_a + textF(λ_a, w₁_b) + K_b, λ_b, h_a + h_b)`.
- **a flat, b flat.** Stays flat: `W_flat = W_a + W_b`.
- **a flat, b broken.** `a`'s flat run merges into `b`'s first line. Result:
  `(w₁ = W_a + w₁_b, K_b, λ_b, h_b)` with cost `textF(c, W_a + w₁_b) + K_b`.

In all four, the only `c`-dependent term remains a single `textF(c, ·)`, the
arithmetic is `O(1)`, and the step relies only on the factory's additive
decomposition (§2.2). Concatenation is the operator that *could* have multiplied
state; it does not. The class-set sizes multiply (|a| × compatible |b|) before
pruning — §6 is what keeps that in check.

### 5.3 nest n d

`nest` shifts the indentation level used by `d`'s continuation lines from `i` to
`i + n`. It recomputes the constant remainder `K` and exit `λ` of `d`'s broken
classes at the higher indent; it does not touch the first line or the
`c`-dependence. Closed, `O(1)` per class.

### 5.4 Choice and group — union then prune

`a <|> b` is the **union** of the two class-sets, pruned. `group d = flatten d <|>
d` injects `d`'s single flat class alongside `d`'s broken classes. Union is the
only operator that *grows* the class count; the Pareto pruning of §6 is what
bounds it. (`flatten d` is the all-on-one-line class of `d`, computed once at
construction; it never appears as a runtime node.)

### 5.5 align d — the genuinely two-dimensional operator

`align` pins `d`'s indentation level to the *current column* `c`, so **every**
line of `d`, not just the first, begins at `c + (a constant offset)`. An aligned
broken class therefore has

```
cost(c) = Σ_k  max(0, c + offset_k + width_k − W)
λ(c)    = c + offset_last
```

— a **sum of hockey sticks** (one per line of the class) and an **affine** exit
column. This differs from the unaligned case in two ways: the cost is a multi-
piece convex piecewise-linear function (piece count = the class's line count,
*content*-bounded, not `W`-bounded), and `λ` is `c + const` rather than constant.
Both differences are benign for composition: a convex piecewise-linear function
composed with the affine substitution introduced by `<>` (§5.2) stays convex
piecewise-linear, and an affine `λ` substituted into another hockey stick stays a
hockey stick. So `align` is closed too — it merely upgrades a class from "one
ramp, constant exit" to "a few ramps, affine exit." §7.3 shows the nested-`align`
case (alignment inside alignment) keeps `c` a single linear parameter.

### 5.6 Summary of the algebra

| constructor | effect on the frontier | closes? |
|-------------|------------------------|---------|
| `text`, `nl` | introduce 1–2 base classes | — |
| `<>` | class cross-product, `O(1)` per pair; `c` stays in first line | yes *(verified)* |
| `nest n` | recompute constant `K`, `λ` at `i+n` | yes *(verified)* |
| `align` | classes carry a few-piece convex cost(c) and affine `λ` | yes *(verified by worked example)* |
| `<|>` / `group` | set union, then prune | yes (size bounded by §6) |

The algebra is closed. The whole question of *efficiency* now reduces to two
counts — the size of the pruned class-set and the number of `c`-breakpoints —
which the next two sections take up.


## 6. Bounding the frontier: two pruning principles

Concatenation cross-products class-sets (§5.2) and choice unions them (§5.4), so
without pruning the class count could explode (a document with `D` nested groups
encodes up to `2^D` distinct layouts). Two principles keep the *surviving* set
small.

### 6.1 Principle I — Pareto on (exit-column, cost)

A class is kept only if it is Pareto-optimal in `(λ, cost)`: no other class exits
at least as early *and* costs at least as little. The non-obvious consequence is
that **a more expensive class is retained when it exits earlier**, because a
shorter exit can save the *parent* from overflow downstream. Concretely (§8), the
two-element call `(g a)` keeps *both* its flat layout (cheaper, exits at column 5)
and its broken layout (costlier by one line, exits at column 4) — neither
dominates. So Pareto pruning does not collapse a node to a single class; it keeps
a *staircase* trading exit column against cost.

### 6.2 The staircase has height ≈ nesting depth

Down a right-nested spine, the surviving staircase has one step per "how many
levels are broken." For `(f (g a))` (§8) the classes are: break nothing (flat),
break the outer only, break both — three classes, each trading one exit column for
one unit of height, all Pareto. In general a right-nested chain of depth `D` yields
a `(D+1)`-step staircase. The naïve `2^D` layouts prune to `D+1`: **linear in
depth, not exponential** *(reasoned; corroborated by the §8 worked examples)*.

### 6.3 Principle II — collapse after a break

The staircase grows with *right-spine* depth, but does *branching* (a node with
several child subforms) multiply it? The answer is no, because of:

> **Collapse-after-break.** A subtree that is immediately followed by a forced
> newline has its exit column consumed by that newline — nothing downstream
> depends on where it ended. Such a subtree therefore keeps only its single
> **minimum-cost** class; its Pareto multiplicity is discarded.

In a vertical layout `(f (g a) (h b))`, the argument `(g a)` is followed by a
newline before `(h b)`, so `(g a)` collapses to one (cheapest) class; only the
**last** child on the **last** line keeps its full frontier, because only its exit
column flows out of the node. So the vertical layout's class count is *not* the
product of its children's counts — it is (1 per non-last child) × (the last
child's count). Branching does **not** multiply the frontier *(reasoned;
corroborated in §8)*.

### 6.4 Consequence: P ≈ right-spine depth

Combining the two: surviving multiplicity accumulates only along the document's
**rightmost spine** (everything to the left of a break collapses), and along that
spine it grows by one per nesting level. So the per-node surviving class count

> `P ≈ D`, where `D` is the right-spine nesting depth,

independent of width `W` and of branching factor. For real Lisp, `D` is small —
nesting deeper than ~10–15 is rare — so `P` is effectively a small constant. The
pathological case is a deeply right-nested chain (`D ≈ n`), where `P` degrades to
`O(n)`; §9 and §10 address how far that matters.

### 6.5 The cost lever in service of pruning

Pruning compares classes by `cost(c)` *for all `c`* (§7.2). With piecewise-linear
cost each class is a hockey stick, and "does class X dominate class Y for every
`c`?" is an `O(1)` comparison of baselines, thresholds, and exits. This is the
concrete payoff of the piecewise-linear choice (§4.1): not just compact functions,
but `O(1)` domination tests, so the whole prune at a node is `O(P²)` with no `W`
anywhere.


## 7. Width-independence: the start-column parameterisation

§6 bounds the *height* of the frontier (number of classes). This section bounds
its *width* — how the frontier changes as the start column `c` sweeps — and shows
the change happens at `O(D)` content-determined breakpoints, never at column
granularity. This is the load-bearing claim: if the `c`-family needed `W` samples,
nothing above would have removed the `W`-factor.

### 7.1 Each class is a hockey stick in c (unaligned)

From §4.3, an unaligned class has `cost(c) = K + max(0, c + w₁ − W)`: flat at
baseline `K` until the threshold `c = W − w₁`, then unit slope. The threshold is
fixed by the class's *first-line width*, a content quantity — not by sampling
`W`. So the entire dependence of one class on `c` is "a ramp that switches on at a
content-determined column."

### 7.2 The frontier changes at O(D) content breakpoints (verified)

As `c` increases, the Pareto staircase deforms, but its **membership** changes
only where two classes' hockey sticks cross or where a class's ramp switches on.
Two classes with equal `w₁` (equal threshold) never cross — they stay a constant
apart — so crossings occur only between classes of differing first-line width, of
which there are `O(D)`. Hence the number of distinct `c`-intervals is `O(D)`. We
verified this on `(f (g a))` (§8.2): across the *entire* column range the frontier
membership flips exactly **once**, at one content-determined column, not at each of
the `W` columns. The whole `c`-family is therefore represented by `O(D)` hockey-
stick tuples plus `O(D)` breakpoints, and the frontier at any `c` is reconstructed
analytically.

### 7.3 Alignment keeps c linear — including nested alignment (verified by example)

Under `align`, a class's cost is a *sum* of hockey sticks (§5.5), one per
`c`-anchored line, with thresholds at `c = W − offset_k − width_k` — again content-
determined. The exit column is affine, `λ(c) = c + offset_last`. The worry was
**alignment nested inside alignment** — does `c` stay linear? It does: an inner
`align` pins its lines to the inner align column, which is the outer align column
plus a constant prefix, i.e. `c + offset_outer + offset_inner`. Each nesting level
contributes another *constant* offset; `c` threads through as a single linear
parameter no matter how deep the alignment nests. We verified this on the
`some`/`find-all` form from `gps1.lfe` (§8.3): every line's start column is
`c + (sum of constant prefixes)`, so every overflow term is a hockey stick in `c`
with a content threshold, and frontier membership again changes only at content
breakpoints. Alignment is therefore width-independent; its only cost over `nest`
is that classes carry a few-piece convex function (bounded by line count) and an
affine rather than constant exit.

### 7.4 Composition never reintroduces W

The two ways `c`-dependence flows during `<>` (§5.2) both preserve the hockey-
stick form: after a *broken* left operand, the right operand is placed at the
*constant* `λ_a`, so its cost becomes a constant (no `c`); after a *flat* left
operand, the right operand is placed at `c + W_a`, an affine shift, so its hockey
stick simply has its threshold moved by `W_a`. Either way the result is still a
hockey stick (or a sum of them, under alignment) with content-determined
thresholds. At no point does any operation iterate over columns.

### 7.5 The width-independence claim, stated precisely

> For the `group + nest + align` fragment, `F_d` is represented by `O(P)` classes
> (`P ≈ D`, §6), each carrying a convex piecewise-linear `cost(c)` whose piece
> count is bounded by the class's line count, and an affine-or-constant `λ(c)`;
> the frontier's membership changes at `O(D)` content-determined `c`-breakpoints.
> No quantity in the representation or its operations depends on `W`.

Status: **verified** for the unaligned (`nest`) fragment by the §8.2 sweep;
**verified by worked example** for alignment, including nesting, via §8.3; **not**
a general proof, and **not** established for `fill` (§10.1).


## 8. Worked examples

All examples use page width `W = 10`, the piecewise-linear cost
`cost = (Σ overflow, height)` compared lexicographically, and a `+2` body-indent
convention with the close paren hugging the last token. We write each class as
its exit column `λ` and cost; rendered at top level the indent is `i = 0`.

### 8.1 Leaf call `(g a)` — Pareto keeps two classes

Two layouts:

- flat `(g a)`: occupies `[0,5]`, `λ = 5`, cost `(0,0)`.
- broken `(g` / `  a)`: lines `[0,2]`, `[0,4]`, `λ = 4`, cost `(0,1)`.

Even though flat fits, neither dominates: flat is cheaper but exits at column 5;
broken costs one more line but exits at column 4, which can save a parent from
overflow. **P = 2** — and this illustrates Principle I (§6.1): the `(λ, cost)`
trade-off retains a costlier-but-shorter class.

### 8.2 Nested `(f (g a))` — the staircase, and a single c-breakpoint

Built from the inner classes, three classes survive:

| class | description | cost(c) | λ | threshold |
|-------|-------------|---------|---|-----------|
| flat | `(f (g a))` | `(max(0, c−1), 0)` | `c+9` | `c = 1` |
| C_bf | `(f` / `  (g a))` | `(max(0, c−8), 1)` | `8` | `c = 8` |
| C_bb | `(f` / `  (g` / `    a))` | `(max(0, c−8), 2)` | `7` | `c = 8` |

At `c = 0` these read `(λ9,(0,0)) (λ8,(0,1)) (λ7,(0,2))` — a clean staircase, each
step trading one exit column for one line, all Pareto. The naïve `2² ` layouts
pruned to `D+1 = 3` (§6.2).

Now sweep `c` (§7.2):

- `c ∈ [0,1]`: all overflow 0 → all three present, **P = 3**.
- `c` just past `1`: flat starts overflowing `(c−1, 0)`, while the broken pair are
  still `(0, ·)`; overflow is primary, so C_bf `(0,1)` dominates flat (shorter
  exit *and* cheaper) — **flat drops**, P = 2.
- `c` past `8`: all three overflow at unit slope; flat stays dominated; C_bf and
  C_bb remain incomparable. Membership unchanged.

Across the whole range, frontier membership flips **once**, at the content column
`c = 1` — not at each of the 10 columns. This is §7.2 made concrete: the
`c`-family is three hockey-stick tuples and one breakpoint, width-independent.

### 8.3 Real alignment: `some`/`find-all` from `gps1.lfe`

The canonical LFE example uses align-under-first-arg, including nested:

```lfe
(some (fun apply-op 1)
      (find-all (lambda (op) (appropriate-p goal op))
                (getvar *ops*)))
```

Model `(some A1 A2)` placed at start column `c`, args aligned under `A1`. The align
column is `c + 6` (`"(some "` is 6 wide). The broken-align class:

- line 1 `(some A1`: `[c, c+6+a1]` → overflow `max(0, c+6+a1 − W)`
- line 2 `A2)` at the align column: `[c+6, c+6+a2+1]` → overflow `max(0, c+6+a2+1 − W)`

so `cost(c) = max(0, c+6+a1−W) + max(0, c+6+a2+1−W)` — a **sum of two hockey
sticks**, thresholds at `c = W−6−a1` and `c = W−6−a2−1` (both content) — and
`λ(c) = c + 6 + a2 + 1`, **affine** in `c` (§5.5, §7.3). Both lines are anchored
to `c` through the align, which is why there are two ramps rather than one.

**Nested align.** `A2 = (find-all B1 B2)` sits at `some`'s align column `c+6`, and
aligns *its* args under `B1` at column `(c+6) + 10 = c + 16` (`"(find-all "` is 10
wide). The inner align column is `c + 16` — still `c + const`. Each nesting level
adds a constant prefix; `c` remains a single linear parameter threading the whole
tree, every overflow term a hockey stick with a content threshold. A numeric sweep
(small widths) again shows membership flipping only at content breakpoints. This is
the §7.3 claim, verified on real LFE.

### 8.4 What the examples corroborate

- Pareto keeps a costlier-shorter class (8.1) — Principle I.
- Cross-product `2^D` prunes to a `D+1` staircase (8.2) — §6.2.
- The `c`-family is `O(D)` hockey sticks with `O(D)` breakpoints, not `O(W)`
  samples (8.2) — §7.2.
- Alignment, including nested alignment, keeps cost a sum of content-threshold
  hockey sticks and `λ` affine (8.3) — §5.5, §7.3.

We also note what the examples do **not** contain: any *fill* layout. Scanning
`gps1.lfe` end to end, every multi-line construct is either one-item-per-line
(the `export`/`import` lists) or align-under-first-arg — never several items
sharing a wrapped line. This is weak but real evidence that the fragment we have
handled is the fragment canonical LFE actually uses (§10.1).


## 9. Complexity and comparison

### 9.1 Estimated complexity

At each of the `n` document nodes, the work is: form the class cross-product
(`O(P²)` pairs, §5.2), and prune (`O(P²)` `O(1)` hockey-stick domination tests,
§6.5), where `P ≈ D` is the right-spine nesting depth (§6.4). So per node `O(D²)`
and overall

> **`O(n · D²)`**, with no dependence on the page width `W`.

For real Lisp, `D` is a small bounded constant (nesting past ~10–15 is rare), so
the estimate is **effectively linear and width-independent**. The pathological
case — a maximally right-nested chain with `D ≈ n` — degrades to `O(n³)`, but such
documents do not arise from hand-written source (§10.2). This is an *estimate*
from the per-node argument, not a proved bound *(reasoned)*.

### 9.2 Against Πₑ

| printer | time | width dependence | bound is… |
|---------|------|------------------|-----------|
| Πₑ (full Σₑ) | `O(n·W⁴)` | quartic in `W` | unconditional |
| Πₑ (aligned only) | `O(n·W³)` | cubic in `W` | unconditional |
| this work (group+nest+align) | `O(n·D²)` *(est.)* | **none** | conditional on `D` small |

The trade is explicit (§3.3): Πₑ's bound holds for *every* document, including
those whose `<|>` structure encodes exponentially many layouts; ours holds when
the surviving-class count stays small, which we argue real Lisp guarantees but
which an adversary can violate. For an 80-column formatter `W ≈ 80–120`, so the
`W⁴`→constant difference is the difference between Πₑ's seconds and (we
conjecture) milliseconds on the S-expression workloads of §1.1 — but that
conjecture awaits implementation and measurement (§12, §13).

### 9.3 Against Yelland and the convexity lineage

Yelland [2016] also removes the `W`-factor by carrying piecewise-linear cost
functions, at `O(n^{3/2})`, but restricts the left operand of aligned
concatenation to literal text and weakens document sharing. Our construction
targets the same `W`-freedom while keeping general `align` (we verified nested
align in §8.3) — the cost being that we have *not* established a sub-quadratic
worst case, only the depth-parameterised estimate of §9.1. Knuth & Plass [1981]
achieve near-linear optimal line breaking by the same underlying move (convex cost
collapses the min-over-predecessors); the difference is that line breaking is
one-dimensional (a flat sequence) whereas pretty-printing is tree-structured, and
our §5–§7 is essentially the bookkeeping needed to keep the one-dimensional trick
working through the tree. Yelland's reported `~√n` pieces and our `~D` classes are
*different counts on different document shapes*; we would not over-trust either as
*the* bound without measurement.

### 9.4 The honest comparison

Πₑ is the right tool when you need a guarantee against arbitrary input and can pay
the `W`-factor. This construction is the right tool when the input is structurally
tame — which a *language-specific* formatter, controlling its own conventions, can
arrange. It is a specialisation, not a strict improvement.


## 10. Limitations and open questions

We are deliberately exhaustive here; the value of the construction is inseparable
from a clear account of where it is unproven or inapplicable.

### 10.1 Fill is unaddressed — the prime suspect

Every argument above relied on a subtree being either flat or followed by a
*forced* newline (Principle II, §6.3). A **fill** layout — pack as many items on a
line as fit, then wrap, as one might for a long argument list or an export list —
breaks that assumption: several items share a line, so a non-last item's exit
column *does* flow into the next item, and the collapse-after-break pruning no
longer applies. Worse, with alignment the shared-line items have `c`-dependent
exits, so the cross-product returns *and* becomes `c`-parameterised. We have not
analysed this case. Two mitigations seem plausible but are unverified: (a) handle
a fill region with a bounded look-ahead or a local width-sampled solve, paying the
`W`-factor only inside fills; (b) avoid fill in the conventions. Evidence that (b)
may suffice: `gps1.lfe` contains no fill at all (§8.4). **Open.**

### 10.2 No worst-case bound; the niceness bet

§9.1 is a per-node estimate, not a theorem, and it degrades to `O(n³)` on
maximally right-nested input. We argue real source is shallow, but we have not
characterised "shallow" formally, nor proved the `P ≈ D` relationship in general —
it is *reasoned* from the two pruning principles and corroborated on small
examples. The whole approach is, at bottom, the bet of §3.3: real Lisp is tame.
Πₑ declined this bet on purpose. A deployed engine should therefore retain a
**fallback** (e.g., to width-sampled Πₑ) when a subtree's class count exceeds a
threshold, converting the bet into a guarantee.

### 10.3 Exactness vs. heuristic pruning

The frontier carries classes that are Pareto-optimal but may never be used
downstream — e.g. the broken `(g a)` of §8.1 is kept on the chance a parent needs
its shorter exit. Exact optimality requires carrying them. A heuristic "drop a
costlier class whose exit-column saving is below ε when a cheaper class already
fits" would shrink `P` further at the price of optimality in rare cases. Whether
that trade is worth it is an empirical, conventions-dependent question. **Open.**

### 10.4 Cost-function choice

We chose piecewise-linear (sum-of-overflow) cost so that every function is a
hockey stick and composition is segment merging (§4.1). Πₑ's default
squared-overflow cost discourages *large* overflows more gracefully but makes each
per-class cost piecewise-*quadratic*, multiplying segment counts and complicating
the domination tests. A practical engine could (a) accept piecewise-linear cost as
a deliberate aesthetic trade, (b) use a piecewise-linear *approximation* of squared
cost, or (c) extend the machinery to piecewise-quadratic envelopes. We have only
worked the piecewise-linear case. **Open.**

### 10.5 What is verified, reasoned, and conjectured

| claim | status |
|-------|--------|
| algebra closed for `text`/`nl`/`<>`/`nest` | **verified** (§5.2–5.3) |
| algebra closed for `align`, incl. nesting | **verified by worked example** (§5.5, §8.3) |
| unaligned `cost(c)` is a 2-piece hockey stick | **verified** (§4.3) |
| frontier membership changes at `O(D)` `c`-breakpoints (nest) | **verified** (§8.2) |
| same under (nested) alignment | **verified by worked example** (§8.3) |
| `P ≈ D` (surviving class count ≈ right-spine depth) | **reasoned** (§6) |
| `O(n·D²)` overall, width-independent | **reasoned estimate** (§9.1) |
| ms-scale on §1.1 S-expr workloads | **conjecture**, awaits implementation (§12) |
| `fill` handled | **not addressed** (§10.1) |
| worst-case sub-quadratic | **not established** (§10.2) |

### 10.6 Methodological caveat

This is the record of one collaborative design session, not a peer-reviewed
result. The worked examples are small and hand-checked; an independent
re-derivation, a property-based check of the algebra against a brute-force oracle
(of the kind already specified for the Πₑ engine spike), and ultimately an
implementation with measurements are all prerequisites before any of the
performance claims should be relied upon.


## 11. Related work

**PrettyExpressive (Πₑ).** Porncharoenwase, Pombrio & Torlak [2023] is the direct
parent of this work: the language Σₑ, the cost-factory abstraction, the
measure/Pareto-frontier resolver, and the optimality guarantee are all theirs, and
the reframing of §3 is simply their frontier read as a function. Our contribution
is to ask what happens if that function is carried symbolically rather than
sampled, specifically for the Lisp fragment. Πₑ's design choice — pay the
`W`-factor to get an unconditional bound and full expressiveness with sharing — is
exactly the choice we revisit, and our construction is best understood as the
"other branch" of that decision.

**Optimal line breaking.** Knuth & Plass [1981] frame paragraph line breaking as a
least-cost dynamic program and solve it in near-linear time by exploiting
convexity of the badness cost (the modern framing: the Monge/quadrangle inequality
and SMAWK-style row minima; for linear costs, the convex-hull trick). Our §7 is
the same idea — convex cost makes the per-position optimisation collapse — adapted
from a flat sequence to a tree.

**Yelland's piecewise-linear formatter.** Yelland [2016] is the closest prior art
on the pretty-printing side: it represents cost as a piecewise-linear function of
the starting column and composes those functions symbolically, achieving
`O(n^{3/2})` with no `W`-factor. It restricts the left operand of aligned
concatenation to literal text and weakens sharing. We target the same
`W`-freedom while keeping general (nested) alignment, at the cost of a weaker
(depth-parameterised, unproven) complexity statement.

**Arbitrary-choice printers.** Bernardy [2017] uses Pareto frontiers to find
optimal layouts and is the acknowledged inspiration for Πₑ's measures; it is
expressive and optimal but exponential in the document size in the worst case (and
later dropped the arbitrary-choice operator for that reason). Swierstra et al.
[1999] and Podkopaev & Boulytchev [2015] are earlier points on the same line.

**Traditional / greedy printers.** Oppen [1980], Wadler [2003], Leijen [2000],
Hughes [1995], and Chitil [2005] make layout choices greedily (the single
`group` choice, decided by a local "does the flat form fit" test). They are fast
and simple but neither minimise overflow nor minimise lines in general. They are
relevant to us as a *fallback and hybrid* substrate: a greedy printer can handle
the common case, with an optimal engine (Πₑ or this one) invoked only where greedy
overflows (§12).

**On the BEAM.** We are not aware of any expressive-and-optimal pretty printer
implemented for the Erlang VM; the existing BEAM document algebras (`erlfmt`'s
`erlfmt_algebra`, Elixir's `Inspect.Algebra`, OTP's `prettypr`) are
Wadler-family greedy printers. Both the Πₑ port and the present construction would,
to our knowledge, be firsts for the platform.


## 12. Implementation outlook (BEAM) and project placement

### 12.1 The representation is BEAM-shaped

The objects this construction manipulates are a natural fit for Erlang. A convex
piecewise-linear function is a **slope-sorted list of segments**; infimal
convolution and lower-envelope merges are **sorted-list merges**; a hockey stick
is a three-field tuple. All of this is pattern-matching over small immutable terms
— the BEAM's home ground — with no need for the mutable, identity-keyed structures
that the width-sampled Πₑ port leans on. The per-node state is *smaller* than
Πₑ's (`O(D)` hockey-stick tuples vs. up to `W+1` sampled measures), which also
shrinks the memo and improves locality.

### 12.2 Parallelism composes with the algebra

The construction is purely functional, so it inherits the coarse parallelism a
formatter wants for free: a source file is a sequence of *independent* top-level
forms, formatted in parallel across schedulers; a project is independent files.
Because there is no width sampling and no shared mutable resolver state, there is
nothing to coordinate. (The finer, per-subproblem parallelism that tempts one on
the BEAM is a trap here, as it is for Πₑ: a single node's work is a handful of
hockey-stick merges, far smaller than message-passing overhead.)

### 12.3 A fallback makes the bet safe

Per §10.2, a deployed engine should monitor the surviving class count per node and,
if it exceeds a threshold (deep right-nesting, or a `fill` region), fall back to
width-sampled Πₑ for that subtree. This converts the "real Lisp is tame" bet into
a guarantee: tame input is formatted in width-independent time; pathological input
is merely no worse than Πₑ. The two engines share the cost-factory abstraction and
the document reader, so the fallback boundary is clean.

### 12.4 Where this sits in the project

This is a **research result, not a committed plan**. The committed path is the
straightforward Πₑ port (the `arc1-poc / slice1-resolver` spike), whose explicit
job is to answer *whether even the direct, width-sampled Πₑ is fast enough on real
LFE*. Two outcomes:

- **If Πₑ clears the latency bar**, this construction is an optional future
  optimisation — pursued only if profiling shows the `W`-factor is the bottleneck.
- **If Πₑ does not clear the bar**, this construction becomes a leading candidate
  for the engine — promoted to its own arc (provisionally *arc2*), gated on first
  reproducing the §8 results in code and property-testing the algebra against the
  same brute-force oracle the PoC already builds.

Either way, the PoC's instrumentation can pay a second dividend cheaply: dumping
each node's `(λ, cost)` frontier on real LFE lets us **measure empirically**
whether frontiers are as tame (few classes, convex) as §6–§7 assume — turning the
central *bet* into data before any further investment. That measurement is the
recommended immediate next step (§13).


## 13. Conclusion and next steps

The page-width factor in PrettyExpressive is a consequence of representing each
subtree's cost-to-column frontier by `W+1` point samples. Carry that frontier
**symbolically** — as a small set of piecewise-linear "hockey-stick" classes — and,
for the `group + nest + align` fragment that canonical LFE actually emits, the
width factor appears to vanish: the algebra is closed under composition, two
pruning principles (Pareto on `(exit-column, cost)`, and collapse-after-break) hold
the surviving class count near the document's right-spine nesting depth `D`, and
the start-column dependence is captured by `O(D)` content-determined breakpoints
rather than by enumerating columns. The estimated cost is `O(n·D²)`,
width-independent, with `D` a small constant for real code — which, *if it holds in
implementation*, would turn PrettyExpressive's worst workload (S-expressions) into
a non-issue for a Lisp formatter.

We have been explicit about the limits (§10): this is hand-derivation and
structural argument, not proof; the `fill` style is unhandled and is the prime
suspect for reintroducing blowup; there is no worst-case guarantee, and the whole
approach is a bet that real Lisp is structurally tame — a bet a fallback to
width-sampled Πₑ can make safe.

**Recommended next steps, in order:**

1. **Measure the bet.** Instrument the Πₑ engine PoC to dump per-node
   `(λ, cost)` frontiers on a corpus of real LFE; check empirically whether
   surviving-class counts and convexity match §6–§7. Cheap, decisive, and it rides
   on work already scheduled.
2. **Property-test the algebra.** Implement §4–§5 and check, against the same
   brute-force oracle the PoC builds, that the symbolic resolver's optimum equals
   the true optimum on small documents — converting "verified by hand" into
   "verified by machine."
3. **Resolve `fill`** (§10.1): either show LFE conventions avoid it, or design the
   bounded-width local solve for fill regions.
4. **Settle the cost function** (§10.4): piecewise-linear as the production cost,
   or a piecewise-linear approximation of squared overflow.
5. **Only then**, if the PoC shows the `W`-factor is the real bottleneck, promote
   this to an implementation arc with a fallback (§12.3, §12.4).

The intellectual core is small and, we think, genuinely promising: *a Lisp
formatter controls its own conventions, so it can stay inside the tame fragment
where optimal layout costs nothing extra for width.* Whether that promise survives
contact with an implementation and a real corpus is the next thing to find out.

---

### References (informal)

- J.-P. Bernardy. *A Pretty But Not Greedy Printer.* ICFP 2017.
- O. Chitil. *Pretty printing with lazy dequeues.* TOPLAS 2005.
- J. Hughes. *The Design of a Pretty-printing Library.* 1995.
- D. E. Knuth, M. F. Plass. *Breaking Paragraphs into Lines.* Softw. Pract.
  Exper. 1981.
- D. Leijen. *wl-pprint* (Wadler/Leijen pretty printer). 2000.
- D. Oppen. *Prettyprinting.* TOPLAS 1980.
- A. Podkopaev, D. Boulytchev. *Polynomial-time optimal pretty-printing
  combinators with choice.* 2015.
- S. Porncharoenwase, J. Pombrio, E. Torlak. *A Pretty Expressive Printer.*
  OOPSLA 2023.
- S. D. Swierstra et al. *Pretty printing combinators.* 1999.
- P. Wadler. *A prettier printer.* 2003.
- P. Yelland. *A New Approach to Optimal Code Formatting.* 2016.
