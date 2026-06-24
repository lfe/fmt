# Slice 6: whole-file latency (minimal reader bridge)

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S6-1 | `lfe` added as test-profile dep only; `src/` stays dep-free (`{deps, []}` unchanged) | `rebar.config` review; `rebar3 compile` | serious | slice6 spec / zero-dep identity | done | `{lfe, "~> 2.2"}` under test profile; top-level `{deps, []}` unchanged; compile clean | hex max is 2.2.0; resolves there |
| A1S6-2 | `pe_lfe_read:read_file/1 -> {ok,[form()]} \| {error,term()}` exists with spec | code review; compile | serious | slice6 spec | done | `test/pe_lfe_read.erl` `read_file/1` with spec; compiles | |
| A1S6-3 | Conversion maps atoms/integers/tuples/lists/dotted-lists/quote-family correctly | eunit snippets via `read_string/1` | correctness | reader bridge | done | `leaves_test`/`call_test`/`tuple_test`/`dotted_list_test`/`quote_family_test` | |
| A1S6-4 | Quote-family head atoms confirmed against `lfe_scan`/`lfe_parse`, cited in comment | code review | serious | correctness over guessing | done | module doc cites `lfe_parse.erl` reductions 7–10: `[quote\|backquote\|comma\|comma-at, X]` | |
| A1S6-5 | Code-vs-data list rule: code→`{call}`, quoted→`{list}`, `()`→`{list,[]}` | eunit | correctness | reader bridge | done | `code_vs_data_test` (incl. `'((a) b)` data-all-the-way-down) | |
| A1S6-6 | Unmodeled leaves (float/binary/map/char/string) hit printed-text fallback, never crash | eunit per kind | serious | let-it-crash boundary | done | `fallback_no_crash_test` (float/binary/map/string/fun), `char_is_int_test`, `string_is_single_leaf_test`, `convert_is_total_test` | |
| A1S6-7 | Round-trips every top-level form of `cl.lfe`, `clj.lfe`, each `test/*.lfe` without crash | eunit via `code:lib_dir(lfe)` | serious | real-input gate | done | `round_trip_test_`: 13 per-file tests green (cl 82, clj 111, +11 suites); **0 genericised** | |
| A1S6-8 | `escript bench/pe_bench lfe-files` mode exists + documented | run it | serious | slice6 spec | done | `main(["lfe-files"])` wired; documented in escript header; 39-row run | |
| A1S6-9 | Per file×width runs in monitored worker w/ timeout; failure→status row, no hang | code review; targeted test | serious | A1-R009 lineage | done | `files_row/3` uses `monitored/2` (30s); `files_row_error_test` (bad path → `error` row, no hang) | |
| A1S6-10 | Headline `fmt_us` = Σ(per-form `format_binary`); `parse_us` recorded separately | code review; CSV | serious | viability evidence | done | `file_metrics`: `fmt_us`=Σ per-form `safe_format_binary`, `parse_us`=read+convert; `files_row_ok_test` | |
| A1S6-11 | `worst_form_us` (+ id/index) recorded | CSV | polish | diagnostics | done | `worst_form_us`, `worst_form_index`, `worst_form_head` columns | |
| A1S6-12 | `bench/results/lfe_files.csv` written with documented header; binary fields escaped | CSV + header test | serious | evidence usability | done | `files_columns_test`/`files_csv_header_test`; `field/1`→`escape_csv/1` for binaries | |
| A1S6-13 | Widths cover ≥ 80 and 100 (60 if cheap) | CSV inspection | serious | viability evidence | done | widths 60/80/100 → 39 rows (13 files × 3) | |
| A1S6-14 | Existing bench modes + CSVs untouched | `git status`; smoke | serious | evidence hygiene | done | `git status bench/results/` shows only `lfe_files.csv` new; `lfe_samples`/`lfe_knowledge`/`lfe_stress`/`lfe_refined` unmodified | |
| A1S6-15 | Closing report frames numbers as latency-not-fidelity; names approximations + fallback-heavy files | report review | serious | methodology | done | see Caveat Checklist | |
| A1S6-16 | Zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | engineering bar | done | compile zero-warning; xref clean; dialyzer 15 files clean | |
| A1S6-17 | eunit floor green | `rebar3 eunit` | serious | engineering bar | done | 207 tests, 0 failures | |
| A1S6-18 | Faithful conversion / comments / spans deferred as A1-R015 | ledger review | correctness | deferred | deferred | | re-entry: production reader slice (A1-R015) |
| A1S6-19 | Single-document model deferred or labelled secondary | ledger/CSV | polish | scope | deferred | | per-form is the realistic model; whole-file-as-one-resolve is a curiosity, not added |
| A1S6-20 | OTP 22–29 backport; coverage + CAP audit remain deferred | ledger review | serious | deferred from arc | deferred | | carried arc deferrals |

## Amendments

1. **lfe 2.2.0, not 2.2.1.** Hex's newest `lfe` is 2.2.0 (Duncan's local checkout
   is a 2.2.1 dev build). `{lfe, "~> 2.2"}` resolves to 2.2.0, which ships
   `src/cl.lfe`, `src/clj.lfe`, and 11 `test/*.lfe` suites (slice-doc said 12;
   the hex package ships 11). All reference inputs present.
2. **Shape-aware converter (not purely generic).** A generic code→`{call}`
   converter crashes `pe_lfe`'s clause rules (`case`/`receive`/`cond`/
   `match-lambda` + multi-clause `defun`/`defmacro`), and real forms commonly
   *contain* these, so most forms would crash. The bridge therefore emits
   clauses for those heads as `{list}` (structural mapping only — all layout
   stays in `pe_lfe`). Result: **0 genericised fallbacks across all 13 files** —
   the knowledge layer engages on 100% of real forms, so the latency is the real
   formatter's, not a generic-list proxy.
3. **`genericize/1` + `safe_format_binary/2` safety net.** Guarantees formatting
   never throws (force `{call}`→`{list}`, retry); the `genericised` boolean is
   surfaced as a CSV column. Never actually triggered on the corpus (0/≈500
   forms), but it makes A1S6-7/9 unconditional.
4. **Column extensions.** Beyond A1S6-12's list: `worst_form_index`,
   `worst_form_head`, `genericised` (justified diagnostics).
5. **Leaf approximations.** `comma-at` (`,@`) → `unquote` (no splice node in
   `form()`); printable char lists → one printed-text leaf (avoids char-int
   explosion, keeps node count representative); float/binary/map/fun →
   `{sym, lfe_io:print1/1}`.

## Caveat Checklist (closure)

- **Files needing fallback most:** none — `genericised = 0` for every file at
  every width. The shape-aware converter handled all ≈500 top-level forms.
- **Headline whole-file `fmt_us` (ms, map backend, limit=width)** @ 60/80/100:
  - `cl.lfe` (82 forms, 767 lines): **30.3 / 25.9 / 26.9**
  - `clj.lfe` (111 forms): **25.4 / 25.6 / 27.5**
  - `guard_SUITE.lfe` (79 forms, 33k nodes — slowest): **49.1 / 51.4 / 60.1**
  - all other suites: **< 30** (most < 10).
- **Worst single form across the corpus:** ≈6.8 ms (`cl.lfe`, a form at width 60);
  typically the worst form per file is 1.5–5 ms.
- **`parse_us` vs `fmt_us` split:** read+convert is the minority — roughly
  20–40% of `fmt_us` (e.g. `cl.lfe` @80: parse 6.0 ms vs fmt 25.9 ms;
  `guard_SUITE` @80: parse 19.4 ms vs fmt 51.4 ms).
- **Timing caveat:** MacBook Pro, one run, in-process best-effort; treat timing
  columns as illustrative. Stable counters (`dag_size`, `tainted`, `n_forms`,
  `bytes`) are the primary signal; `tainted` here is pruned-sub-layout
  bookkeeping (badness summed > 0 only where a form genuinely overflows), not a
  failure.
- **Fidelity caveat (NOT a correctness claim):** these are *latency* numbers.
  The call/list disambiguation is heuristic (multi-clause detection, clause
  shaping); strings collapse to one printed leaf; `comma-at` loses its `@`;
  floats/binaries/maps render as printed leaves; comments and source spans are
  dropped entirely (LFE's reader discards comments). "We formatted cl.lfe in
  ~26 ms" must not become "the formatter is correct." Faithful conversion is the
  deferred **A1-R015**.

## Closure

Closed at commit `04cca2a` on 2026-06-23. CDC verification: pending
(operator-run). Total rows: 20. Done: 17. Deferred: 3 (A1S6-18 faithful
conversion / A1-R015; A1S6-19 single-document model; A1S6-20 OTP backport +
coverage/CAP). No-op: 0.

Headline for the running log: whole-file formatter latency (Σ per-form, width
80) is **~26 ms for cl.lfe (767 lines)** and **~26 ms for clj.lfe**, with the
heaviest file (`guard_SUITE`, ~33k nodes) at **~51 ms** and the worst single
form at **~6.8 ms** — all comfortably interactive. The per-form model means the
`O(n·W⁴)` cost stays small (per form, not per file). Latency, not fidelity;
go/no-go bar still to be set by Duncan.
