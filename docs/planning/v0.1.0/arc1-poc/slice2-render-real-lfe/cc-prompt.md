# CC prompt - fmt v0.1.0 · arc1-poc / slice2-render-real-lfe

You are CC. Continue the BEAM-native Πe (`PrettyExpressive`) PoC from
`arc1-poc / slice1-resolver`. Slice1 closed the resolver core at the
cost/measure level. This slice adds **rendering**, a small **public facade**,
and a **20-form real-LFE-shaped fixture corpus** so CDC/operator can judge
whether the algorithm still looks viable for LFE formatting.

Target OTP 28. Keep the implementation lean and direct. This is still a PoC,
not the final LFE formatter.

## Read first

- `docs/planning/v0.1.0/pretty-expressive-port-plan.md` - especially §2, §3,
  and §5.
- `docs/planning/v0.1.0/arc1-poc/slice1-resolver/cc-prompt.md`.
- `docs/planning/v0.1.0/arc1-poc/slice1-resolver/ledger.md`.
- `docs/planning/v0.1.0/arc1-poc/slice1-resolver/cdc-verification.md`.
- This slice's `slice-doc.md` and `ledger.md`.

Load **collaboration-framework** (ledger discipline) and **erlang-guidelines**
(`11-anti-patterns` first, then `01-core-idioms`, `02-api-design`,
`04-data-and-types`, `05-functions-and-pattern-matching`, `10-performance`,
`15-testing`, `17-tooling`). Validate at the edge, crash in the interior;
tagged returns on public surfaces; `-spec` on every exported function.

## Slice focus

Implement only what is needed to answer:

> With rendering included, and with inputs shaped like real LFE forms, does
> this Erlang Πe engine still look feasible enough to continue toward an LFE
> formatter?

Do **not** implement an LFE parser or a general knowledge layer. Build the
sample documents by hand from the 20 selected forms in `slice-doc.md`.

## Modules / surfaces

### `pe_render`

Render the choiceless document carried by `pe_measure:doc/1`.

Required surface:

```erlang
-spec render(pe_measure:cdoc()) -> iolist().
-spec render_binary(pe_measure:cdoc()) -> binary().
```

Semantics:

- `{text, Bin}` appends `Bin`.
- `nl` emits `$\n` plus the current indentation spaces.
- `{concat, A, B}` renders A then B.
- `{nest, N, D}` renders D with indentation increased by `N`.
- `{align, D}` renders D with indentation set to the current column.

Track column and indentation separately. This is the same subtlety as the
resolver: `align` sets indentation to the current column; `nest` is relative.
Render as an iolist; do not repeatedly flatten binaries in the hot path.

### `pe`

Small public facade:

```erlang
-spec resolve(pe_doc:dag(), pe_resolve:opts()) ->
    {pe_measure:measure(), pe_resolve:stats()}.
-spec format(pe_doc:dag(), map()) -> {iolist(), pe_measure:measure(), pe_resolve:stats()}.
-spec format_binary(pe_doc:dag(), map()) -> {binary(), pe_measure:measure(), pe_resolve:stats()}.
```

Defaults:

- `cost => pe_cost_squared`
- `memo => pe_memo_map`
- `width => 80`
- `limit => width`

The facade may accept the same keys as `pe_resolve:opts()`. Keep it small; this
is a convenience surface for tests and harnesses, not a final library API.

### `pe_lfe_samples` (test/support module)

A fixture module containing the selected 20 samples from `slice-doc.md`.

Required surface:

```erlang
-spec all() -> [sample()].
-spec by_id(atom()) -> sample().
-spec build(sample()) -> pe_doc:dag().
-spec id(sample()) -> atom().
-spec label(sample()) -> binary().
-spec source(sample()) -> binary().
```

Use a record or map internally, but expose a small accessor surface. Each sample
must carry:

- stable id (`lfe_01_ackermann`, etc.);
- source reference string;
- short label;
- category tags;
- a builder function that returns a frozen DAG.

The sample documents should be manually built to resemble the source forms'
layout choices. It is acceptable for expected output to be a canonicalized
version of the source, not byte-for-byte original source. The goal is engine
stress and rendering viability, not source preservation.

Suggested helper combinators inside `pe_lfe_samples`:

- `txt/2`, `atom/2`, `str/2`
- `sexp/3` for a parenthesized form with a head and children
- `block/3` for forms whose children should break vertically
- `clause/3` for `defun` / `match-lambda` clause shapes
- `quote/2`, `tuple/2`, `list/2`, as needed

Keep helper names plain and local; if a helper starts looking like the final LFE
knowledge layer, stop and keep it test-only.

### Benchmark harness

Add an escript or extend `bench/pe_bench` with a real-LFE sample mode. Keep the
slice1 synthetic sweep intact.

Required output columns for sample CSV:

```text
id,label,width,time_us,memo_size,calls,tainted,badness,height,bytes,lines
```

Run all 20 samples at widths `80` and `100`. Use the map backend by default.
Use `erlang:monotonic_time/1` (or `timer:tc`, which uses monotonic time on
modern OTP) for durations. Prefer fresh-process runs for each sample/repeat if
the harness remains simple. Emit stdout and write
`bench/results/lfe_samples.csv`.

Do not interpret the results. Flag obvious pathologies in the closing report,
but leave the viability conclusion to CDC/operator.

## Selected samples

Use exactly the 20 selected forms listed in `slice-doc.md`:

1. synthetic Ackermann `defun`
2. `fizzbuzz:fizz/3`
3. `fizzbuzz:buzz1/1`
4. `fizzbuzz:tail-buzz/2`
5. `core-macros:++`
6. `core-macros:cond`
7. `core-macros:backquote` / `bq-expand`
8. `ets-demo:new/0`
9. `ets-demo:by_place_ms/2`
10. `mnesia-demo:new/0`
11. `guessing-game2:guess-server/1`
12. `ping-pong` callback cluster
13. `http-async:get-page/1`
14. `object-via-closure:fish-class/3`
15. `object-via-process:fish-class/3`
16. `internal-state:account-class/3`
17. `lfe-eval:eval-expr/2`
18. `lfe-eval:parse-bitspecs/3`
19. `lfe-eval:eval-lambda/2`
20. `lfe-eval:eval-receive/2` plus helpers

## Tests

EUnit:

- `pe_render_tests`: each core rendering construct, including `align` vs
  `nest` cases where indentation differs.
- `pe_tests`: facade defaults and override options.
- `pe_lfe_samples_tests`: exactly 20 samples, stable ids, all build, all render
  at widths 80 and 100, output is non-empty and balanced enough for the
  canonical fixture expectation.

Common Test or EUnit:

- sample benchmark smoke test: runs a small subset and proves CSV columns are
  emitted.

Keep PropEr only if it adds a real invariant. Suggested optional property:
rendering a choiceless doc never crashes and returns an iolist/binary for
generated choiceless terms.

## Engineering bar

- `rebar3 compile` zero warnings.
- `rebar3 eunit` green.
- `rebar3 ct` green if CT is used.
- `rebar3 proper` green if PropEr is added for renderer properties.
- `rebar3 xref` clean.
- `rebar3 dialyzer` clean.
- `escript bench/pe_bench lfe` or equivalent writes
  `bench/results/lfe_samples.csv`.

## Working ledger

Update `ledger.md` as you work. Every row must reach `done`, `deferred`, or
`no-op`; `done` needs command output evidence. If you need to amend scope, raise
it explicitly rather than silently changing the target.

## When done

Hand back:

- renderer and facade;
- 20-sample fixture corpus;
- sample benchmark output and CSV;
- green verification floor;
- per-row ledger walk;
- caveats for any sample that taints heavily, renders awkwardly, or dominates
  runtime.

Do not draw the final viability conclusion. Produce the evidence.
