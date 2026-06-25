# CDC verification — arc1-poc / slice5-lfe-layout-refinements

Verifier: Claude (Cowork chat seat, acting as CDC — independent of the
implementer, Codex, which authored slice5)
Date: 2026-06-23
Reviewed commit: `a2226e0` (Refine LFE block argument layout); docs scaffolding
`aa50040`.

## Verification boundary (read first)

Static, evidence-based CDC review — diffs, committed source, and committed CSV
read directly. Build/verify commands (`rebar3 compile`, `eunit`, `ct`,
`proper`, `dialyzer`, `xref`) **not re-run** (no OTP 28 toolchain here). Rows
whose evidence is a passing command are marked **structurally verified** (named
test/function exists; asserted artifact matches), with command re-run
**deferred to operator-run CDC**.

## Summary

No correctness or scope blockers. Slice5 resolves both slice3 visual caveats:
A1-R013 (block-valued call arguments) and A1-R014 (`flet`/`fletrec` function
bindings). 24 rows done, 2 validly deferred, 0 no-op, 0 silent drops. The two
key golden tests assert **exact rendered line content and a max-indent bound**
— substantive assertions, not stubs, consistent with the project's
assert-exact test discipline.

The most important CDC checks here are the **scope-control rows** (A1S5-21
no resolver change; A1S5-22 no parser work). Both hold under diff inspection.

## Evidence reproduced (static)

```text
Scope (git show --name-only a2226e0)
  PASS — src/ change is limited to src/pe_lfe.erl (the knowledge layer).
  NO pe_resolve / pe_mset / pe_cost / pe_memo / pe_doc / pe_measure changes
  → A1S5-21 (no resolver semantics) holds.
  NO reader / parser / scanner / span / comment module
  → A1S5-22 (no source-fidelity work) holds.

New knowledge-layer functions (src/pe_lfe.erl)
  PASS — generic_block_arg_call, block_valued_arg (A1-R013);
  flet_form, flet_bindings, lower_flet_binding (A1-R014) — all present.

Named tests present (test/pe_lfe_tests.erl, _bench_tests, _stress_tests)
  PASS — block_valued_call_arguments_test, lfe_08_match_lambda_argument_test,
  top_level_block_forms_stay_readable_test, flet_function_binding_layout_test,
  fletrec_function_binding_body_layout_test, flet_non_function_binding_fallback_test,
  lfe_20_fletrec_binding_test, generic_call_test (regression),
  refined_row_count_and_subset_test — all FOUND.

Golden-test assertions match ledger rendered-evidence (read in source)
  A1S5-4  lfe_08: asserts line "    (lists:foreach", line "      (match-lambda",
          and max_indent(Bin) =< 10.                                   ✓ exact
  A1S5-11 lfe_20: asserts line "    ((loop (q)", line "       (receive",
          and assertNot a standalone "\n      (q)\n" line.             ✓ exact

CSV artifact (bench/results/lfe_refined.csv, RFC-4180 parse)
  PASS — 85 data rows = 60 lfe-sample (20 ids × widths [60,80,100]) +
  25 stress-affected (5 ids × widths [20,40,60,80,100]);
  all 60 real-sample rows badness=0; affected ids =
  {block_arg_case, block_arg_lambda, block_arg_match_lambda,
   block_arg_receive, fletrec_bindings_12}.
  Existing lfe_samples/knowledge/stress CSVs untouched by the diff (A1S5-17).

Latency sanity (refined run)
  Heaviest row = fletrec_bindings_12 @ 959us; all other rows < ~0.5ms.
  The refinements did not introduce a latency regression.

Build/verify commands (compile, eunit, ct, proper, dialyzer, xref)
  CLEAN-TREE GREEN — CC re-ran on a clean checkout at f1cc23d (includes
  slice1–6): compile zero-warning; eunit 207, 0 failures; ct 2 passed;
  proper 5/5; dialyzer 15 files clean; xref clean. Clean-tree evidence
  (CC is implementer-adjacent), not fully-independent CDC, but it discharges
  the gate-rerun risk.
```

## Ledger walk

| ID | CDC status | Basis |
|----|------------|-------|
| A1S5-1 | verified done | diff scoped to `pe_lfe`, harness/tests, recs, ledger, new CSV; no broad fmt churn |
| A1S5-2..3 | verified done | `generic_block_arg_call`/`block_valued_arg` present; block-arg test present |
| A1S5-4 | verified done | `lfe_08_match_lambda_argument_test` asserts exact lines + `max_indent =< 10` |
| A1S5-5 | structurally verified | `block_argument_stress_layout_test` present |
| A1S5-6..7 | verified done | `generic_call_test` + `top_level_block_forms_stay_readable_test` (regression guards) present |
| A1S5-8..10 | verified done | `flet_form`/`flet_bindings`/`lower_flet_binding` present; binding + fallback tests present |
| A1S5-11 | verified done | `lfe_20_fletrec_binding_test` asserts exact `((loop (q)` shape, no standalone `(q)` line |
| A1S5-12 | structurally verified | `fletrec_stress_binding_layout_test` present |
| A1S5-13..14 | structurally verified | metrics moved inside `monitored/2`; timeout/error row tests present |
| A1S5-15 | verified done | `lfe-knowledge`/`lfe-stress` modes still routed in `bench/pe_bench` |
| A1S5-16..19 | verified done | `lfe_refined.csv` = 85 rows (60+25) reproduced; prior CSVs untouched |
| A1S5-20 | verified done | Caveat Checklist names shapes + stable counters, timing treated as illustrative |
| A1S5-21 | verified done | **no resolver/mset/cost modules in diff** |
| A1S5-22 | verified done | **no parser/source-span/comment modules in diff**; still lowers explicit `form()` |
| A1S5-23..24 | verified (clean-tree, CC-run) | gates green at f1cc23d: compile/eunit 207/ct 2/proper 5/dialyzer 15/xref |
| A1S5-25..26 | valid deferred | OTP backport; coverage + CAP audit — carried, not dropped |

## Findings

- **F1 (minor / bookkeeping).** Closure line reads "pending (`HEAD aa50040`
  + working tree)"; implementation landed at `a2226e0`. Record the closing SHA
  (cleanup slice handles this).
- **F2 (positive).** Scope discipline is exemplary: the two scope-control rows
  (no resolver, no parser) are the ones most likely to be quietly violated when
  "just refining layout," and the diff confirms neither was touched. The
  accidental broad `rebar3 fmt` churn noted in A1S5-1 was backed out — diff
  shows no unrelated reformatting.
- **F3 (forward pointer, not a defect).** A1S5-22 keeps parser/source fidelity
  out of scope; the caveat checklist correctly records this as still-open
  A1-R015 — the next frontier.

## Closure

CDC accepts slice5 at the stated scope (knowledge-layer layout refinement, no
resolver/parser change). Both target caveats resolved with exact-assertion
golden tests; scope clean; CSV reproduced; engineering gates green on a clean
tree at `f1cc23d` (CC-run — clean-tree evidence). F1 resolved: closing SHA
`a2226e0` recorded (commit `62cf9fb`). Final fully-independent sign-off is
optional given clean-tree green.
