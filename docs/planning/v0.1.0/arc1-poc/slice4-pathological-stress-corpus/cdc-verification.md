# CDC verification — arc1-poc / slice4-pathological-stress-corpus

Verifier: Claude (Cowork chat seat, acting as CDC — independent of the
implementer, Codex, which authored slice4)
Date: 2026-06-23
Reviewed commit: `96dcdfd` (Add LFE pathological stress benchmark);
docs scaffolding `0d0e812`.

## Verification boundary (read first)

This is a **static, evidence-based CDC review**: diffs, committed source, and
committed CSV artifacts were read directly (not the implementer's summaries).
The build/verify commands (`rebar3 compile`, `eunit`, `ct`, `proper`,
`dialyzer`, `xref`) were **not re-run** — the verification environment has no
OTP 28 toolchain, and running an older OTP against `warnings_as_errors`,
OTP28-targeted code would be misleading. Rows whose evidence is a *passing
command* are therefore marked **structurally verified** (the named test /
function exists in committed source and the asserted artifact matches) with
the command re-run **deferred to operator-run CDC**. This mirrors the
operator-run CDC mode already noted in the slice3 ledger.

## Summary

No correctness or scope blockers found. Slice4 is row-complete: 26 rows done,
2 validly deferred, 0 no-op, 0 silent drops. The corpus is **test-profile only**
(no `src/` changes), which is correct for a stress corpus — it exercises the
existing engine, it does not modify it.

All structural-counter claims in the ledger's Caveat Checklist were
**reproduced exactly** from the committed `bench/results/lfe_stress.csv` using
an RFC-4180 parser.

## Evidence reproduced (static)

```text
Scope (git show --name-only 96dcdfd)
  PASS — touches only: bench/pe_bench, bench/results/lfe_stress.csv,
  running-recommendations.md, slice4 ledger, and test/ modules
  (pe_lfe_stress.erl, pe_lfe_stress_tests.erl, pe_lfe_bench.erl,
  pe_lfe_bench_tests.erl). No src/ engine changes — correct for a stress
  corpus.

Stress families present (test/pe_lfe_stress.erl)
  PASS — proper_list_*, dotted_list_*, generic_call_*, deep_sexp_*,
  shared_concat_10, shared_choice_8, quote_tower_*, let_bindings_16,
  letstar_bindings_24, fletrec_bindings_12, nested_case_8, nested_receive_6,
  nested_cond_12, block_arg_{match_lambda,lambda,case,receive},
  nofit_text_{80,180}, tiny_width_call_30 — all FOUND.

Named tests present (pe_lfe_stress_tests.erl / pe_lfe_bench_tests.erl)
  PASS — stress_count_and_ids_test, stress_metadata_test,
  representative_families_render_test, shared_dag_size_test,
  stress_builds_deterministic_test, forced_nofit_badness_test,
  stress_columns_test, stress_row_count_test, stress_monitored_timeout_test,
  stress_monitored_error_test — all FOUND.

CSV artifact (bench/results/lfe_stress.csv, RFC-4180 parse)
  PASS — 125 data rows; 25 distinct ids; widths exactly [20,40,60,80,100];
  0 non-ok rows; header column order matches A1S4-16 exactly; dag_size present.
  Comma-bearing labels are correctly double-quoted (escape_csv works; a naive
  comma-split parser misreads them, but the file is valid CSV).

Caveat-checklist headline counters (all reproduced exactly)
  shared_concat_10 @20  : badness=126427536, dag_size=11   ✓
  nested_case_8    @100 : calls=2002, memo=1833, tainted=478 ✓
  letstar_bindings_24 @100 : calls=1962                     ✓
  nested_receive_6 @100 : calls=1893, memo=1688, tainted=421 ✓
  nofit_text_180   @20  : badness=25600                     ✓
  tiny_width_call_30 @20: badness=656100                    ✓

Build/verify commands (compile, eunit 132, ct, proper 5/5, dialyzer 15 files,
xref)
  DEFERRED to operator-run CDC — not re-run here (no OTP 28 toolchain).
  Named tests exist in committed source; pass/fail not independently confirmed.
```

## Ledger walk

| ID | CDC status | Basis |
|----|------------|-------|
| A1S4-1 | structurally verified | `test/pe_lfe_stress.erl` exists with stable surface; diff scope confirmed |
| A1S4-2 | structurally verified | `stress_count_and_ids_test`, `stress_metadata_test` present |
| A1S4-3..6 | verified done | family ids present (proper/dotted/generic/deep); representative render test present |
| A1S4-7 | verified done | `shared_concat_10`/`shared_choice_8` present; CSV `dag_size=11` confirmed |
| A1S4-8..10 | verified done | quote-tower, binding-list, nested-clause families present |
| A1S4-11 | verified done | `block_arg_*` families present (the slice3 `lfe_08` caveat seed) |
| A1S4-12 | verified done | forced no-fit rows show non-zero badness in CSV (reproduced) |
| A1S4-13 | structurally verified | `stress_builds_deterministic_test` present |
| A1S4-14..15 | verified done | `lfe-stress` mode in `bench/pe_bench`; CSV written, prior CSVs untouched (diff) |
| A1S4-16 | verified done | CSV header matches requested column list exactly |
| A1S4-17 | verified done | 125 rows = 25×5; widths [20,40,60,80,100] (reproduced) |
| A1S4-18..19 | structurally verified | `monitored/2` + `spawn_monitor`; timeout/error tests present; 0 timeout rows in run |
| A1S4-20 | verified done | `dag_size` column present; module doc defines it as `pe_doc:size/1` |
| A1S4-21 | structurally verified | `representative_families_render_test` present |
| A1S4-22 | verified done | `nofit_text_180@20=25600`, `tiny_width_call_30@20=656100` reproduced |
| A1S4-23 | structurally verified | stdout-summary code present in harness; not exercised here |
| A1S4-24 | verified done | Caveat Checklist names proxy limitation (no exact all-tainted instrumentation) honestly |
| A1S4-25..26 | DEFERRED (operator-run) | engineering-gate commands not re-run; named tests exist |
| A1S4-27..28 | valid deferred | OTP 22–29 backport; coverage + CAP audit — explicitly carried, not dropped |

## Findings

- **F1 (minor / bookkeeping).** The Closure line reads "Closed at commit:
  pending (`HEAD 0d0e812` + working tree)", but the implementation actually
  landed at `96dcdfd`. The closing SHA is stale and should be recorded (the
  cleanup slice handles this).
- **F2 (informational, positive).** CSV escaping (`escape_csv/1`) is working:
  comma-bearing labels are double-quoted per RFC 4180. The A1-R012 concern is
  genuinely addressed, not merely latent, for the comma case.
- **F3 (methodology, already disclosed).** Amendment 3 is honest: the
  all-tainted *path* is not instrumented; non-zero `badness`/`tainted` is used
  as a proxy. This is the correct disclosure, and it is the same gap as the
  still-open niceness-bet frontier-width instrumentation (see
  running-recommendations / §3 follow-up). Not a slice4 defect; a named arc gap.

## Closure

CDC accepts slice4 at the stated scope (pathological stress corpus, test-only,
counter-level evidence), **conditional on operator-run of the engineering-gate
commands** (A1S4-25/26). No silent drops; scope is clean; all reproducible
counters match. Recommend recording closing SHA `96dcdfd` (F1).
