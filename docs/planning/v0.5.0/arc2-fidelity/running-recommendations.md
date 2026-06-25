# Running Recommendations — carried forward (arc2 staging)

> Scratch staging file. `workbench/` is gitignored; this holds the still-live
> recommendations and the optimisation ideas carried out of `arc1-poc` so they
> are not lost between arcs. **Move this into the arc2 planning directory when it
> is created.** Item IDs keep their arc1 labels for traceability; renumber on
> adoption into the arc2 register.
>
> Provenance: carried from
> `docs/planning/v0.1.0/arc1-poc/running-recommendations.md` (the still-open /
> watch items) and `docs/planning/v0.1.0/arc1-poc/optimisation-ideas.md` (all of
> it — forward-looking). The arc1 file retains the *addressed* items as the
> historical record.

## Status Key

- **open** — still needs investigation or implementation.
- **watch** — not a current blocker, but should be kept visible.

## Carried recommendations (still live)

### A1-R002: Treat benchmark timing columns as illustrative, not golden data

- **Status:** watch
- **Source:** Slice1 benchmark verification.
- **Concern:** The benchmark artifacts are reproducible in shape but not
  bit-for-bit stable: timing columns vary between runs. Microsecond differences
  from short runs are useful for gross comparisons, but easy to over-read.
- **Recommendation:** Keep committed CSVs as sample-output artifacts. For
  performance conclusions, compare stable structural counters first (`calls`,
  `memo_size`, `tainted`, output size), and use timing only across repeated,
  fresh-process runs with enough duration to reduce noise.
- **Re-entry trigger:** Any claim that one backend or layout strategy is faster
  based mainly on one short benchmark run.

### A1-R003: Keep the map memo backend as the baseline until larger workloads say otherwise

- **Status:** watch
- **Source:** Slice1 backend benchmark review.
- **Concern:** The map memo backend looked best at the slice1 scale; ETS was
  slower in that small local workload, and the process-dictionary backend should
  remain benchmark-only.
- **Recommendation:** Keep `pe_memo_map` as the default backend. Revisit ETS
  only if later workloads show shared-state, memory, or table-size pressures
  where ETS has a measured advantage.
- **Re-entry trigger:** Large fixture corpora, concurrent formatting scenarios,
  or profiling that shows map memo operations dominating runtime or memory.

### A1-R005: Carry deferred compatibility and audit work forward explicitly

- **Status:** open
- **Source:** Slice1 and slice2 ledgers.
- **Concern:** OTP 22-29 compatibility, coverage gating, and CAP-style strength
  audit were validly deferred rather than silently dropped.
- **Recommendation:** Keep these as named planning items rather than letting them
  blur into general polish. The backport slice should make OTP markers
  mechanically greppable; the audit slice should classify coverage and
  correctness evidence by strength.
- **Re-entry trigger:** Before calling the PoC complete, publishing it as a
  reusable library substrate, or setting CI expectations.

### A1-R008: Make the renderer's width model explicit

- **Status:** open
- **Source:** Slice2 implementation review.
- **Concern:** `pe_render` currently advances columns with `string:length(Bin)`.
  That is acceptable for the ASCII-heavy PoC fixtures, but a formatter eventually
  needs a declared policy for display width.
- **Recommendation:** Decide whether the formatter's width semantics are ASCII
  byte width, Unicode grapheme/display width, or a width already measured and
  carried through the document. Then encode that decision in specs, tests, and
  docs before real user input broadens.
- **Re-entry trigger:** Parser integration, Unicode/string fixture addition, or
  any public API contract around page width.

### A1-R015: Move from hand-built `form()` terms toward parser-derived samples

- **Status:** open
- **Source:** Slice3 caveat checklist and CDC verification.
- **Concern:** Slice3 is a real knowledge layer, but the corpus is still
  hand-built `pe_lfe:form()` terms. It proves lowering and layout strategy, not
  source fidelity, comment behavior, reader edge cases, or parser integration.
- **Recommendation:** Add a later slice that builds `form()` terms from actual
  LFE source or ASTs for at least a small fixture set. Keep source fidelity and
  comment preservation as explicit questions rather than inferred properties.
- **Re-entry trigger:** Before claiming this is an LFE formatter rather than a
  knowledge-layer PoC.

### A1-R018: Newline cost diverges from mjl on indentation overflow (kept ours)

- **Status:** open (documented divergence; operator chose to keep ours)
- **Source:** Slice8 differential oracle against mjl `print.rs`.
- **Concern:** mjl's `print.rs` resolves a broken `Newline` to a measure with
  cost `(0, 1)` — one newline, **no charge for the indentation that follows**.
  Our resolver charges `text_cost(0, I)` for the indentation per the paper's
  LineM rule, so when an indentation level `I` exceeds the page width `W` our
  newline costs more than mjl's. The two engines therefore diverge only when a
  line's indentation alone overruns `W`.
- **Decision (operator, 2026-06-24):** keep ours (the paper-faithful LineM
  charge); bound the differential-oracle corpus so the divergence is never
  exercised (`pe_oracle_mjl` generates shallow nests / short text and sweeps
  widths `{40, 80, 120}`, keeping every reachable indentation well under the
  smallest width). The in-BEAM oracle is self-consistent and needs no bound.
- **Differential-oracle scope note (revised in iteration 1):** `cost` (explicit
  cost injection) is **in** the differential corpus. The original 8a comparator
  recomputed cost from the rendered string, which cannot see an injected cost
  (two layouts tying on internal cost recompute to different string costs, and
  we deliberately do not replicate mjl's memo tie-break) — so 8a excluded it.
  Iteration 1 changed the canonical comparator to **reported optimal cost**
  (`pe_measure:cost/1` vs mjl `PrintResult::cost()`), which both engines compute
  identically through an injected `cost` node, so cost-bearing documents are now
  exercised (the committed `oracle_samples.csv` carries such rows, e.g.
  `(cost 3 1 (cost 0 1 (t "cwv")))` ⇒ string `"cwv"` but both report `(3, 2)`).
  `cost` remains additionally covered by the in-BEAM brute-force oracle and the
  `cost` algebra doctests in `pe_algebra_tests`.
- **Re-entry trigger:** If a future requirement needs parity with mjl on
  deeply-indented documents, reconcile the newline cost models so the two
  *reported* costs agree past the page width — either drop our LineM indentation
  charge, or add the equivalent charge to mjl — and then lift the corpus
  indentation bound.

### A1-R020: Deferred LFE forms are a future conventions slice

- **Status:** open (planning hook)
- **Source:** Slice9 provenance cross-reference against `lfe-indent.el`.
- **Concern:** slice9 covers the slice3 dispatch set (+`catch` demonstrator),
  but the Emacs `define-lfe-indent` table names many forms LFE has conventions
  for that we do not yet lay out specially: `if`, `try`, `do`, comprehensions
  (`lc`/`bc`/`list-comp`/`binary-comp`), the `let-function`/`letrec-function`/
  `let-macro`/`macrolet` binders, `prog1`/`prog2`, `define-module`/
  `extend-module`, and old-style `begin`/`let-syntax`/`syntax-rules`/`macro`.
  These fall to the generic fallback today.
- **Recommendation:** A future **conventions** slice adds these. The ones that
  fit an existing palette style (`let-function`→`flet-binds`, `begin`→`block`,
  etc.) are data-only rows; the genuinely new shapes (`if`, `try`, `do`,
  comprehensions, `prog1/2`'s distinguished head) each need a new palette
  function + `apply_style` clause + its own golden — one real layout decision
  apiece, which is why slice9 deliberately added only the single `catch`
  demonstrator.
- **Re-entry trigger:** When broadening LFE formatting coverage beyond the
  slice3 corpus, or before claiming the formatter handles idiomatic LFE.

## Optimisation ideas (carried from arc1-poc/optimisation-ideas.md)

> Informal notes, not a spec. Captured from the arc1-poc "turn it on its side"
> brainstorm (June 2026): the BEAM-leaning ideas for making up the performance
> ground Πₑ loses on S-expression workloads. Confidence tagged *(grounded /
> promising / bet / trap)*. The arc1 measurement step (does plain Πₑ clear the
> latency bar; per-node frontier dump testing the convexity "niceness" bet) was
> completed in slice1 + slice7 — recorded as *addressed* in the arc1 register;
> the levers below remain to be built.

### The framing: three axes

There are exactly three ways to make up the `O(n·W⁴)` ground:

1. **Do less work** — algorithmic (Levers 1, 3, and the convexity rewrite).
2. **Use more cores** — parallelism; the BEAM's cheap-process superpower (Lever 2).
3. **Don't redo work** — caching / incremental (the format server).

The BEAM is unusually strong at #2 and #3 *cheaply*. #1 is where the big
asymptotic wins live.

### Lever 1 — Lisp lives in the cheaper sublanguage *(grounded; highest-confidence free win)*

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

### Lever 2 — per-top-level-form (and per-file) parallelism *(grounded; build it first)*

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

### Lever 3 — greedy-first, optimal-repair hybrid *(promising; biggest practical upside)*

Most code fits fine under a cheap greedy (Wadler-style, `O(n)`) pass. Run greedy
everywhere; invoke expensive Πₑ (or the symbolic engine) **only on the subtrees
greedy overflowed or laid out badly**. Pay for optimality exactly where it buys
something. Repair units are independent → parallel (composes with Lever 2).

- Risk (principled): defining "greedy did badly here" and guaranteeing the
  repaired result is actually optimal-in-context.
- Worth prototyping once both a greedy and an optimal engine exist.
- Note: BEAM already has greedy document algebras to borrow from
  (`erlfmt_algebra`, Elixir `Inspect.Algebra`, OTP `prettypr`).

### The convexity / symbolic rewrite — *the one we chased*

Pretty-printing ≈ shortest-path / Knuth–Plass; the Pareto frontier is a
cost-to-column function; carry it symbolically (piecewise-linear) instead of
sampling `W` columns → width-independent for the `group+nest+align` fragment.

- **Fully written up** in `docs/research/symbolic-pwl-frontier.md` (repo-root
  relative). See there.
- Status: hand-derived, not proved; `fill` unhandled; a bet on real-Lisp niceness.
- This is the deepest "do less work" win if it survives implementation.
- Empirical input already gathered: slice7 dumped per-node Pareto frontier widths
  (`bench/results/frontier.csv`) to test the "niceness" bet.

### Don't-redo-work — the formatting server + incremental *(promising; the real UX win)*

The dominant *interactive* use is format-on-save, where one form changed. A
formatting **gen_server** with a content-addressed cache
(`hash(form-source) → formatted output`, in ETS / `persistent_term`) makes
reformatting an unchanged form free, and incremental formatting reformats only the
edited form. This sidesteps the perf problem entirely for the editor case; the
cold `rebar3` run is the only place you pay full price, and Lever 2 covers that.

- Most OTP-idiomatic "productisation" angle.
- `persistent_term` also good home for the static conventions table (already used
  by slice9's rule registry as a read-only cache).

### The trap to avoid *(do not build)*

**Process-per-subproblem dataflow** — an actor per `(node, c, i)` that messages
its dependencies. Sounds maximally BEAM-y; is overhead-bound. Each subproblem's
real work is a Pareto/segment merge of a handful of tiny tuples — the
message-passing overhead per dependency edge dwarfs the computation. Parallelism
here wants to be **coarse** (forms, files, repair-subtrees), never per-cell. Same
caution applies to the symbolic engine.

### Suggested ordering

1. **Measure** — does plain Πₑ even clear the latency bar? Also dump per-node
   frontiers to test the convexity "niceness" bet empirically. *(Done in arc1:
   slice1 latency + slice7 frontier dump.)*
2. **Lever 2** (per-form/file parallelism) — free constant-factor, build anyway.
3. **Lever 1** (aligned-only) — free `W`-factor if LFE stays aligned; quick test.
4. If still short: **Lever 3** (greedy-repair) and/or the **symbolic engine**
   (the paper) — the asymptotic wins.
5. **Format server / incremental** — orthogonal; the interactive-UX win, whenever
   editor integration matters.
