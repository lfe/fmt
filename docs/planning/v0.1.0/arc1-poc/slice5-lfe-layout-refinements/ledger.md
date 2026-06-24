# Slice 5: LFE layout refinements

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S5-1 | Slice starts from committed slice4 state and does not fold unrelated work into the diff | `git status`; `git log`; code review | serious | collaboration discipline | done | `HEAD aa50040` starts from slice5 planning after slice4 implementation `96dcdfd`; `git diff --stat` is scoped to `pe_lfe`, bench harness/tests, running recommendations, ledger, and new `lfe_refined.csv` | Accidental broad `rebar3 fmt` churn was backed out before closure. |
| A1S5-2 | `pe_lfe` adds a focused abstraction for block-valued argument layout | code review; `rebar3 compile` | serious | A1-R013 | done | `generic_call/3` branches to `generic_block_arg_call/4`; `rebar3 compile` clean | |
| A1S5-3 | Known block argument forms include `lambda`, `match-lambda`, `case`, `receive`, and `cond` | code review; eunit tests | serious | A1-R013 | done | `block_valued_arg/1`; `block_valued_call_arguments_test_`; `rebar3 eunit`: 153 tests, 0 failures | |
| A1S5-4 | `lfe_08_ets_new` no longer shows pathological rightward drift for `match-lambda` as an argument | targeted golden/indent test | serious | slice3 caveat | done | `lfe_08_match_lambda_argument_test`; rendered width 80 has `lists:foreach` then local `match-lambda`; max indent <= 10 | |
| A1S5-5 | Stress block-argument samples reflect the refined layout | eunit structural tests over `block_arg_*` samples | correctness | slice4 corpus / A1-R013 | done | `block_argument_stress_layout_test`; `rebar3 eunit`: 153 tests, 0 failures | |
| A1S5-6 | Ordinary generic calls still use generic S-expression fallback | regression test | serious | scope control | done | `generic_call_test` still expects `(foo a b)` and `(foo)`; `rebar3 eunit`: 153 tests, 0 failures | |
| A1S5-7 | Top-level/body-position block forms keep their existing readable block behavior | regression tests for `lambda`, `match-lambda`, `case`, `receive`, `cond` | correctness | scope control | done | `top_level_block_forms_stay_readable_test` plus existing case/receive/cond tests; `rebar3 eunit`: 153 tests, 0 failures | |
| A1S5-8 | `pe_lfe` adds focused function-binding layout for `flet` and `fletrec` | code review; `rebar3 compile` | serious | A1-R014 | done | `flet_form/4`, `flet_bindings/3`, `lower_flet_binding/3`; `rebar3 compile` clean | |
| A1S5-9 | Function bindings shaped `(name (args...) body...)` render clause-like | focused eunit test | serious | A1-R014 | done | `flet_function_binding_layout_test` and `fletrec_function_binding_body_layout_test`; `rebar3 eunit`: 153 tests, 0 failures | |
| A1S5-10 | Non-function binding shapes retain safe fallback behavior | focused eunit test | correctness | scope control | done | `flet_non_function_binding_fallback_test` expects `(flet ((x 1)) x)` | |
| A1S5-11 | `lfe_20_eval_receive` formats `fletrec` local function binding naturally | targeted golden/indent test | serious | slice3 caveat | done | `lfe_20_fletrec_binding_test`; rendered width 80 has `((loop (q)` and nested `receive`, with no separate `(q)` line | |
| A1S5-12 | Stress `fletrec_bindings_12` reflects the refined binding layout | eunit structural test | correctness | slice4 corpus / A1-R014 | done | `fletrec_stress_binding_layout_test`; `rebar3 eunit`: 153 tests, 0 failures | |
| A1S5-13 | Stress benchmark row work moves construction, `dag_size`, resolve, render, and metric extraction inside the monitored timeout boundary | code review; targeted test if practical | serious | A1-R016 | done | `stress_row/3` worker calls `stress_metrics/3`; `stress_metrics/3` now builds the DAG, computes `pe_doc:size/1`, resolves, renders, and extracts metrics inside `monitored/2` | Public seam does not cheaply delay build; closure uses code-review evidence plus existing monitored timeout/error tests. |
| A1S5-14 | Timeout/error rows still emit stable CSV rows when construction or formatting fails/times out | eunit test or explicit code-review evidence | serious | A1-R016 | done | `stress_monitored_timeout_test`, `stress_monitored_error_test`; `failed_stress_row/2` now fills `dag_size => 0` with all other stable zero counters | |
| A1S5-15 | Existing `lfe-knowledge` and `lfe-stress` benchmark modes remain available | run or smoke-test commands | correctness | benchmark continuity | done | `bench/pe_bench` still routes `lfe-knowledge` to `run_knowledge/0` and `lfe-stress` to `run_stress/0`; exports unchanged and `rg` confirmed both modes | Did not rerun legacy commands to avoid rewriting slice3/slice4 timing artifacts. |
| A1S5-16 | Slice5 adds a refined benchmark command, e.g. `escript bench/pe_bench lfe-refined` | run benchmark | serious | slice5 evidence | done | `escript bench/pe_bench lfe-refined` exit 0; wrote `bench/results/lfe_refined.csv (85 rows)` | |
| A1S5-17 | Slice5 benchmark writes a new artifact, e.g. `bench/results/lfe_refined.csv`, without silently repurposing slice3/slice4 CSVs | inspect files and ledger | serious | evidence hygiene | done | `bench/results/lfe_refined.csv` added; `git status --short` shows no modifications to existing `lfe_samples.csv`, `lfe_knowledge.csv`, or `lfe_stress.csv` | |
| A1S5-18 | Refined benchmark includes all 20 real samples at widths 60, 80, and 100, or records a justified amendment | CSV row count | correctness | viability evidence | done | `refined_row_count_and_subset_test`: 60 `lfe-sample` rows at widths `[60,80,100]`; CSV has 86 lines including header | |
| A1S5-19 | Refined benchmark includes affected stress samples, or all stress samples, with clear labels | CSV row count/content | correctness | A1-R013 / A1-R014 | done | `refined_row_count_and_subset_test`: 25 `stress-affected` rows for five affected IDs at widths `[20,40,60,80,100]` | Affected subset chosen to keep slice5 evidence focused. |
| A1S5-20 | Closing report summarizes shape improvements and stable counter changes without over-reading timing | closing report review | serious | methodology | done | Caveat Checklist below and handoff summary name shapes and stable counters; timing treated as illustrative | |
| A1S5-21 | No resolver semantic changes are introduced | code review; targeted diff review | serious | scope control | done | `git diff --stat` includes no `src/pe_resolve*`, `src/pe_mset*`, `src/pe_cost*`, or resolver modules | |
| A1S5-22 | No parser/source-fidelity work is introduced | code review; ledger review | correctness | scope control | done | Diff contains no parser modules or source-span/comment machinery; `pe_lfe` still lowers explicit `form()` terms | |
| A1S5-23 | Zero-warning compile + xref + dialyzer clean | `rebar3 compile`; `rebar3 xref`; `rebar3 dialyzer` | serious | engineering bar | done | `rebar3 compile` clean; `rebar3 xref` clean; `rebar3 dialyzer` exit 0 analyzing 15 files | |
| A1S5-24 | Unit/integration/property floor green | `rebar3 eunit`; `rebar3 ct` if CT is used; `rebar3 proper` if PropEr is present/added | serious | engineering bar | done | `rebar3 eunit`: 153 tests, 0 failures; `rebar3 ct`: all 2 tests passed; `rebar3 proper`: 5/5 properties passed | |
| A1S5-25 | OTP 22-29 compatibility remains explicitly deferred if not handled | ledger review | polish | deferred from arc | deferred | | Re-entry: OTP backport slice; this PoC remains on the current local OTP/rebar3 toolchain. |
| A1S5-26 | Coverage gate + CAP strength audit remains explicitly deferred if not handled | ledger review | serious | deferred from arc | deferred | | Re-entry: post-slice strength-analysis / CAP audit phase. |

## Amendments

Record scope amendments here before closure. Each amendment should explain what
changed, why it changed, and which ledger rows it affects.

1. **Refined benchmark uses affected stress subset.** The slice5 benchmark covers
   all 20 real samples at widths 60/80/100 and the five affected stress samples
   (`block_arg_match_lambda`, `block_arg_lambda`, `block_arg_case`,
   `block_arg_receive`, `fletrec_bindings_12`) at widths 20/40/60/80/100,
   rather than rerunning all 25 stress rows. This matches the prompt's allowed
   "clearly named affected subset" path (A1S5-18/19).
2. **Timeout-boundary evidence is code-review plus existing worker tests.** The
   public stress-sample seam does not provide a cheap delayed-build hook. The
   implementation now places build, `dag_size`, resolve, render, and metrics
   inside `stress_metrics/3`, called only from `monitored/2`; timeout/error row
   stability remains covered by monitored worker tests and code review
   (A1S5-13/14).

## Caveat Checklist

At closure, fill in:

- **Exact layout-rule changes made in `pe_lfe`:** generic calls containing
  block-valued arguments (`lambda`, `match-lambda`, `case`, `receive`, `cond`)
  use a local block indentation branch; `flet`/`fletrec` binding lists recognize
  function bindings shaped `(name (args...) body...)` and lower them with a
  local name+args head plus nested body. Ordinary calls and non-function
  bindings retain fallback behavior.
- **Rendered evidence for `lfe_08_ets_new` (width 80):**
  ```lisp
  (lists:foreach
    (match-lambda
      ((`#(,name ,desc)) (ets:insert tab (make-place name name desc desc))))
    (default-places))
  ```
- **Rendered evidence for `lfe_20_eval_receive` (width 80):**
  ```lisp
  (fletrec
    ((loop (q)
       (receive
         (msg (when (match-clauses msg clauses)) (apply-clause msg clauses env))
         (after timeout (loop (merge-queue q))))))
    (loop ()))
  ```
- **Affected stress samples:** `block_arg_match_lambda`, `block_arg_lambda`,
  `block_arg_case`, and `block_arg_receive` now break block arguments under the
  call head; `fletrec_bindings_12` keeps local function name and argument list
  together and aligns subsequent bindings under the binding-list opening.
- **Refined benchmark artifact:** `bench/results/lfe_refined.csv`, 86 lines
  including header / 85 data rows.
- **Stable counters worth noticing:** all 60 real-sample rows have
  `badness = 0`; affected stress rows are labelled `stress-affected`. Narrow
  width 20 still intentionally records non-zero badness for some block-argument
  rows (`block_arg_match_lambda`, `block_arg_case`), while the fletrec stress
  rows stay at `badness = 0`.
- **Timeout/error rows:** none in the refined benchmark output; timeout/error
  behavior remains covered by targeted monitored-worker tests.
- **Remaining generic-fallback awkward shapes:** this slice intentionally leaves
  parser/source fidelity, comments, Unicode width, and broader generic
  backquoted-data refinements out of scope.
- **Deferrals:** parser/source fidelity remains A1-R015; Unicode width remains
  A1-R008; OTP 22-29 compatibility and coverage/CAP remain deferred rows.

## Closure

Closed at commit `a2226e0` on 2026-06-23. Total rows: 26. Done: 24.
Deferred: 2 (A1S5-25 OTP 22–29 backport; A1S5-26 coverage gate + CAP audit).
No-op: 0.

CDC verification: static review complete — see `cdc-verification.md`
(no blockers; both A1-R013/R014 caveats resolved with exact-assertion golden
tests; scope-control rows confirmed). Engineering-gate command re-run
(A1S5-23/24) remains operator-run pending.
