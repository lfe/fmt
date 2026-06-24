# CC prompt — arc1-poc / slice6 — whole-file latency (minimal reader bridge)

> For CC (implementation seat). Read `slice-doc.md` first for the design and the
> decision rationale. Load **erlang-guidelines** (`11-anti-patterns` first, then
> `01-core-idioms`, `03-error-handling`, `15-testing`). Walk the ledger; CDC
> verifies independently. Iteration cap: 5.

## Goal

Get **real whole-file formatting latency** on `cl.lfe`, `clj.lfe`, and the LFE
`test/*.lfe` suites, on Duncan's MacBook Pro. Build the minimum reader bridge to
do it (reuse LFE's reader; benchmark-only) and a new bench mode. **No `src/`
changes** — reuse `pe_lfe:format_binary/2` per top-level form.

## Scope fence

- New files: `test/pe_lfe_read.erl` (bridge), `test/pe_lfe_read_tests.erl`,
  a new bench mode in `test/pe_lfe_bench.erl` + escript wiring in `bench/pe_bench`,
  the new `bench/results/lfe_files.csv`, and a one-line test-profile dep in
  `rebar.config`.
- **Do not** touch `src/`. **Do not** modify existing CSVs
  (`lfe_samples`, `lfe_knowledge`, `lfe_stress`, `lfe_refined`).
- **No git safety-bypass flags** (no `--allow-dirty`/`--no-verify`/`--force`);
  satisfy gates, don't skip them (CLAUDE.md).
- Sandbox cannot mutate git or unlink in mounted repos — if any `rm`/`git` is
  needed, hand it to Duncan.

## Safety / idiom notes (erlang-guidelines)

- The bridge reads source files and calls LFE's reader, which **interns atoms**.
  That is the reader's behaviour, on semi-trusted source we are formatting — but
  note it in the module doc, and do **not** add any `list_to_atom/1` of your own.
  Our side converts atom → binary via `atom_to_binary/2`.
- **Let it crash per file, not per run.** Each file runs in a monitored worker
  (reuse `monitored/2`); a read/convert/format failure becomes an `error`/`timeout`
  CSV row, never a hang and never an aborted run (cf. A1-R009/A1S4-18).
- Spec every exported function; keep `warnings_as_errors`, dialyzer, xref clean.

## Ledger

| ID | Criterion | Verify | Significance | Status |
|----|-----------|--------|--------------|--------|
| A1S6-1 | `lfe` added as a **test-profile** dep only; `src/` stays dep-free; `{deps, []}` unchanged | `rebar.config` review; `rebar3 compile` | serious | planned |
| A1S6-2 | `pe_lfe_read:read_file/1 -> {ok,[pe_lfe:form()]} \| {error,term()}` exists with spec | code review; `rebar3 compile` | serious | planned |
| A1S6-3 | Conversion maps atoms→`{sym,_}` (binary), integers→`{int,_}`, tuples→`{tuple,_}`, proper/improper lists→`{call\|list}`/`{dotted_list}`, quote-family heads→`{quote\|bquote\|unquote}` | eunit on small snippets via `lfe_io:read_string/1` | correctness | planned |
| A1S6-4 | Quote-family head atoms confirmed against `lfe_scan`/`lfe_parse` (not guessed) and cited in a comment | code review | serious | planned |
| A1S6-5 | Code-vs-data list position handled: code lists→`{call}`, lists under quote→`{list}`, `()`→`{list,[]}` | eunit | correctness | planned |
| A1S6-6 | Unmodeled leaves (float, binary, map, char, string-ambiguous) hit the printed-text fallback `{sym, print1(Term)}` and **never crash** | eunit feeding each kind; assert no exception | serious | planned |
| A1S6-7 | Bridge round-trips every top-level form of `cl.lfe`, `clj.lfe`, and each `test/*.lfe` without crashing (fallback allowed) | eunit reading via `code:lib_dir(lfe)` | serious | planned |
| A1S6-8 | New bench mode `escript bench/pe_bench lfe-files` exists and is documented | run it | serious | planned |
| A1S6-9 | Per file × width: read+convert and per-form format run in a **monitored worker** with generous timeout; failure→status row, no hang | code review; targeted timeout/error test | serious | planned |
| A1S6-10 | **Headline metric** = whole-file formatter latency = Σ(per-form `format_binary`) at each width; recorded as `fmt_us`. Read+convert time recorded separately as `parse_us` | code review; CSV | serious | planned |
| A1S6-11 | Also record worst single-form time (`worst_form_us`) and its id/index | CSV | polish | planned |
| A1S6-12 | `bench/results/lfe_files.csv` written with header incl. `file,width,status,n_forms,bytes,lines,parse_us,fmt_us,worst_form_us,memo_size,calls,tainted,badness,dag_size` (or justified equivalent); binary fields escaped | CSV inspection; header test | serious | planned |
| A1S6-13 | Widths cover at least 80 and 100 (add 60 if cheap) | CSV row inspection | serious | planned |
| A1S6-14 | Existing bench modes (`lfe-knowledge`, `lfe-stress`, `lfe-refined`) and their CSVs are untouched | `git status`; run a smoke check | serious | planned |
| A1S6-15 | Closing report states these are **latency, not fidelity** numbers; names the conversion approximations (call/list, strings, fallback) and which files needed fallback most | report review | serious | planned |
| A1S6-16 | Zero-warning compile + xref + dialyzer clean | `rebar3 compile`; `rebar3 xref`; `rebar3 dialyzer` | serious | planned |
| A1S6-17 | eunit floor green (bridge + bench tests) | `rebar3 eunit` | serious | planned |
| A1S6-18 | Faithful conversion / comments / spans remain explicitly deferred as A1-R015 | ledger review | correctness | planned |
| A1S6-19 | Single-document (whole-file-as-one-resolve) model deferred or added only as a clearly-labelled secondary row | ledger/CSV review | polish | planned |
| A1S6-20 | OTP 22–29 backport; coverage gate + CAP audit remain explicitly deferred | ledger review | serious | planned |

## Steps

1. **Dep.** Add `{lfe, "~> 2.2"}` (or the version matching Duncan's local
   checkout — confirm) to the `test` profile deps in `rebar.config`. Leave
   top-level `{deps, []}`.

2. **Bridge** `test/pe_lfe_read.erl`:
   - `read_file(Path) -> {ok, [pe_lfe:form()]} | {error, term()}` over
     `lfe_io:read_file/1`.
   - `convert/1 :: term() -> pe_lfe:form()` with a `data`/`code` context flag for
     the call-vs-list rule, and the printed-text fallback as the catch-all clause.
   - Confirm the quote/backquote/comma head atoms from `lfe_scan`/`lfe_parse`;
     cite the source in a comment.

3. **Bench mode** in `test/pe_lfe_bench.erl`: add `run_files/0` and a
   `files-columns`/escape path mirroring the existing `run_stress`/`run_refined`
   structure (reuse `monitored/2`, `escape_csv/1`, `run_to`-style writer). Locate
   inputs via `code:lib_dir(lfe)` (`/src/cl.lfe`, `/src/clj.lfe`, `/test/*.lfe`).
   For each (file, width): inside one monitored worker — read+convert (time it),
   then for each top-level form call `pe_lfe:format_binary/2` and sum the times;
   aggregate memo/calls/tainted/badness; track the worst form. Write
   `bench/results/lfe_files.csv`.

4. **Escript wiring** in `bench/pe_bench`: route `main(["lfe-files"])` →
   `with_lfe_bench(fun pe_lfe_bench:run_files/0)`.

5. **Tests**: `test/pe_lfe_read_tests.erl` — snippet conversions (A1S6-3/5),
   fallback-no-crash for each unmodeled kind (A1S6-6), and a whole-file
   round-trip over the three reference sources (A1S6-7). Plus a monitored
   timeout/error row test for the bench (A1S6-9).

6. **Run + record** on Duncan's MBP:
   `rebar3 eunit && escript bench/pe_bench lfe-files`. Commit the CSV. Paste the
   per-file `fmt_us` (whole-file latency) summary into the closing report.

## Done when

The ledger is row-complete (every row `done`/`deferred`/`no-op`), the new CSV
holds whole-file `fmt_us` for all reference files at the chosen widths, the
engineering gates are green, and the closing report reports the latency numbers
with the fidelity caveat front and centre. Report the commit SHA(s) and the
headline `fmt_us` figures for the running log; CDC (and the still-unpinned bar)
come next.
