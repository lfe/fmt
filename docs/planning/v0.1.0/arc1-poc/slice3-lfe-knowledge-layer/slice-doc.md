# Slice 3: LFE knowledge layer

> Arc: `arc1-poc`
> Slice: `slice3-lfe-knowledge-layer`
> Status: planned for CC
> Prior slice: `slice2-render-real-lfe`

## Purpose

Slice2 proved that the Erlang PrettyExpressive engine can resolve and render
20 real-LFE-shaped forms quickly enough to keep investigating. It also exposed
the next useful truth: generic S-expression layout is not enough for LFE. The
awkward `lfe_07_bq_expand` output was not an engine failure; it was a knowledge
failure. A Lisp formatter needs form-aware choices.

Slice3 introduces the first LFE knowledge layer: a small, explicit LFE term
model plus form-aware lowering into `pe_doc`. The goal is not to parse `.lfe`
files or preserve comments. The goal is to prove that a reusable formatter-map
can express LFE conventions cleanly, improve the awkward slice2 shapes, and
still produce good resolver numbers over the same 20-form corpus.

This slice should answer:

> If the same 20 forms are routed through an actual LFE knowledge layer instead
> of a generic fixture-specific S-expression builder, do the layouts become more
> LFE-useful without hurting the engine viability signal?

## Scope

In scope:

- A production-shaped `pe_lfe` module that lowers LFE terms to `pe_doc` DAGs
  and offers convenience `format/2` / `format_binary/2` wrappers.
- A small LFE term vocabulary using binaries for symbols, so no atoms are
  minted from source-like input.
- Form-aware layout rules for the LFE forms represented in the 20-sample
  corpus.
- Migration of the 20 sample corpus so samples are LFE terms lowered through
  `pe_lfe`, not hand-built document specs.
- Golden or structural tests for the most important layouts: Ackermann,
  `eval-when-compile`, multi-clause functions/macros, clause bodies, and nested
  special forms.
- A slice3 benchmark artifact that preserves the slice2 baseline and emits new
  knowledge-layer numbers.
- Small harness hardening carried forward from the slice2 review where it is
  cheap and directly relevant.

Out of scope:

- Parsing `.lfe` source files.
- Comment preservation or source-span tracking.
- Full LFE grammar coverage.
- A final public formatter API.
- OTP 22-29 backport.
- Coverage gate and whole-repo CAP audit.
- The full pathological S-expression stress corpus from the running
  recommendations. Slice3 may add small canaries, but the full stress slice is
  separate.

## Design Shape

### Term model

Use a small explicit term model. Exact names may be refined during
implementation, but the contract should keep these properties:

- symbols are binaries, not dynamically-created atoms;
- strings are binaries;
- quote-like reader forms are explicit;
- proper, dotted, and tuple/list-ish forms are representable;
- call/special-form heads are inspectable without parsing text.

Suggested shape:

```erlang
-type form() ::
    {sym, binary()}
  | {str, binary()}
  | {int, integer()}
  | {quote, form()}
  | {bquote, form()}
  | {unquote, form()}
  | {list, [form()]}
  | {dotted_list, [form()], form()}
  | {tuple, [form()]}
  | {call, [form()]}.
```

It is acceptable to add narrow helper constructors in tests or samples, but the
exported surface should stay small and dialyzer-friendly.

### Required `pe_lfe` surface

```erlang
-spec to_doc(form()) -> pe_doc:dag().
-spec to_doc(form(), map()) -> pe_doc:dag().
-spec format(form(), map()) ->
    {iolist(), pe_measure:measure(), pe_resolve:stats()}.
-spec format_binary(form(), map()) ->
    {binary(), pe_measure:measure(), pe_resolve:stats()}.
```

`format/2` and `format_binary/2` should delegate to `pe:format/2` and
`pe:format_binary/2` after lowering. Resolver options should pass through; the
default backend remains `pe_memo_map` via the existing `pe` facade.

### Formatter map / rules

The knowledge layer should choose a rule by the symbolic head of a call form.
Generic S-expression formatting is the fallback, not the main strategy.

Rules required for this slice:

- `defun` and `defmacro`: name on the head line; clauses vertically nested.
- function/macro clauses: pattern head plus one or more body forms.
- `lambda` and `match-lambda`: argument or clause structure plus vertical body.
- `let`-family forms represented in the corpus: binding lists should be
  vertical-friendly and not drift under a generic call align.
- `case`: subject on the head line; clauses vertically nested.
- `receive`: message clauses vertically nested; support an `after` branch if
  represented by the sample corpus.
- `cond`: clauses vertically nested.
- `progn` and `eval-when-compile`: block bodies, so nested definitions start
  near the block indentation instead of far to the right.
- quote/backquote/unquote: prefix layout.
- tuples, proper lists, dotted lists, and generic calls as fallback.

The knowledge layer may reuse internal helper combinators inspired by
`pe_lfe_samples`, but those helpers should live in `pe_lfe` or a private
companion module, not remain duplicated in the sample module.

## Sample Corpus Migration

Keep the 20 sample IDs, labels, sources, and tags from slice2. Change the
sample payload from a fixture-specific document spec to an LFE `form()` term.
`pe_lfe_samples:build/1` should call `pe_lfe:to_doc/1`.

Add an accessor for the source term if useful:

```erlang
-spec form(sample()) -> pe_lfe:form().
```

The existing `all/0`, `by_id/1`, `build/1`, `id/1`, `label/1`, `source/1`, and
`tags/1` surface should remain stable unless there is a strong reason to
amend it.

## Layout Evidence

At minimum, tests should pin:

- Ackermann renders in the expected compact multi-clause shape at width 80.
- `eval-when-compile` containing `defun bq-expand` renders as a block, with the
  inner `defun` starting at block indentation rather than aligned as a generic
  second argument.
- `case`, `receive`, `cond`, and `let` sample shapes produce vertical,
  readable bodies.
- All 20 samples still render deterministically at widths 80 and 100.

Exact byte-for-byte goldens are valuable for the key examples. For the rest,
structural assertions are acceptable: non-empty output, balanced parentheses,
max indentation sanity, and expected leading lines for known forms.

## Benchmarking

Do not overwrite the slice2 baseline as if it were the same data. Add a slice3
CSV, for example:

```text
bench/results/lfe_knowledge.csv
```

Use the same core columns as slice2:

```text
id,label,width,time_us,memo_size,calls,tainted,badness,height,bytes,lines
```

Run all 20 samples at widths 80 and 100. Adding width 60 is useful if cheap,
because it starts to pressure layout choices without being the full stress
corpus. The closing report should summarize stable counters first
(`memo_size`, `calls`, `tainted`, `badness`, `height`, bytes/lines) and treat
timing columns as illustrative.

If the benchmark harness is touched, harden `run_once/1` with a monitor so a
crashing worker reports an error instead of hanging. If the CSV writer is
touched and still emits labels, add minimal CSV escaping.

## Success Criteria

- `pe_lfe` has a small typed public surface with specs on exported functions.
- No atoms are created from source-like symbol names.
- Generic S-expression fallback remains available.
- The 20 samples are lowered through `pe_lfe`, not through a fixture-only
  document builder.
- The key awkward slice2 shape, `lfe_07_bq_expand`, improves in the rendered
  output.
- All 20 samples render at width 80 and 100 with deterministic output.
- Slice3 benchmark output is committed separately from the slice2 baseline.
- The full verification floor remains green.

## Handoff

When complete, CC should provide:

- new `pe_lfe` source and tests;
- migrated 20-sample corpus;
- golden or structural layout evidence;
- benchmark stdout and committed `bench/results/lfe_knowledge.csv`;
- a per-row ledger walk with command output evidence;
- a caveat section naming any form the knowledge layer still handles awkwardly,
  any heavily-tainted sample, and any scope consciously deferred.

