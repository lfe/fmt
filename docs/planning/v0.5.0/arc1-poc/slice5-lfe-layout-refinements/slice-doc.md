# Slice 5: LFE layout refinements

> Arc: `arc1-poc`
> Slice: `slice5-lfe-layout-refinements`
> Status: planned for CC
> Prior slice: `slice4-pathological-stress-corpus`

## Purpose

Slice4 gave the project enough stress evidence to stop treating the algorithmic
risk as the only next question. The current engine survives the deliberately
pathological corpus at the tested sizes, and the remaining high-value questions
are now about LFE usefulness: do common higher-order and local-function shapes
format like a Lisp programmer expects?

Slice5 refines the LFE knowledge layer around two known residual awkward cases:

- special/block forms used as ordinary call arguments, such as
  `(lists:foreach (match-lambda ...) ...)`;
- `flet`/`fletrec` local function bindings of the form
  `(name (args...) body...)`.

It also closes the small slice4 harness concern: the stress benchmark's timeout
should cover document construction and `dag_size`, not only resolve/render.

This slice should answer:

> Can the LFE knowledge layer handle block-valued arguments and local function
> bindings naturally, while preserving the slice4 stress/benchmark safety
> signal?

## Scope

In scope:

- Refine `pe_lfe` lowering for block-valued call arguments.
- Refine `pe_lfe` lowering for `flet` and `fletrec` function bindings.
- Add golden or structural tests for the two previously awkward real samples:
  `lfe_08_ets_new` and `lfe_20_eval_receive`.
- Add or update stress tests for `block_arg_match_lambda`, `block_arg_lambda`,
  `block_arg_case`, `block_arg_receive`, and `fletrec_bindings_12`.
- Move stress benchmark row construction fully inside the monitored timeout
  boundary.
- Add a new refined benchmark artifact that does not overwrite slice3/slice4
  baseline CSVs.
- Keep the full verification floor green.

Out of scope:

- LFE parser integration.
- Source fidelity, comments, or source-span preservation.
- Unicode display-width policy.
- Resolver semantic changes.
- New broad stress-corpus families.
- OTP 22-29 backport.
- Coverage gate and whole-repo CAP audit.

## Layout Targets

### Block-valued call arguments

Current behavior: known block forms used as arguments are lowered as ordinary
generic arguments, so their first line aligns under the call argument column and
the body can drift right.

Required behavior: when a generic call contains a known block form argument,
the block-valued argument should be allowed to break onto its own local block
indentation rather than inheriting generic first-argument alignment.

Examples to improve:

```lisp
(lists:foreach
  (match-lambda
    (((tuple name desc))
      (ets:insert tab (make-place name name desc desc))))
  (default-places))
```

The exact line breaks may differ if the implementation finds a better local
shape, but the nested block body should not drift far right under
`lists:foreach`.

Block-valued forms for this slice:

- `lambda`
- `match-lambda`
- `case`
- `receive`
- `cond`
- possibly other existing block forms if the helper naturally supports them
  without broadening scope.

### `flet`/`fletrec` function bindings

Current behavior: `fletrec` itself is recognized, but each function binding is
still formatted like a generic list.

Required behavior: function bindings shaped like `(name (args...) body...)`
should use clause-like layout:

```lisp
(fletrec
  ((loop (q)
     (receive
       ...)))
  (loop ()))
```

The important property is that the binding's name and argument list form a
local function head, and the body nests under that head. Non-function binding
shapes should continue to fall back safely to the existing list/generic layout.

## Benchmarking

Do not overwrite the existing slice3 or slice4 CSV artifacts as if they were
the same evidence. Add a new slice5 artifact, for example:

```text
bench/results/lfe_refined.csv
```

Recommended coverage:

- the 20 real LFE samples at widths 60, 80, and 100;
- the slice4 stress corpus at widths 20, 40, 60, 80, and 100, or a clearly
  named affected subset if running the whole corpus is too noisy;
- enough columns to compare stable counters before/after: `id`, `label`,
  `category` when available, `width`, `time_us`, `memo_size`, `calls`,
  `tainted`, `badness`, `height`, `bytes`, `lines`, `dag_size` when available.

Timing remains illustrative. The closing report should emphasize structural
counters and rendered-shape evidence.

The old benchmark commands should still work. If CC adds a new mode, use a
clear name such as:

```bash
escript bench/pe_bench lfe-refined
```

## Tests

At minimum:

- exact or targeted golden tests for `lfe_08_ets_new`;
- exact or targeted golden tests for `lfe_20_eval_receive`;
- focused unit tests for block-valued arguments in generic calls;
- focused unit tests for `flet`/`fletrec` function binding layout;
- regression tests that ordinary generic calls and ordinary lists still render
  as before;
- stress-harness tests proving document construction and `dag_size` are inside
  the monitored timeout boundary, or a justified equivalent if the public seam
  makes exact testing awkward.

Prefer targeted line/indent assertions over brittle full-output goldens except
for compact examples where byte-exact output is clearly stable.

## Success Criteria

- `lfe_08_ets_new` no longer shows pathological rightward drift for
  `match-lambda` used as a call argument.
- `lfe_20_eval_receive` formats `fletrec` function bindings in a clause-like
  shape.
- Stress block-argument and `fletrec` samples reflect the refined layout.
- Stress benchmark timeout covers construction, `dag_size`, resolve, and render.
- Slice5 benchmark evidence is written to a new artifact and prior CSVs are not
  silently repurposed.
- Verification floor remains green: compile, eunit, CT if present, PropEr if
  present, xref, and dialyzer.

## Handoff

When complete, CC should provide:

- summary of `pe_lfe` layout-rule changes;
- rendered before/after-style examples for `lfe_08_ets_new` and
  `lfe_20_eval_receive`;
- benchmark command and committed slice5 CSV artifact;
- verification floor output;
- per-row ledger walk;
- caveats and deferrals, especially any shapes still falling back to generic
  layout.
