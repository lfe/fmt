# CC prompt - fmt v0.1.0 - arc1-poc / slice3-lfe-knowledge-layer

You are CC. Continue the BEAM-native PrettyExpressive PoC from
`arc1-poc / slice2-render-real-lfe`.

Slice1 proved the resolver substrate. Slice2 added rendering, a small facade,
and 20 real-LFE-shaped fixtures. Slice3 adds the first **LFE knowledge layer**:
a typed term vocabulary plus form-aware lowering into the existing engine.

Target OTP 28. Keep this as a PoC slice, but make the code production-shaped:
small exported surfaces, specs on exported functions, no dynamic atom creation
from source-like input, and a reproducible `rebar3` verification floor.

## Read first

- `docs/planning/v0.1.0/pretty-expressive-port-plan.md`
- `docs/planning/v0.1.0/arc1-poc/running-recommendations.md`
- `docs/planning/v0.1.0/arc1-poc/slice1-resolver/cc-prompt.md`
- `docs/planning/v0.1.0/arc1-poc/slice1-resolver/ledger.md`
- `docs/planning/v0.1.0/arc1-poc/slice1-resolver/cdc-verification.md`
- `docs/planning/v0.1.0/arc1-poc/slice2-render-real-lfe/slice-doc.md`
- `docs/planning/v0.1.0/arc1-poc/slice2-render-real-lfe/ledger.md`
- This slice's `slice-doc.md` and `ledger.md`

Load **collaboration-framework** for ledger discipline. Load
**erlang-guidelines** for Erlang/OTP idioms: `11-anti-patterns` first, then
`02-api-design`, `04-data-and-types`, `05-functions-and-pattern-matching`,
`10-performance`, `15-testing`, and `17-tooling` as needed. The project
toolchain in `rebar.config` wins over generic defaults.

## Slice focus

Implement only what is needed to answer:

> Can a reusable LFE knowledge layer improve the 20 real-LFE sample layouts
> while preserving the promising resolver/rendering performance signal?

Do **not** implement an LFE parser. Do **not** preserve comments or source
spans. Do **not** try to cover all LFE forms. Route the existing 20 samples
through a form-aware knowledge layer and produce evidence.

## Required module: `pe_lfe`

Create a source module for LFE-specific lowering. It may be a single module for
this slice; introduce a private companion only if it removes real complexity.

Required public surface:

```erlang
-type form() :: ... .

-spec to_doc(form()) -> pe_doc:dag().
-spec to_doc(form(), map()) -> pe_doc:dag().
-spec format(form(), map()) ->
    {iolist(), pe_measure:measure(), pe_resolve:stats()}.
-spec format_binary(form(), map()) ->
    {binary(), pe_measure:measure(), pe_resolve:stats()}.
```

Suggested term vocabulary:

```erlang
{sym, binary()}
{str, binary()}
{int, integer()}
{quote, Form}
{bquote, Form}
{unquote, Form}
{list, [Form]}
{dotted_list, [Form], Tail}
{tuple, [Form]}
{call, [Form]}
```

You may refine names if a better Erlang shape emerges, but keep the important
properties:

- source-like symbols are binaries;
- no `list_to_atom/1` or `binary_to_atom/1` for source symbols;
- exported types and specs are dialyzer-friendly;
- invalid internal term shapes may crash during lowering, but public
  convenience helpers should have clear contracts.

## Knowledge rules

Choose a layout rule by matching the binary symbol at the head of `{call, ...}`.
Generic S-expression layout is the fallback.

Implement form-aware rules for the forms present in the 20-sample corpus:

- `defun`
- `defmacro`
- clause shapes used by function/macro definitions
- `lambda`
- `match-lambda`
- `let`-family shapes represented by the samples
- `case`
- `receive`, including represented `after` shape if present
- `cond`
- `progn`
- `eval-when-compile`
- quote/backquote/unquote prefix forms
- proper lists, dotted lists, tuples, and generic calls

Prefer aligned/nested block shapes that are natural for Lisp:

- top-level-ish block bodies should break vertically;
- clauses should nest bodies by a small stable indent;
- long generic calls may align arguments, but special forms should not drift
  deeply rightward just because the head is long;
- `eval-when-compile` should format its body like a block, so nested `defun`
  starts near block indentation.

Do not change resolver semantics unless a test exposes an actual engine bug.

## Migrate `pe_lfe_samples`

Keep the sample IDs, labels, source references, and tags stable. Replace the
fixture-only document spec payload with LFE `pe_lfe:form()` terms, then make:

```erlang
pe_lfe_samples:build(Sample) -> pe_lfe:to_doc(pe_lfe_samples:form(Sample)).
```

Add:

```erlang
-spec form(sample()) -> pe_lfe:form().
```

if useful for tests and benchmarks.

The old helper vocabulary in `pe_lfe_samples` was a slice2 fixture interpreter.
Do not leave two competing knowledge layers behind. If a helper belongs to the
new knowledge layer, move it into `pe_lfe` or keep it private there. If a helper
is only sample sugar, keep it small and ensure it produces `pe_lfe:form()`, not
`pe_doc` nodes.

## Tests

EUnit:

- `pe_lfe_tests`: term lowering and public facade behavior.
- tests proving source symbols are represented as binaries and no dynamic atom
  conversion is used in the knowledge layer.
- exact or targeted golden assertions for:
  - Ackermann at width 80;
  - `eval-when-compile` containing `defun bq-expand`;
  - at least one `case`;
  - at least one `receive`;
  - at least one `cond`;
  - at least one `let`.
- `pe_lfe_samples_tests`: preserve 20 ids, metadata, deterministic rendering,
  and successful rendering at widths 80 and 100.

Optional but useful:

- structural max-indent checks for `lfe_07_bq_expand`;
- a few width 60 canaries;
- a small property that lowering any generated simple `form()` either produces
  a DAG or fails with a known internal bad-shape crash. Do not add weak PropEr
  tests just to inflate the count.

## Benchmark

Add a slice3 benchmark artifact without erasing slice2's baseline:

```text
bench/results/lfe_knowledge.csv
```

Use the same core columns:

```text
id,label,width,time_us,memo_size,calls,tainted,badness,height,bytes,lines
```

Run all 20 samples at widths 80 and 100. Add width 60 if it stays cheap. The
bench command may be:

```bash
escript bench/pe_bench lfe-knowledge
```

or another clearly documented mode. Keep the slice1 default sweep intact.

If you touch the benchmark runner, harden worker timing with `spawn_monitor`
or equivalent so crashes do not hang the parent. If you touch CSV field
writing, add minimal CSV escaping for binary fields.

Do not draw the final viability conclusion. Emit numbers and name caveats.

## Engineering bar

- `rebar3 compile` zero warnings.
- `rebar3 eunit` green.
- `rebar3 ct` green if CT is used.
- `rebar3 proper` green if PropEr is added or already present.
- `rebar3 xref` clean.
- `rebar3 dialyzer` clean.
- Slice3 benchmark command writes `bench/results/lfe_knowledge.csv`.

Run build-tool commands serially when they share `_build`; parallel `rebar3`
commands can race and produce misleading failures.

## Working ledger

Update `ledger.md` as you work. Every row must end as `done`, `deferred`, or
`no-op`; `done` needs command output evidence. If you amend scope, record the
amendment explicitly. Do not silently replace the slice goal with whatever was
easy to implement.

## When done

Hand back:

- `pe_lfe` source and tests;
- migrated 20-sample corpus;
- key rendered examples, especially Ackermann and `lfe_07_bq_expand`;
- benchmark stdout and committed `bench/results/lfe_knowledge.csv`;
- green verification floor;
- per-row ledger walk;
- caveats and deferrals.
