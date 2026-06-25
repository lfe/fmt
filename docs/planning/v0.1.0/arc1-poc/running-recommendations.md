# Arc 1 PoC Running Recommendations

This document is the living register for recommendations, concerns, and follow-up
ideas that emerge while reviewing the PrettyExpressive-on-BEAM PoC slices. It is
not a replacement for per-slice ledgers or verification reports: those remain
the evidence record for what was specified and completed. This file captures the
cross-slice judgment that is easy to lose in conversation: performance risks to
stress later, implementation improvements that are not blockers yet, modeling
questions that affect LFE usefulness, and planning hooks for future slices.

When adding to this file, keep each item concrete enough to become a slice row,
audit item, benchmark scenario, or implementation ticket. Recommendations may be
left open, marked addressed, or superseded, but should not be deleted merely
because the current slice is moving on.

## Status Key

- **open** - still needs investigation or implementation.
- **watch** - not a current blocker, but should be kept visible.
- **addressed** - handled by a later slice or explicit decision; retained for
  context.

## Slice 1: Resolver PoC

### A1-R001: Stress the all-tainted fallback path

- **Status:** addressed by slice4, keep watching
- **Source:** CDC verification of slice1 resolver.
- **Concern:** Slice1 proved promising resolver behavior on the tested DAGs, but
  the disclosed all-tainted `optimal/1` / leftmost-widening path remains the
  main algorithmic performance risk. The current data does not show that this
  path dominates real workloads, only that it exists.
- **Recommendation:** Add an explicit stress slice or benchmark family that
  constructs workloads likely to force all-tainted or mostly-tainted resolution:
  very narrow widths, many nested choices, long s-expression lists, and deeply
  nested forms whose flat alternatives repeatedly overflow.
- **Current plan:** `slice4-pathological-stress-corpus` is planned to exercise
  this risk with forced no-fit rows, narrow widths, tainted/badness counters, and
  timeout-safe benchmark execution.
- **Slice4 result:** The stress corpus added forced no-fit/proxy rows and
  non-zero badness/tainted evidence, but did not add exact all-tainted-path
  instrumentation. Keep the exact internal-path question visible if resolver
  work resumes.
- **Re-entry trigger:** Before relying on the PoC for large generated LFE files,
  macro-heavy forms, or formatter-wide performance claims.

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

### A1-R004: Preserve real-input validation as a recurring gate

- **Status:** addressed by slice2, keep watching
- **Source:** Slice1 closure recommendation.
- **Concern:** Slice1 intentionally stopped at the cost/measure resolver layer:
  no rendering, no public facade, no real-LFE-shaped inputs.
- **Recommendation:** Continue requiring end-to-end real-input checks in later
  slices. Slice2 added rendering, facade APIs, and 20 real-LFE-shaped fixtures.
  Slice3 moved the corpus through an explicit LFE knowledge layer; future slices
  should move toward parser-derived forms and source-fidelity evidence.
- **Re-entry trigger:** Any new engine or layout feature that is only validated
  against symbolic documents.

### A1-R005: Carry deferred compatibility and audit work forward explicitly

- **Status:** open
- **Source:** Slice1 and slice2 ledgers.
- **Concern:** OTP 22-29 compatibility, coverage gating, and CAP-style strength
  audit were validly deferred rather than silently dropped.
- **Recommendation:** Keep these as named planning items rather than letting them
  blur into general polish. The backport slice should make OTP markers
  mechanically greppable; the audit slice should classify coverage and
  correctness evidence by strength.
- **Re-entry trigger:** Before calling arc1 complete, publishing the PoC as a
  reusable library substrate, or setting CI expectations.

## Slice 2: Render + Real-LFE Viability Samples

### A1-R006: Build an LFE knowledge layer; do not rely on generic s-expression layout

- **Status:** addressed by slice3, keep watching
- **Source:** Slice2 review and benchmark output inspection.
- **Concern:** The engine handled the 20 fixtures well, but generic `sexp`
  alignment drifts too far right for some Lisp forms. `lfe_07_bq_expand` is the
  visible example: wrapping a `defun` inside `(eval-when-compile ...)` via a
  generic call combinator makes the inner body align awkwardly.
- **Recommendation:** Make slice3 focus on an LFE knowledge layer with form-aware
  rules for `defun`, `defmacro`, `lambda`, `let`, `case`, `receive`, `cond`,
  `eval-when-compile`, quasiquote/unquote, long argument lists, and clause-like
  bodies. Generic sexp formatting should be the fallback, not the main strategy.
- **Re-entry trigger:** Slice3 planning and any discussion of LFE formatter
  usefulness or visual quality.

### A1-R007: Add a pathological s-expression stress corpus

- **Status:** addressed by slice4
- **Source:** Slice2 viability assessment.
- **Concern:** Slice2's numbers are encouraging: all 40 rows had `badness = 0`,
  sub-millisecond timings, and no all-tainted failures. But these fixtures are
  moderate, hand-shaped forms; they do not yet answer the worst-case Lisp
  question.
- **Recommendation:** Add a stress corpus that deliberately targets difficult
  Lisp structures: narrow widths, long proper and improper lists, deeply nested
  macro/quasiquote forms, long `let` binding lists, long function calls, nested
  `case`/`receive` clauses, and generic sexps with no special knowledge-layer
  help.
- **Current plan:** `slice4-pathological-stress-corpus` is planned to implement
  this as a deterministic corpus plus `bench/results/lfe_stress.csv`, with
  stable structural counters prioritized over timing.
- **Slice4 result:** Implemented as 25 deterministic samples across the requested
  families, benchmarked at widths 20, 40, 60, 80, and 100, with 125 committed
  CSV rows and no timeout/error rows in the sample run.
- **Re-entry trigger:** After the first LFE knowledge-layer slice, or before
  claiming algorithmic feasibility for broad LFE formatting.

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

### A1-R009: Harden the benchmark harness against worker crashes

- **Status:** addressed by slice3
- **Source:** Slice2 implementation review.
- **Concern:** The benchmark uses a fresh spawned process per repeat, which is
  good timing hygiene, but a crashing worker would leave the parent waiting for
  a result message.
- **Recommendation:** Use `spawn_monitor` or equivalent monitored worker logic
  in `pe_lfe_bench:run_once/1`, and report worker exits explicitly. This keeps
  the harness from hanging during future stress cases.
- **Re-entry trigger:** Before adding intentionally pathological fixtures or
  using the harness in unattended CI.

### A1-R010: Avoid small avoidable allocations in benchmark-side metrics

- **Status:** addressed by slice3
- **Source:** Slice2 implementation review.
- **Concern:** `pe_lfe_bench:count_char/2` currently counts newlines by building
  a list and taking its length. The current binaries are tiny, so this is not a
  blocker.
- **Recommendation:** If benchmark output grows, replace the list-comprehension
  count with an accumulator/fold-style binary scan. Keep this as a cleanup item,
  not a premature optimization.
- **Re-entry trigger:** Larger rendered outputs, stress corpus runs, or profiler
  evidence that benchmark-side metrics distort timing.

### A1-R011: Keep fixture fidelity limits visible

- **Status:** addressed by slice3
- **Source:** Slice2 fixture review.
- **Concern:** `pe_lfe_samples` is intentionally a hand-built spec interpreter
  over real-LFE-shaped forms. That was the right slice2 tradeoff, but the outputs
  are canonicalized shapes, not byte-for-byte source-derived formatting.
- **Recommendation:** Treat slice2 fixtures as engine and rendering probes, not
  proof that source-preserving LFE formatting is solved. Later slices should add
  parser-derived forms or a bridge from actual LFE syntax/AST into the document
  model.
- **Re-entry trigger:** Any claim about source fidelity, comment preservation,
  reader syntax edge cases, or exact LFE formatting behavior.

### A1-R012: CSV escaping is fine for current labels, but should not become a hidden assumption

- **Status:** addressed by slice3
- **Source:** Slice2 benchmark review.
- **Concern:** The current benchmark CSV writer emits binary fields directly
  without CSV quoting. The current labels are controlled and comma-free, so this
  is not a defect today.
- **Recommendation:** If benchmark metadata becomes user-provided or labels gain
  commas, quotes, or newlines, add minimal CSV escaping or switch to a structured
  writer.
- **Re-entry trigger:** Expanding sample metadata, importing labels from source
  files, or consuming CSVs with stricter tooling.

## Slice 3: LFE Knowledge Layer

### A1-R013: Add context-sensitive layout for special forms in argument position

- **Status:** addressed by slice5, keep watching
- **Source:** Slice3 CDC verification of `lfe_08_ets_new`.
- **Concern:** Slice3 fixed the top-level `eval-when-compile` drift, but a
  special form used as a call argument still inherits generic argument
  alignment. The visible case is `(lists:foreach (match-lambda ...) ...)`,
  where `match-lambda` aligns under the `lists:foreach` argument column and its
  body shifts right.
- **Recommendation:** Add a knowledge-layer rule or combinator for block-valued
  arguments: when an argument is itself a known block form (`lambda`,
  `match-lambda`, `case`, `receive`, `cond`, etc.), allow it to break from the
  call with a local block indentation rather than generic first-argument align.
- **Current plan:** `slice5-lfe-layout-refinements` is planned to address this
  alongside `flet`/`fletrec` binding layout, with `lfe_08_ets_new` and the
  slice4 `block_arg_*` stress samples as evidence targets.
- **Slice5 result:** `pe_lfe` now detects `lambda`, `match-lambda`, `case`,
  `receive`, and `cond` in generic-call argument position and lowers those
  calls with a local block indentation. `lfe_08_ets_new` and the slice4
  `block_arg_*` stress canaries have targeted tests and refined benchmark rows.
- **Re-entry trigger:** Next knowledge-layer refinement slice, especially before
  judging visual quality on higher-order calls.

### A1-R014: Give `flet`/`fletrec` function bindings clause-like layout

- **Status:** addressed by slice5, keep watching
- **Source:** Slice3 CDC verification of `lfe_20_eval_receive`.
- **Concern:** `fletrec` itself is recognized, but its function-definition
  binding still formats through generic list layout. The result separates the
  function name, arg list, and body in a way that is mechanically valid but not
  yet the natural LFE shape for local function definitions.
- **Recommendation:** Teach the knowledge layer a binding-shape rule for
  `flet`/`fletrec`: bindings of the form `(name (args...) body...)` should lower
  through the same clause/body machinery used by `defun`-style forms, with the
  body nested under the local function head.
- **Current plan:** `slice5-lfe-layout-refinements` is planned to address this
  with `lfe_20_eval_receive` and the slice4 `fletrec_bindings_12` stress sample
  as evidence targets.
- **Slice5 result:** `pe_lfe` now gives `flet`/`fletrec` bindings shaped
  `(name (args...) body...)` a local name+args head with the body nested below
  it, while non-function binding shapes retain the previous generic fallback.
  `lfe_20_eval_receive` and `fletrec_bindings_12` have targeted tests and
  refined benchmark rows.
- **Re-entry trigger:** Next knowledge-layer refinement slice, or any corpus
  expansion involving local functions.

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

## Slice 4: Pathological Stress Corpus

### A1-R016: Keep the whole stress row inside the timeout boundary

- **Status:** addressed by slice5, keep watching
- **Source:** Slice4 CDC review of `pe_lfe_bench:stress_row/3`.
- **Concern:** The stress benchmark wraps resolve/render work in a monitored
  timeout, but computes `dag_size` by building the sample before entering that
  monitored worker. The current 25 samples are bounded and safe, so this did not
  affect the slice4 evidence. However, future larger or generator-heavy stress
  cases could still wedge the parent during pre-worker construction.
- **Recommendation:** Move document construction, `dag_size`, resolve, and render
  into the monitored worker as one timed operation. Timeout/error rows can report
  `dag_size = 0` or a blank field when construction never completed. Add a
  targeted test if a cheap delayed-build seam becomes available.
- **Current plan:** `slice5-lfe-layout-refinements` is planned to include this
  cleanup so future stress expansions inherit a stronger timeout boundary.
- **Slice5 result:** `pe_lfe_bench:stress_row/3` now runs document construction,
  `pe_doc:size/1`, resolve, render, and metric extraction inside the monitored
  worker. Timeout/error rows report `dag_size = 0` when the worker does not
  produce metrics.
- **Re-entry trigger:** Before expanding the stress corpus sizes, adding
  generator-driven stress cases, or running the benchmark unattended in CI.

## Slice 8: Alignment with Rust `pretty-expressive` (mjl)

### A1-R017: `limit` default changed to `trunc(1.2 * Width)` (reviewed, not silent)

- **Status:** addressed (landed in slice8), keep watching
- **Source:** Slice8 alignment with mjl `cost.rs`
  (`limit() = computation_width.unwrap_or((1.2 * page_width) as usize)`);
  operator decision 2026-06-24.
- **Change:** `pe:with_defaults/1` previously defaulted the computation-width
  `limit` to the page `Width`; it now defaults to `trunc(1.2 * Width)`, matching
  mjl. Explicit `limit` callers are unaffected. This is an **output-affecting**
  default change — a wider limit lets the resolver keep more candidate layouts
  before tainting, so some documents now resolve to a different (lower-cost)
  layout than before. Recorded here and in `CHANGELOG.md` per `CLAUDE.md`'s
  reviewed-change rule (a silent landing here would be the exact failure mode
  the guideline warns against).
- **Latency movement (real LFE corpus, slice6 path):** same-process A/B over
  510 forms across 13 reference `.lfe` files, Σ per-form `format_binary`,
  best-of-5: width 60 ≈ +6.6%, width 80 ≈ −1.3%, width 100 ≈ +0.6%. The larger
  limit explores more layouts (the `O(n·W⁴)` factor), but the real corpus shows
  no pathological tail — movement stays within run-to-run noise (±~7%). The
  worst case remains the synthetic stress/guard rows, which pin `limit`
  explicitly and are unaffected.
- **Re-entry trigger:** If a future corpus expansion or larger default width
  surfaces a guard_SUITE / stress-row tail blowup, revisit whether the default
  should clamp `limit` for very large `W`.

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

## Slice 9: Declarative LFE Rule Registry

### A1-R019: Data-file format is Erlang terms (`file:consult`), not s-expr

- **Status:** addressed (operator decision 2026-06-24)
- **Source:** Slice9 cc-prompt + slice-doc open question on data-file syntax.
- **Concern:** The slice-doc recommended an s-expr `priv/lfe-format-rules.lfe`
  read via `lfe_io`, on the premise that `lfe` is already a dependency. It is
  not — `lfe` is **test-only** in `rebar.config`, and `src/` is deliberately
  dependency-free. An `lfe_io` loader in the production `pe_lfe` would promote
  `lfe` to a production dep and break default-profile `xref`/`dialyzer`.
- **Decision:** Use Erlang terms via `file:consult` —
  `priv/lfe-format-rules.eterm`, `{rule, "defun", define, []}` rows. Zero new
  deps; `src/` stays dependency-free. The rule *content* is unchanged (form →
  tag → params; string names; closed atom tag set).
- **Re-entry trigger:** If a future slice promotes `lfe` to a production
  dependency for other reasons (e.g. an in-tree `.lfe` source reader), the rules
  file could move to s-expr to read like its `lfe-indent.el` ancestor.

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
