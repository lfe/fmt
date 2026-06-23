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

- **Status:** open
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

- **Status:** open
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

- **Status:** open
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
- **Re-entry trigger:** Next knowledge-layer refinement slice, especially before
  judging visual quality on higher-order calls.

### A1-R014: Give `flet`/`fletrec` function bindings clause-like layout

- **Status:** open
- **Source:** Slice3 CDC verification of `lfe_20_eval_receive`.
- **Concern:** `fletrec` itself is recognized, but its function-definition
  binding still formats through generic list layout. The result separates the
  function name, arg list, and body in a way that is mechanically valid but not
  yet the natural LFE shape for local function definitions.
- **Recommendation:** Teach the knowledge layer a binding-shape rule for
  `flet`/`fletrec`: bindings of the form `(name (args...) body...)` should lower
  through the same clause/body machinery used by `defun`-style forms, with the
  body nested under the local function head.
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
