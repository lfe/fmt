# CDC verification — arc1-poc / slice6-whole-file-latency

Verifier: Claude (Cowork chat seat, acting as CDC — independent of the
implementer, CC, which authored slice6)
Date: 2026-06-24
Reviewed commit: `04cca2a` (slice6), `51e615f` (ledger SHA).

## Verification boundary

Static, evidence-based CDC: diffs, committed source, and committed
`lfe_files.csv` read directly; the latency headline re-derived from the CSV with
an RFC-4180 parser. Build/eunit not re-run here (no OTP 28 toolchain); CC's
clean-tree run is the pass-evidence for the suite.

## Summary

No blockers. 17 done, 3 deferred, 0 no-op, 0 silent drops. The slice is correctly
**benchmark-only** (no `src/` change), the zero-dep identity is preserved, and
the latency headline reproduces **exactly** from committed data. The fidelity
caveat is honestly and prominently disclosed.

## Independent reproduction (lfe_files.csv, 39 rows)

```text
cl.lfe        @80 : fmt_us=25892  → 25.9 ms   (ledger 25.9 ✓)  n_forms=82
clj.lfe       @80 : fmt_us=25573  → 25.6 ms   (ledger 25.6 ✓)  n_forms=111
guard_SUITE   @80 : fmt_us=51403  → 51.4 ms   (ledger 51.4 ✓)
max fmt_us across corpus = 60.08 ms (guard_SUITE @100; ledger 60.1 ✓)
genericised = 0 for every row  → knowledge layer engaged on 100% of forms
                                  (these are real-formatter numbers, not a
                                   generic-list proxy) ✓
columns match ledger A1S6-12 + amendment 4 exactly.
```

## Scope + structural evidence (static)

```text
Scope (git show --name-only 04cca2a)
  PASS — NO src/ changes (benchmark-only, as designed). Touches bench harness,
  test/pe_lfe_read.erl + tests, rebar.config (test-profile dep), planning docs,
  lfe_files.csv.

Zero-dep identity (rebar.config)
  PASS — `lfe` is under the `test` profile only, with a comment stating src/
  stays dep-free; top-level `{deps, []}` unchanged. The zero-runtime-dep
  property of the engine is preserved.

Bridge + tests present
  PASS — pe_lfe_read:read_file/1; code_vs_data_test, fallback_no_crash_test,
  convert_is_total_test, round_trip_test_ (real files via code:lib_dir(lfe)),
  files_row_error_test, files_csv_header_test — all FOUND.

Realistic model
  PASS — per-form independent format (fmt_us = Σ format_binary), parse_us
  separate; matches the slice-doc's Lever-2 rationale (W⁴ stays per-form).
```

## Ledger walk (abridged — full rows in ledger.md, all `done`/`deferred`)

| ID | CDC status | Basis |
|----|------------|-------|
| A1S6-1 | verified done | `lfe` test-profile only; `{deps,[]}` intact (read rebar.config) |
| A1S6-2..6 | verified done | bridge + conversion/fallback/total tests present |
| A1S6-7 | verified done | `round_trip_test_` over cl/clj/test*; ledger reports 0 genericised — reproduced (genericised=0 in CSV) |
| A1S6-8..13 | verified done | `lfe-files` mode; CSV 39 rows, widths 60/80/100; latency headline reproduced; columns match |
| A1S6-14 | verified done | only `lfe_files.csv` new in `bench/results/` (diff) |
| A1S6-15 | verified done | fidelity caveat present and prominent in ledger |
| A1S6-16..17 | clean-tree green (CC-run) | compile/xref/dialyzer/eunit — not re-run here |
| A1S6-18..20 | valid deferred | A1-R015 faithful reader; single-document model; OTP/coverage/CAP |

## Findings

- **F1 (positive / important).** `genericised = 0` across all 13 files is the
  load-bearing fact: it means the latency numbers are the *real* knowledge-layer
  formatter's, not a generic-list approximation. Reproduced from the CSV.
- **F2 (already disclosed, endorse).** The fidelity caveat is correct and must
  travel with these numbers: strings collapse to one leaf, `comma-at` loses `@`,
  floats/binaries/maps are printed leaves, comments/spans dropped. "Formatted
  cl.lfe in ~26 ms" is a *latency* statement, not a correctness one. Faithful
  conversion is the deferred A1-R015 — the next real build.

## Closure

CDC accepts slice6 at the stated scope (whole-file *latency* probe, benchmark-
only, fidelity explicitly out of scope). Headline reproduced exactly; zero-dep
identity intact; scope clean. Engineering gates rely on CC's clean-tree run
(noted). Feeds the (now-formality) latency-bar decision.
