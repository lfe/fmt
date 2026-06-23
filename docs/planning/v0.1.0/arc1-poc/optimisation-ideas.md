# Optimisation ideas — working notes

> Informal notes, not a spec. Captured from the arc1-poc "turn it on its side"
> brainstorm (June 2026). These are the BEAM-leaning ideas for making up the
> performance ground Πₑ loses on S-expression workloads. Confidence tagged
> *(grounded / promising / bet / trap)*. Revisit once the slice1 PoC gives us
> real numbers.

## The framing: three axes

There are exactly three ways to make up the `O(n·W⁴)` ground:

1. **Do less work** — algorithmic (Levers 1, 3, and the convexity rewrite).
2. **Use more cores** — parallelism; the BEAM's cheap-process superpower (Lever 2).
3. **Don't redo work** — caching / incremental (the format server).

The BEAM is unusually strong at #2 and #3 *cheaply*. #1 is where the big
asymptotic wins live.

---

## Lever 1 — Lisp lives in the cheaper sublanguage *(grounded; highest-confidence free win)*

Πₑ is `O(n·W⁴)` for full Σₑ but **`O(n·W³)` for the aligned-only fragment** — and
the paper explicitly notes aligned concatenation is the *Lisp/Haskell/R/Julia*
tradition, while unaligned `<>` is the C-family one. The extra factor of `W` is
paid precisely for unaligned concat. If LFE conventions almost never need
unaligned concat, **we drop a whole factor of `W` for free** just by staying in
the aligned fragment.

- Confidence: high that the factor is real; medium that LFE *never* needs `<>`
  (the paper warns even Lisp occasionally wants a prefix merging into a first
  line).
- Action: cheap to test — implement aligned-only, see what (if anything) breaks.
  This is the first thing to actually measure.

## Lever 2 — per-top-level-form (and per-file) parallelism *(grounded; build it first)*

A source file is a *sequence of independent top-level forms* — formatting
`(defun foo …)` cannot affect `(defun bar …)` (modulo trivial blank-line
handling). So whole-file formatting is embarrassingly parallel at coarse grain:
parallel-map forms across schedulers, near-zero coordination, no shared mutable
state. And `rebar3 lfe format` runs on files and whole projects, so the real
workload is *already* a bag of independent units — parallel at the form level and
the file level.

- Magnitude: if Πₑ is ~15× slower per form than greedy, 8–16 cores recover most of
  that for the actual whole-file/project use case. Doesn't change asymptotics;
  recovers the constant.
- Why it's safe: `resolve` is pure → no locks; duplicate work (if any) is
  idempotent.
- ~20 lines. Do this regardless of which engine wins.

## Lever 3 — greedy-first, optimal-repair hybrid *(promising; biggest practical upside)*

Most code fits fine under a cheap greedy (Wadler-style, `O(n)`) pass. Run greedy
everywhere; invoke expensive Πₑ (or the symbolic engine) **only on the subtrees
greedy overflowed or laid out badly**. Pay for optimality exactly where it buys
something. Repair units are independent → parallel (composes with Lever 2).

- Risk (principled): defining "greedy did badly here" and guaranteeing the
  repaired result is actually optimal-in-context.
- Worth prototyping once both a greedy and an optimal engine exist.
- Note: BEAM already has greedy document algebras to borrow from
  (`erlfmt_algebra`, Elixir `Inspect.Algebra`, OTP `prettypr`).

## The convexity / symbolic rewrite — *the one we chased*

Pretty-printing ≈ shortest-path / Knuth–Plass; the Pareto frontier is a
cost-to-column function; carry it symbolically (piecewise-linear) instead of
sampling `W` columns → width-independent for the `group+nest+align` fragment.

- **Fully written up** in `../../research/symbolic-pwl-frontier.md`. See there.
- Status: hand-derived, not proved; `fill` unhandled; a bet on real-Lisp niceness.
- This is the deepest "do less work" win if it survives implementation.

## Don't-redo-work — the formatting server + incremental *(promising; the real UX win)*

The dominant *interactive* use is format-on-save, where one form changed. A
formatting **gen_server** with a content-addressed cache
(`hash(form-source) → formatted output`, in ETS / `persistent_term`) makes
reformatting an unchanged form free, and incremental formatting reformats only the
edited form. This sidesteps the perf problem entirely for the editor case; the
cold `rebar3` run is the only place you pay full price, and Lever 2 covers that.

- Most OTP-idiomatic "productisation" angle.
- `persistent_term` also good home for the static conventions table.

---

## The trap to avoid *(do not build)*

**Process-per-subproblem dataflow** — an actor per `(node, c, i)` that messages
its dependencies. Sounds maximally BEAM-y; is overhead-bound. Each subproblem's
real work is a Pareto/segment merge of a handful of tiny tuples — the
message-passing overhead per dependency edge dwarfs the computation. Parallelism
here wants to be **coarse** (forms, files, repair-subtrees), never per-cell. Same
caution applies to the symbolic engine.

---

## Suggested ordering (once slice1 PoC numbers land)

1. **Measure** — does plain Πₑ even clear the latency bar? (slice1.) Also dump
   per-node frontiers to test the convexity "niceness" bet empirically.
2. **Lever 2** (per-form/file parallelism) — free constant-factor, build anyway.
3. **Lever 1** (aligned-only) — free `W`-factor if LFE stays aligned; quick test.
4. If still short: **Lever 3** (greedy-repair) and/or the **symbolic engine**
   (the paper) — the asymptotic wins.
5. **Format server / incremental** — orthogonal; the interactive-UX win, whenever
   editor integration matters.
