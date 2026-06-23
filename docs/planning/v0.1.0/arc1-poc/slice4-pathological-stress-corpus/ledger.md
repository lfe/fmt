# Slice 4: Pathological stress corpus

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S4-1 | Stress corpus module exists with stable metadata and build surface | code review; `rebar3 compile` | serious | slice4 spec | done | HEAD `0d0e812` + working tree; `test/pe_lfe_stress.erl`; `rebar3 compile` clean | |
| A1S4-2 | Corpus exposes stable IDs, labels, categories, and sizes | eunit corpus metadata tests | correctness | benchmark reproducibility | done | `rebar3 eunit`: 132 tests, 0 failures; `stress_count_and_ids_test`, `stress_metadata_test` | |
| A1S4-3 | Corpus contains long proper-list stress cases | code review; eunit representative render | serious | A1-R007 | done | `proper_list_24`, `proper_list_48`; `representative_families_render_test` | |
| A1S4-4 | Corpus contains long improper/dotted-list stress cases | code review; eunit representative render | serious | A1-R007 | done | `dotted_list_16`, `dotted_list_32`; `representative_families_render_test` | |
| A1S4-5 | Corpus contains long generic-call fallback stress cases | code review; eunit representative render | serious | A1-R007 | done | `generic_call_24`, `generic_call_48`; `representative_families_render_test` | |
| A1S4-6 | Corpus contains deep generic S-expression stress cases | code review; eunit representative render | serious | A1-R007 | done | `deep_sexp_8`, `deep_sexp_12`; benchmark rows include non-zero badness at narrow widths | |
| A1S4-7 | Corpus contains at least one shared-subtree or shared-DAG stress case | code review; structural counter evidence | serious | A1-R001 / paper risk | done | `shared_concat_10`, `shared_choice_8`; `shared_dag_size_test`; CSV `shared_concat_10` has `dag_size=11` | |
| A1S4-8 | Corpus contains quote/backquote/unquote tower stress cases | code review; eunit representative render | correctness | LFE syntax risk | done | `quote_tower_12`, `quote_tower_18`; `representative_families_render_test` | |
| A1S4-9 | Corpus contains long `let`/`let*`/`flet`/`fletrec` binding-list cases | code review; eunit representative render | serious | A1-R007 / A1-R014 | done | `let_bindings_16`, `letstar_bindings_24`, `fletrec_bindings_12`; `representative_families_render_test` | |
| A1S4-10 | Corpus contains nested `case`/`receive`/`cond` or clause-like forms | code review; eunit representative render | serious | A1-R007 | done | `nested_case_8`, `nested_receive_6`, `nested_cond_12`; `representative_families_render_test` | |
| A1S4-11 | Corpus contains block-valued call-argument cases related to the slice3 `lfe_08` caveat | code review; eunit representative render | serious | A1-R013 | done | `block_arg_match_lambda`, `block_arg_lambda`, `block_arg_case`, `block_arg_receive`; `representative_families_render_test` | |
| A1S4-12 | Corpus contains forced no-fit or mostly-tainted rows by construction | code review; benchmark evidence | serious | A1-R001 | done | `nofit_text_80`, `nofit_text_180`, `tiny_width_call_30`; CSV has non-zero badness and tainted rows | |
| A1S4-13 | Stress samples build deterministically and do not depend on wall-clock/random input | eunit deterministic build tests | serious | reproducibility | done | `stress_builds_deterministic_test`; all samples rebuild with same root and DAG size | |
| A1S4-14 | Benchmark mode for stress corpus exists and is documented in command form | run `escript bench/pe_bench lfe-stress` or documented equivalent | serious | slice4 spec | done | `bench/pe_bench lfe-stress`; command ran and wrote `bench/results/lfe_stress.csv` | |
| A1S4-15 | Benchmark writes `bench/results/lfe_stress.csv` without overwriting prior benchmark artifacts | run benchmark; inspect files | serious | evidence hygiene | done | `escript bench/pe_bench lfe-stress`; `wc -l bench/results/lfe_stress.csv` -> 126 | Existing `lfe_samples.csv` and `lfe_knowledge.csv` modes untouched. |
| A1S4-16 | CSV header includes `id,label,category,size,width,limit,status,time_us,memo_size,calls,tainted,badness,height,bytes,lines,dag_size` or a justified equivalent | inspect CSV; eunit header test | correctness | analysis usability | done | `stress_columns_test`; CSV header exactly matches requested columns | |
| A1S4-17 | Benchmark covers normal and aggressive widths, including 20, 40, 60, 80, and 100 unless amended with rationale | CSV row inspection | serious | A1-R001 / A1-R007 | done | `stress_row_count_test`: 25 samples x 5 widths = 125 rows; widths `[20,40,60,80,100]` | |
| A1S4-18 | Benchmark runs each row in a monitored worker with timeout/error reporting | code review; timeout/error test if practical | serious | stress safety | done | `pe_lfe_bench:monitored/2` uses `spawn_monitor` plus `after`; `stress_monitored_timeout_test`, `stress_monitored_error_test` | |
| A1S4-19 | Timeout or worker error produces a CSV row and does not abort the remaining run | targeted test or controlled benchmark evidence | serious | stress safety | done | `stress_row/3` maps timeout/error to row status; targeted monitored timeout/error tests pass | Actual benchmark had no timeout/error rows. |
| A1S4-20 | CSV includes a deterministic `dag_size` or equivalent structural-size counter with documented meaning | code review; CSV inspection | correctness | analysis usability | done | `pe_lfe_stress` module doc defines `dag_size = pe_doc:size/1`; `stress_row_shape_test`; CSV includes `dag_size` | |
| A1S4-21 | Representative bounded stress cases render successfully in ordinary tests | `rebar3 eunit` | correctness | regression safety | done | `rebar3 eunit`: 132 tests, 0 failures; `representative_families_render_test` covers all stress families | |
| A1S4-22 | At least one forced no-fit canary records non-zero badness or an explicitly better all-tainted/no-fit signal | eunit or benchmark evidence | serious | A1-R001 | done | `forced_nofit_badness_test`; CSV examples: `nofit_text_180@20 badness=25600`, `tiny_width_call_30@20 badness=656100` | |
| A1S4-23 | Benchmark stdout summarizes worst rows by calls, memo size, tainted count, badness, and timeout/error status | run benchmark; inspect stdout | polish | operator usefulness | done | `escript bench/pe_bench lfe-stress` prints `calls top`, `memo_size top`, `tainted top`, `badness top`, and `status` summary | |
| A1S4-24 | Closing report states whether forced no-fit/all-tainted-like scenarios were observed, and names proxy limitations if exact all-tainted instrumentation is unavailable | closing report review | serious | methodology | done | Caveat Checklist below filled; exact all-tainted-path signal not instrumented, proxy is non-zero badness + tainted forced rows | |
| A1S4-25 | Zero-warning compile + xref + dialyzer clean | `rebar3 compile`; `rebar3 xref`; `rebar3 dialyzer` | serious | engineering bar | done | `rebar3 compile` clean; `rebar3 xref` clean; `rebar3 dialyzer` exit 0 analyzing 15 files | |
| A1S4-26 | Unit/integration/property floor green | `rebar3 eunit`; `rebar3 ct` if CT is used; `rebar3 proper` if PropEr is present/added | serious | engineering bar | done | `rebar3 eunit`: 132 tests, 0 failures; `rebar3 ct`: all 2 tests passed; `rebar3 proper`: 5/5 properties passed | |
| A1S4-27 | OTP 22-29 compatibility remains explicitly deferred if not handled | ledger review | polish | deferred from arc | deferred | | Re-entry: backport slice; OTP 28 remains target for this PoC slice. |
| A1S4-28 | Coverage gate + CAP strength audit remains explicitly deferred if not handled | ledger review | serious | deferred from arc | deferred | | Re-entry: post-slice strength-analysis/audit phase. |

## Amendments

Record scope amendments here before closure. Each amendment should explain what
changed, why it changed, and which ledger rows it affects.

1. **Stress IDs and categories are binaries.** Slice4 uses binary IDs/categories
   for `pe_lfe_stress` rather than atoms, matching the prompt's suggested
   binary-oriented surface and avoiding new atom vocabulary for corpus metadata
   (A1S4-1/2).
2. **`dag_size` is document-DAG size.** The deterministic structural counter is
   `pe_doc:size/1` after lowering/building: the frozen hash-consed document-node
   count, not source-form tree size or rendered byte count (A1S4-20).
3. **Exact all-tainted path not instrumented.** This slice does not add resolver
   instrumentation for "all-tainted path entered." It records forced no-fit rows
   through non-zero `badness` and `tainted` counters, as allowed by the prompt
   when exact instrumentation would churn resolver semantics (A1S4-12/22/24).

## Caveat Checklist

At closure, fill in:

- **Stress families included:** proper lists, dotted lists, generic calls, deep
  generic S-expressions, shared DAGs, quote/backquote/unquote towers, long
  binding lists, nested clause forms, block-valued call arguments, and forced
  no-fit rows. No requested stress family was deferred.
- **Highest calls:** `nested_case_8` at width 100 (`calls=2002`, `memo=1833`,
  `tainted=478`), followed by `letstar_bindings_24` at width 100
  (`calls=1962`) and `nested_receive_6` at width 100 (`calls=1893`).
- **Highest memo size:** `nested_case_8` at width 100 (`memo=1833`), then
  `nested_receive_6` at width 100 (`memo=1688`).
- **Highest tainted count:** `nested_case_8` at width 100 (`tainted=478`), then
  `nested_case_8` at width 80 (`tainted=439`) and `nested_receive_6` at width
  100 (`tainted=421`).
- **Highest badness:** `shared_concat_10` dominates badness across all widths,
  highest at width 20 (`badness=126427536`, `dag_size=11`). Forced no-fit rows
  also show non-zero badness, e.g. `tiny_width_call_30` at width 20
  (`badness=656100`) and `nofit_text_180` at width 20 (`badness=25600`).
- **Timeout/error rows:** none in the committed stress run; all 125 rows have
  `status=ok`. Timeout/error behavior is covered by targeted EUnit tests.
- **Forced no-fit/all-tainted-like scenarios:** observed through non-zero
  `badness` and `tainted` rows. Exact all-tainted-path entry is not directly
  instrumented; this report uses the proxy allowed by the slice prompt.
- **Timing caveat:** `time_us` is sample-output evidence from one local run.
  Stable counters (`calls`, `memo_size`, `tainted`, `badness`, `dag_size`) are
  the primary signal; timing is illustrative.
- **Visual-quality caveat:** block-valued call arguments remain intentionally
  unrefined. This slice measures pathological behavior and does not address
  the slice3 `lfe_08` visual caveat.

## Closure

Closed at commit: pending (`HEAD 0d0e812` + working tree).

CDC verification: pending.
