# Slice 4: Pathological stress corpus

> Arc: `arc1-poc`
> Slice: `slice4-pathological-stress-corpus`
> Status: planned for CC
> Prior slice: `slice3-lfe-knowledge-layer`

## Purpose

Slices 1 through 3 produced an encouraging signal: the Erlang resolver,
renderer, facade, and first LFE knowledge layer all handle the current
real-LFE-shaped corpus without hitting the scary all-tainted path. That is good
news, but it is not yet the evidence we need for a Lisp formatter. Lisp syntax
can naturally produce long, nested, mostly-homogeneous S-expressions, and those
are exactly the shapes that could turn PrettyExpressive's theoretical worst
cases into practical trouble.

Slice4 deliberately goes looking for trouble.

The goal is not to improve visual quality, add parser integration, or make a
final feasibility call. The goal is to add a deterministic stress corpus and
benchmark mode that pressure the known risks: very narrow widths, long proper
and improper lists, deeply nested quote/backquote structures, generic
S-expressions without special-form help, block-valued arguments, local function
bindings, and forced no-fit rows. The output should tell us whether the
algorithmic risk remains mostly theoretical at useful sizes, or whether LFE
formatting needs a different strategy before this PoC grows further.

This slice should answer:

> What happens when the current Erlang PrettyExpressive implementation is fed
> deliberately pathological LFE/S-expression shapes, including cases designed to
> produce tainted or no-fit layouts?

## Scope

In scope:

- A test-only stress corpus module with stable IDs, labels, categories, sizes,
  and deterministic construction.
- Stress cases built through `pe_lfe:form()` and, where useful, directly through
  `pe_doc` to isolate engine behavior from LFE knowledge-layer behavior.
- A benchmark mode that resolves and renders the stress corpus at narrow and
  normal widths.
- Explicit timeout/error handling so runaway cases produce CSV rows instead of
  hanging the benchmark.
- Stable structural counters in the CSV: resolver calls, memo size, tainted
  count, badness, height, output bytes/lines, DAG size, and status.
- A committed sample CSV for the stress run.
- Tests that prove the corpus is stable, the benchmark row shape is stable, and
  representative bounded stress cases render successfully.

Out of scope:

- Resolver semantic changes.
- LFE visual-quality refinements for the residual slice3 awkward cases.
- Parser-derived samples.
- Source fidelity, comments, or source-span preservation.
- Unicode display-width policy.
- OTP 22-29 backport.
- Coverage gate and whole-repo CAP audit.

## Stress Families

The corpus should include enough cases to distinguish "real workload pressure"
from one synthetic corner. Suggested families:

1. **Long proper lists.** Lists with many atoms/items, including sizes large
   enough to force vertical layout at narrow widths.
2. **Long improper/dotted lists.** Dotted lists with many prefixes and a tail,
   since Lisp formatters must not assume only proper lists.
3. **Long generic calls.** Calls with many arguments where no special-form rule
   applies, so generic S-expression fallback is the strategy under test.
4. **Deep generic S-expressions.** Nested call/list structures that grow
   depth-first and repeatedly present flat-vs-broken alternatives.
5. **Shared-subtree stress.** At least one workload inspired by the paper's
   shared-DAG examples, so memoization pressure is visible separately from
   source-tree size.
6. **Quote/backquote towers.** Nested quote, backquote, and unquote structures
   with both data and calls inside.
7. **Long binding lists.** `let`/`let*`/`flet`/`fletrec`-shaped forms with many
   bindings and bodies.
8. **Deep clause forms.** Nested `case`, `receive`, `cond`, and function clauses
   with enough alternatives to pressure block layout.
9. **Block-valued call arguments.** Known slice3 awkward shapes such as
   `lists:foreach` receiving `match-lambda`, `lambda`, `case`, or `receive`
   as an argument.
10. **Forced no-fit rows.** Rows containing text wider than the configured
    width/limit, and/or very narrow widths, so the benchmark intentionally
    observes non-zero badness and tainted behavior.

The corpus does not need hundreds of cases. It should be broad and explicit:
roughly 20 to 40 stress cases is enough if the cases are parameterized by
category and size.

## Benchmarking

Add a new benchmark artifact:

```text
bench/results/lfe_stress.csv
```

The command may be:

```bash
escript bench/pe_bench lfe-stress
```

or another clearly documented mode. Keep the existing slice1, slice2, and
slice3 benchmark modes intact.

Recommended CSV columns:

```text
id,label,category,size,width,limit,status,time_us,memo_size,calls,tainted,badness,height,bytes,lines,dag_size
```

Where:

- `status` is `ok`, `timeout`, or `error`.
- `time_us` is illustrative and may be blank or `0` for timeout/error rows.
- `badness`, `tainted`, `calls`, and `memo_size` are the primary viability
  signal.
- `dag_size` should be a deterministic structural count of the document DAG or
  lowered form/doc size. It does not have to be perfect, but the definition
  should be stable and documented in code or tests.

Use a width matrix that includes both normal and aggressive widths. Suggested
widths:

```text
20,40,60,80,100
```

If a special forced no-fit family needs different widths or limits, include
those rows explicitly and label the category clearly.

The benchmark must run each row in a monitored worker with a timeout. The
timeout should be configurable or at least centralized. A default around 5
seconds per row is reasonable for a PoC stress run, but CC may adjust it if the
implementation evidence supports the change. A timeout is a valid result: record
it in the CSV and continue.

## Tests

At minimum:

- corpus count and stable ID/category tests;
- deterministic build tests for all stress samples;
- representative render tests for each stress family at bounded sizes;
- CSV header and row-shape tests for the stress benchmark;
- timeout/error-path tests for the benchmark worker if practical;
- a regression test or canary proving at least one forced no-fit row produces
  non-zero badness, unless the implementation exposes a better explicit signal.

The test suite should not run the full pathological matrix if that would make
normal `rebar3 eunit` slow or flaky. Keep the heaviest combinations in the
benchmark command, not the ordinary unit floor.

## Success Criteria

- Stress corpus module exists and is test-only or otherwise clearly separated
  from the engine/public formatter surface.
- Corpus includes the required stress families with stable metadata.
- Benchmark writes `bench/results/lfe_stress.csv` without overwriting previous
  benchmark artifacts.
- Benchmark rows cannot hang the parent process; timeout/error cases are
  reported and the run continues.
- At least one forced no-fit or mostly-tainted scenario is represented in the
  committed CSV.
- Normal verification floor remains green: compile, eunit, CT if present,
  PropEr if present, xref, and dialyzer.
- Closing report summarizes worst rows by calls, memo size, tainted count,
  badness, and timeout/error status without drawing the final feasibility
  verdict.

## Handoff

When complete, CC should provide:

- the stress corpus module and tests;
- the benchmark command and committed `bench/results/lfe_stress.csv`;
- a short explanation of each stress family and why it was included;
- a table or summary of worst rows by stable structural counters;
- explicit notes on whether forced no-fit/all-tainted-like scenarios were hit;
- the green verification floor;
- a per-row ledger walk with command-output evidence;
- caveats and deferrals.
