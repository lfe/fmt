# CC prompt - fmt v0.5.0 - arc1-poc / slice5-lfe-layout-refinements

You are CC. Continue the BEAM-native PrettyExpressive PoC from
`arc1-poc / slice4-pathological-stress-corpus`.

Slice5 is a focused LFE usefulness slice. Slice4 showed the current engine can
survive the stress corpus at the tested sizes, so this slice should refine the
knowledge layer for the two known awkward LFE shapes and close one benchmark
harness concern.

Target OTP 28. Keep the code production-shaped: small helpers, specs on exported
functions, deterministic tests, no dynamic atom creation from source-like input,
and a reproducible `rebar3` verification floor.

## Read first

- `docs/planning/v0.5.0/pretty-expressive-port-plan.md`
- `docs/planning/v0.5.0/arc1-poc/running-recommendations.md`
- `docs/planning/v0.5.0/arc1-poc/slice3-lfe-knowledge-layer/slice-doc.md`
- `docs/planning/v0.5.0/arc1-poc/slice3-lfe-knowledge-layer/ledger.md`
- `docs/planning/v0.5.0/arc1-poc/slice4-pathological-stress-corpus/slice-doc.md`
- `docs/planning/v0.5.0/arc1-poc/slice4-pathological-stress-corpus/ledger.md`
- This slice's `slice-doc.md` and `ledger.md`

Load **collaboration-framework** for ledger discipline. Load
**erlang-guidelines** for Erlang/OTP idioms: `11-anti-patterns` first, then
`04-data-and-types`, `05-functions-and-pattern-matching`, `10-performance`,
`15-testing`, and `17-tooling` as needed. The project toolchain in
`rebar.config` wins over generic defaults.

## Slice focus

Implement only what is needed to answer:

> Can the LFE knowledge layer handle block-valued arguments and local function
> bindings naturally, while preserving the slice4 stress/benchmark safety
> signal?

Do not implement an LFE parser. Do not preserve comments/source spans. Do not
change resolver semantics. Do not broaden the stress corpus unless a tiny case
is needed to pin the refined behavior.

## Required layout refinements

### 1. Block-valued call arguments

Refine generic call layout so a known block form used as an argument can break
as a local block instead of aligning under the generic argument column.

Target forms:

- `lambda`
- `match-lambda`
- `case`
- `receive`
- `cond`

You may include other already-known block forms if the helper naturally supports
them and tests stay focused.

Important constraints:

- Ordinary generic calls should still use generic S-expression fallback.
- A known block form in top-level or body position should keep its current block
  behavior.
- The improvement should be context-sensitive: the same `pe_lfe:form()` term can
  render differently when it is a block-valued argument than when it is an
  ordinary body form, if that is what produces natural LFE layout.
- Avoid a giant special-case per sample. Prefer a small helper such as
  `block_arg_form/1`, `block_valued/1`, or an equivalent local abstraction.

Primary sample target:

- `lfe_08_ets_new`

Stress targets:

- `block_arg_match_lambda`
- `block_arg_lambda`
- `block_arg_case`
- `block_arg_receive`

### 2. `flet`/`fletrec` local function bindings

Refine `flet` and `fletrec` binding layout. Function bindings shaped like:

```lisp
(name (args...) body...)
```

should lower through clause-like machinery:

```lisp
(fletrec
  ((loop (q)
     (receive
       ...)))
  (loop ()))
```

Important constraints:

- Preserve safe fallback for non-function binding shapes.
- Keep `let` and `let*` ordinary value bindings readable; do not accidentally
  treat every binding list as a function binding.
- Reuse or factor existing clause/body helpers if that keeps the implementation
  clear.

Primary sample target:

- `lfe_20_eval_receive`

Stress target:

- `fletrec_bindings_12`

### 3. Stress benchmark timeout boundary

In slice4, `stress_row/3` computed `dag_size` before entering the monitored
worker. Move all potentially-expensive row work inside the timeout boundary:

- document construction;
- `dag_size`;
- resolve;
- render;
- metric extraction.

Timeout/error rows may use `dag_size = 0` if construction never completed. The
important property is that a pathological sample cannot wedge the parent before
the monitored worker starts.

Add a targeted test if practical. If exact testing would require ugly test-only
hooks, document the limitation in the ledger and prove the code path by review.

## Benchmark evidence

Do not overwrite slice3 or slice4 CSV artifacts as if they were the same data.
Add a new slice5 artifact, for example:

```text
bench/results/lfe_refined.csv
```

Add a clear command such as:

```bash
escript bench/pe_bench lfe-refined
```

Recommended rows:

- all 20 real LFE samples at widths 60, 80, 100;
- either all 25 stress samples at widths 20, 40, 60, 80, 100, or a clearly
  labeled affected subset containing the block-argument and `fletrec` stress
  samples.

If you choose a subset, say why in the ledger. Preserve the existing
`lfe-knowledge` and `lfe-stress` modes.

Stable counters are the signal: `memo_size`, `calls`, `tainted`, `badness`,
`height`, bytes/lines, and `dag_size` where available. Timing is illustrative.

## Tests

EUnit:

- golden or targeted layout assertions for `lfe_08_ets_new`;
- golden or targeted layout assertions for `lfe_20_eval_receive`;
- focused block-valued argument tests for `lambda`, `match-lambda`, `case`,
  `receive`, and `cond` when used as call arguments;
- focused `flet`/`fletrec` function-binding tests;
- fallback tests showing ordinary generic calls and non-function bindings remain
  stable;
- stress benchmark timeout-boundary test or explicit code-review evidence;
- refined benchmark CSV header/row-shape tests if adding a new benchmark mode.

Common Test / PropEr:

- Keep existing suites green.
- Add property tests only if they check a meaningful invariant.

Avoid over-broad byte goldens that will make harmless whitespace improvements
painful later. Prefer assertions about key lines, max indentation, relative
indentation, and absence of the previously-bad rightward drift.

## Engineering bar

- `rebar3 compile` zero warnings.
- `rebar3 eunit` green.
- `rebar3 ct` green if CT is used.
- `rebar3 proper` green if PropEr is present or added.
- `rebar3 xref` clean.
- `rebar3 dialyzer` clean.
- Refined benchmark command writes the slice5 CSV artifact.

Run build-tool commands serially when they share `_build`; parallel `rebar3`
commands can race and produce misleading failures.

## Working ledger

Update `ledger.md` as you work. Every row must end as `done`, `deferred`, or
`no-op`; `done` needs command-output evidence. If you amend scope, record the
amendment explicitly.

Do not silently turn this into a parser slice or a broad formatter rewrite.

## When done

Hand back:

- summary of `pe_lfe` changes;
- rendered examples for `lfe_08_ets_new` and `lfe_20_eval_receive`;
- refined benchmark command and committed CSV;
- green verification floor;
- per-row ledger walk;
- caveats and deferrals.
