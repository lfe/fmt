# Slice 2: render + real-LFE viability samples

> Arc: `arc1-poc`
> Slice: `slice2-render-real-lfe`
> Status: planned for CC
> Prior slice: `slice1-resolver`

## Purpose

Slice1 proved the cost/measure-level resolver core: explicit DAG sharing, memo
backends, oracle equivalence, and synthetic benchmark output. Slice2 answers the
next viability question: once we render a chosen layout and feed the engine
documents shaped like real LFE code, does the Πe approach still look useful for
an LFE formatter?

This slice is deliberately **not** the LFE knowledge layer. It does not parse
LFE source and it does not implement general per-form formatting rules. Instead,
it adds the renderer/public facade the engine needs, plus a curated corpus of
20 real-LFE-shaped fixtures built by hand from `~/lab/lfe/lfe/examples`. Those
fixtures should be enough to expose the important S-expression risk: deeply
nested lists, many alternatives, pattern-matching function heads, macros,
records, bit syntax, receive/try/case, and process/OTP forms.

## Scope

In scope:

- `pe_render`: render a choiceless document carried in `pe_measure:doc/1` to an
  `iolist()` / binary with correct indentation semantics.
- `pe`: a small public facade around `pe_resolve` + `pe_render`, using
  `pe_memo_map` as the default memo backend.
- A test-only `pe_lfe_samples` fixture module containing 20 hand-built document
  builders, one per selected LFE form.
- A benchmark harness for the 20 fixtures at widths 80 and 100, reporting
  timing, memo/call/taint stats, rendered bytes/lines, and a per-sample summary.
- Tests that pin renderer semantics, facade behavior, and sample rendering
  stability.

Out of scope:

- Parsing `.lfe` files.
- A general LFE formatter map / knowledge layer.
- Comments-preserving source transformation.
- OTP 22-29 backport.
- Coverage gate and whole-repo CAP audit.

## Selected Real-LFE Fixture Corpus

The corpus is chosen to cover form shapes that matter for formatter viability,
not to be statistically representative of all LFE code. The source form should
be preserved in the fixture metadata as a label/reference, while the actual
engine input is a hand-built `pe_doc` document.

| ID | Source | Form | Why it matters |
|----|--------|------|----------------|
| LFE-01 | synthetic, based on Duncan's prompt | `ackermann/2` | Multi-clause `defun` with pattern-matching heads and nested recursive call. |
| LFE-02 | `examples/fizzbuzz.lfe:53` | `fizz/3` | Compact multi-clause pattern matching with strings and bare variables. |
| LFE-03 | `examples/fizzbuzz.lfe:72` | `buzz1/1` | Guarded function head plus long comment-adjacent body shape. |
| LFE-04 | `examples/fizzbuzz.lfe:116` | `tail-buzz/2` | Tail-recursive list pattern, nested call, good medium-size body. |
| LFE-05 | `examples/core-macros.lfe:55` | `++` macro | Many macro clauses with quasiquote/unquote and dotted rest syntax. |
| LFE-06 | `examples/core-macros.lfe:100` | `cond` macro | Macro clauses that expand into nested `case`/`if`; stresses alternatives. |
| LFE-07 | `examples/core-macros.lfe:125` | `backquote` + `bq-expand` | Large nested `eval-when-compile`, `fletrec`, `case`, tuple/list patterns. |
| LFE-08 | `examples/ets-demo.lfe:50` | `new/0` | Record construction, quoted data table, `lists:foreach`, `match-lambda`. |
| LFE-09 | `examples/ets-demo.lfe:86` | `by_place_ms/2` | `match-spec` with record match and guard. |
| LFE-10 | `examples/mnesia-demo.lfe:50` | `new/0` | Backquote table attributes, transaction lambda, records, larger data list. |
| LFE-11 | `examples/guessing-game2.lfe:61` | `guess-server/1` | `receive` with guarded record matches and recursive loop. |
| LFE-12 | `examples/ping-pong.lfe:73` | `gen_server` callbacks | OTP callback cluster, backquoted return tuples, record accessor/update. |
| LFE-13 | `examples/http-async.lfe:124` | `get-page/1` | Async `httpc:request`, `receive` result/error branches. |
| LFE-14 | `examples/object-via-closure.lfe:92` | `fish-class/3` | Closure object style, nested lambdas, `case`, backquoted property list. |
| LFE-15 | `examples/object-via-process.lfe:88` | `fish-class/3` | Process loop with receive, backquoted message patterns, state recursion. |
| LFE-16 | `examples/internal-state.lfe:112` | `account-class/3` | Stateful receive loop with `cond`, message patterns, update recursion. |
| LFE-17 | `examples/lfe-eval.lfe:109` | `eval-expr/2` | Large central evaluator `case`; many special-form branches. |
| LFE-18 | `examples/lfe-eval.lfe:227` | `parse-bitspecs/3` | Let/flet/case nesting plus tuple construction; bit-spec domain. |
| LFE-19 | `examples/lfe-eval.lfe:337` | `eval-lambda/2` | Long arity dispatch; exposes vertical vs compact clause layout pressure. |
| LFE-20 | `examples/lfe-eval.lfe:569` | `eval-receive/2` + helpers | `fletrec`, receive with `after`, queue merge; realistic hard S-expression. |

## Success Criteria

- Rendering is semantically correct for `text`, `nl`, `concat`, `nest`, and
  `align` on choiceless documents.
- The facade can render a resolved document to an `iolist()` or binary with
  deterministic output.
- The 20 fixture documents all render successfully at widths 80 and 100.
- The sample benchmark emits a reproducible CSV and stdout table with enough
  data for CDC/operator analysis.
- The benchmark does not draw the conclusion for the operator; it produces
  numbers and flags obvious pathological cases.

## Design Notes

Use the slice1 engine as-is. Do not change resolver semantics unless a renderer
test exposes a genuine bug. Prefer `pe_memo_map` as the default backend because
slice1 data favored it at this scale and because it is the pure reference path.

The fixture module may use helper combinators to make hand-built S-expression
documents readable: `list/2`, `form/3`, `atom/2`, `string/2`, `tuple/2`,
`clauses/2`, etc. Keep those helpers test-only unless they are obviously
engine-generic. This is a viability fixture corpus, not the final public LFE
formatter API.

Measure with monotonic time, not wall-clock system time. For timing fairness,
run enough repeats to reduce noise and run samples in fresh processes where it
is cheap to do so. Still report raw numbers, not a backend/algorithm verdict.

## Handoff

When complete, CC should provide:

- The renderer/facade modules.
- The 20-sample fixture module and tests.
- Benchmark stdout plus committed CSV under `bench/results/`.
- A per-row ledger walk with command output.
- A short caveat section naming any sample that is too slow, all-tainted, or
  structurally awkward to model by hand.
