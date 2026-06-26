# CC prompt - fmt v0.5.0 - arc1-poc / slice4-pathological-stress-corpus

You are CC. Continue the BEAM-native PrettyExpressive PoC from
`arc1-poc / slice3-lfe-knowledge-layer`.

Slice1 proved the resolver substrate. Slice2 added rendering, a facade, and 20
real-LFE-shaped samples. Slice3 added the first LFE knowledge layer. Slice4 is a
measurement slice: build a deterministic pathological stress corpus and
benchmark mode that pressure the known S-expression and all-tainted risks.

Target OTP 28. Keep this as a PoC slice, but make the code production-shaped:
small surfaces, specs on exported functions, deterministic fixtures, explicit
timeouts for pathological runs, and a reproducible `rebar3` verification floor.

## Read first

- `docs/planning/v0.5.0/pretty-expressive-port-plan.md`
- `docs/planning/v0.5.0/arc1-poc/running-recommendations.md`
- `docs/planning/v0.5.0/arc1-poc/slice1-resolver/cc-prompt.md`
- `docs/planning/v0.5.0/arc1-poc/slice1-resolver/ledger.md`
- `docs/planning/v0.5.0/arc1-poc/slice1-resolver/cdc-verification.md`
- `docs/planning/v0.5.0/arc1-poc/slice2-render-real-lfe/slice-doc.md`
- `docs/planning/v0.5.0/arc1-poc/slice2-render-real-lfe/ledger.md`
- `docs/planning/v0.5.0/arc1-poc/slice3-lfe-knowledge-layer/slice-doc.md`
- `docs/planning/v0.5.0/arc1-poc/slice3-lfe-knowledge-layer/ledger.md`
- This slice's `slice-doc.md` and `ledger.md`

Load **collaboration-framework** for ledger discipline. Load
**erlang-guidelines** for Erlang/OTP idioms: `11-anti-patterns` first, then
`04-data-and-types`, `05-functions-and-pattern-matching`, `10-performance`,
`15-testing`, and `17-tooling` as needed. The project toolchain in
`rebar.config` wins over generic defaults.

## Slice focus

Implement only what is needed to answer:

> What happens when the current Erlang PrettyExpressive implementation is fed
> deliberately pathological LFE/S-expression shapes, including cases designed to
> produce tainted or no-fit layouts?

Do not refine LFE visual quality in this slice unless a tiny helper is required
to construct the stress corpus. Do not implement a parser. Do not change
resolver semantics. Do not draw the final project-viability conclusion. Produce
evidence.

## Required corpus

Add a stress corpus module. A test-only module is preferred unless a source
module is clearly justified. The module should expose stable metadata and a way
to build the stress input.

Suggested surface:

```erlang
-type sample() :: ... .

-spec all() -> [sample()].
-spec by_id(binary()) -> sample().
-spec id(sample()) -> binary().
-spec label(sample()) -> binary().
-spec category(sample()) -> binary().
-spec size(sample()) -> non_neg_integer().
-spec build(sample()) -> pe_doc:dag().
```

If you build through `pe_lfe:form()`, also expose `form/1` where useful. If a
case must isolate engine behavior and is clearer as direct `pe_doc`, that is
acceptable, but label it clearly and keep the public distinction obvious.

Required stress families:

- long proper lists;
- long improper/dotted lists;
- long generic calls with no special-form rule;
- deep generic S-expressions;
- at least one shared-subtree or shared-DAG stress case;
- quote/backquote/unquote towers;
- long `let`/`let*`/`flet`/`fletrec` binding lists;
- nested `case`/`receive`/`cond` or clause-like forms;
- block-valued call arguments, including a `match-lambda`/`lambda`-as-argument
  style case related to the slice3 `lfe_08` caveat;
- forced no-fit rows, such as text wider than the configured width/limit or a
  deliberately tiny width.

Aim for roughly 20 to 40 stress samples. Prefer a small, well-labelled corpus
over a giant unreviewable matrix.

## Benchmark mode

Add a stress benchmark mode without erasing previous artifacts:

```bash
escript bench/pe_bench lfe-stress
```

or a similarly explicit command. It should write:

```text
bench/results/lfe_stress.csv
```

Recommended CSV header:

```text
id,label,category,size,width,limit,status,time_us,memo_size,calls,tainted,badness,height,bytes,lines,dag_size
```

Run the corpus at widths:

```text
20,40,60,80,100
```

If some cases need a custom width/limit to force no-fit behavior, add those rows
explicitly and label them through `category` or `id`.

The benchmark must run each sample/width row in a monitored worker with a
timeout. Do not let a pathological input wedge the parent process. On timeout or
worker crash:

- write a row with `status=timeout` or `status=error`;
- preserve whatever stable fields are available;
- continue with the remaining rows;
- include enough stdout detail to identify the failed row.

Keep timing methodology consistent with prior slices: fresh-process timing is
fine; timing columns are illustrative; stable counters are the main signal.

## Structural counters

Preserve the existing stable counters where possible:

- `memo_size`
- `calls`
- `tainted`
- `badness`
- `height`
- rendered `bytes`
- rendered `lines`

Add `dag_size` or a similarly named deterministic structural size. It may count
reachable document nodes, lowered form nodes, or another stable approximation.
Define it in code comments or tests so future comparisons know what it means.

If the current public API cannot expose an exact "all-tainted path was entered"
signal without engine churn, do not force an invasive instrumentation change.
Instead, include forced no-fit rows, report non-zero badness and tainted counts,
and explain the limits of that proxy in the closing report. A small stats-field
addition is acceptable only if it is obviously safe, tested, and does not change
resolver semantics.

## Tests

EUnit:

- stress corpus count, stable IDs, stable categories, and deterministic builds;
- representative bounded render tests for every stress family;
- at least one forced no-fit canary with non-zero badness, unless a better
  explicit signal is exposed;
- benchmark CSV header/row-shape tests;
- benchmark timeout/error behavior if practical.

Common Test / PropEr:

- Keep existing suites green.
- Add property tests only if they provide real value. Do not add weak PropEr
  tests just to increase the count.

Do not put the full heavy stress matrix in ordinary unit tests. Unit tests should
be fast and deterministic; the benchmark command is where the heavier matrix
belongs.

## Engineering bar

- `rebar3 compile` zero warnings.
- `rebar3 eunit` green.
- `rebar3 ct` green if CT is used.
- `rebar3 proper` green if PropEr is present or added.
- `rebar3 xref` clean.
- `rebar3 dialyzer` clean.
- Stress benchmark command writes `bench/results/lfe_stress.csv`.

Run build-tool commands serially when they share `_build`; parallel `rebar3`
commands can race and produce misleading failures.

## Working ledger

Update `ledger.md` as you work. Every row must end as `done`, `deferred`, or
`no-op`; `done` needs command output evidence. If you amend scope, record the
amendment explicitly. Do not silently replace the slice goal with a smaller,
easier benchmark.

## When done

Hand back:

- stress corpus module and tests;
- benchmark command and committed `bench/results/lfe_stress.csv`;
- a summary of corpus families and sample counts;
- worst rows by calls, memo size, tainted count, badness, and timeout/error;
- clear statement of whether forced no-fit/all-tainted-like cases were observed;
- green verification floor;
- per-row ledger walk;
- caveats and deferrals.
