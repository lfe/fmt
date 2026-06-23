# Slice 3: LFE knowledge layer

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S3-1 | `pe_lfe` exists in `src/` with exported `form()` type plus `to_doc/1`, `to_doc/2`, `format/2`, and `format_binary/2` | code review; `rebar3 compile` | serious | slice3 spec | done | `src/pe_lfe.erl`; exact surface; compile clean | |
| A1S3-2 | `pe_lfe` represents source-like symbols as binaries and does not mint atoms from input | code review for `list_to_atom` / `binary_to_atom`; eunit symbol tests | serious | Erlang safety / API design | done | `no_atom_minting_test` (binary_to_existing_atom raises before+after); `no_dynamic_atom_calls_in_source_test` greps src clean | |
| A1S3-3 | exported `pe_lfe` functions have specs and dialyzer-clean contracts | code review; `rebar3 dialyzer` | serious | Erlang tooling | done | specs on all exports; dialyzer 15 files clean | |
| A1S3-4 | generic fallback formats ordinary calls, proper lists, dotted lists, tuples, strings, integers, and symbols | `rebar3 eunit --module=pe_lfe_tests` | correctness | knowledge layer | done | `leaves_test`/`generic_call_test`/`list_tuple_test`/`dotted_list_test` | |
| A1S3-5 | quote, backquote, and unquote lower as prefix forms without adding unwanted spaces | eunit golden/structural tests | correctness | LFE syntax | done | `prefix_forms_test`: `'foo`/`` `foo``/`,foo`/`` `#(a ,b)`` | |
| A1S3-6 | `defun` and `defmacro` rules format names on the head line and clauses vertically | eunit golden tests, including Ackermann | serious | LFE usefulness | done | `ackermann_golden_test` (exact); defmacro via `lfe_05`/`lfe_06` renders | |
| A1S3-7 | clause formatting supports pattern heads, guard-like first body forms, and multiple body forms | eunit tests over sample clauses | correctness | LFE usefulness | done | `lfe_03`/`lfe_04` guards, `lfe_11`/`lfe_16` multi-body clauses render (samples_render tests) | |
| A1S3-8 | `lambda` and `match-lambda` rules format body/clause structures vertically | eunit tests from samples | correctness | LFE usefulness | done | `lfe_14` lambda, `lfe_08` match-lambda render vertically (samples_render tests) | |
| A1S3-9 | `let`-family binding shapes represented in the corpus format without generic rightward drift | eunit structural/golden tests | serious | LFE usefulness | done | `let_vertical_test`: binding on head line, body nested at indent 2 | |
| A1S3-10 | `case`, `receive`, and `cond` rules format clauses as readable vertical blocks | eunit golden/structural tests | serious | LFE usefulness | done | `case_vertical_test`/`receive_vertical_test`/`cond_vertical_test` | |
| A1S3-11 | `progn` and `eval-when-compile` format bodies as blocks | eunit golden/structural tests | serious | slice2 caveat | done | `eval_when_compile_block_test`; `lfe_12` progn renders as block | |
| A1S3-12 | `lfe_07_bq_expand` no longer aligns the nested `defun` body as a generic second argument | targeted test on rendered output and/or max indent | serious | running recommendation A1-R006 | done | `eval_when_compile_block_test`: `  (defun bq-expand` at indent 2; `max_indent ≤ 16` | |
| A1S3-13 | `pe_lfe:format/2` and `format_binary/2` delegate through the existing `pe` facade and preserve resolver option overrides | eunit facade tests | serious | API behavior | done | `facade_delegates_test`/`facade_width_override_test` (width 8 breaks) | |
| A1S3-14 | `pe_lfe_samples` keeps the 20 stable ids, labels, sources, and tags from slice2 | `rebar3 eunit --module=pe_lfe_samples_tests` | correctness | corpus continuity | done | `sample_count_test`=20; `sample_ids_test` exact; `sample_metadata_test` | |
| A1S3-15 | `pe_lfe_samples` stores LFE `form()` terms and `build/1` lowers through `pe_lfe:to_doc/1` | code review; eunit `form/1` / build tests | serious | slice3 spec | done | `form_accessor_test` (build == to_doc(form)); `all_forms_are_terms_test` | |
| A1S3-16 | old fixture-only document-builder knowledge is not left as a competing layout layer in `pe_lfe_samples` | code review | serious | scope control | done | `pe_lfe_samples` holds only `form()` sugar (sym/call/…); lowering lives in `pe_lfe` | |
| A1S3-17 | all 20 samples resolve and render deterministically at widths 80 and 100 | eunit sample render/determinism tests | correctness | viability | done | `samples_render_width_80/100_test`, `samples_deterministic_test` | |
| A1S3-18 | Ackermann renders in the expected compact multi-clause shape at width 80 | eunit golden test | correctness | user-provided canary | done | `ackermann_golden_test` (byte-exact 4-line shape) | |
| A1S3-19 | at least one `case`, one `receive`, one `cond`, and one `let` sample has targeted layout evidence | eunit golden/structural tests | serious | knowledge-layer coverage | done | `case_vertical`/`receive_vertical`/`cond_vertical`/`let_vertical`/`receive_after` tests | |
| A1S3-20 | benchmark emits `bench/results/lfe_knowledge.csv` with `id,label,width,time_us,memo_size,calls,tainted,badness,height,bytes,lines` | run benchmark; inspect header and row count | serious | viability evidence | done | `escript bench/pe_bench lfe-knowledge`; header exact; 61 lines | |
| A1S3-21 | benchmark covers all 20 samples at widths 80 and 100, and optionally 60 if added | CSV row count and stdout table | serious | viability evidence | done | widths 80/100/60 → 60 rows; `knowledge_row_count_test`=60 | |
| A1S3-22 | benchmark timing workers cannot hang the parent on crash | code review `spawn_monitor` or equivalent; failure-mode test if practical | serious | running recommendation A1-R009 | done | `run_once/1` uses `spawn_monitor`; worker crash → `{bench_worker_crashed, _}` error, never a hang | |
| A1S3-23 | CSV writer handles binary fields with commas/quotes/newlines if benchmark metadata remains CSV | eunit CSV escaping test or explicit no-op rationale | correctness | running recommendation A1-R012 | done | `escape_csv/1` (quote + double inner quotes); `csv_escaping_test` | |
| A1S3-24 | slice3 closing report summarizes stable counters and names any awkward, heavily-tainted, or slow sample without drawing the final viability conclusion | closing report review | serious | methodology | done | see Caveat Checklist + closing report | |
| A1S3-25 | zero-warning compile + xref + dialyzer clean | `rebar3 compile`; `rebar3 xref`; `rebar3 dialyzer` | serious | engineering bar | done | compile zero-warning; xref clean; dialyzer 15 files clean | |
| A1S3-26 | unit/integration/property floor green | `rebar3 eunit`; `rebar3 ct` if CT is used; `rebar3 proper` if PropEr is present/added | serious | engineering bar | done | 104 eunit + 5 PropEr + 2 CT, 0 failures | |
| A1S3-27 | OTP 22-29 compatibility remains explicitly deferred if not handled | ledger review | polish | deferred from arc | deferred | | re-entry: backport slice |
| A1S3-28 | coverage gate + CAP strength audit remains explicitly deferred if not handled | ledger review | serious | deferred from arc | deferred | | re-entry: post-slice strength-analysis phase |

## Amendments (CC refinements, recorded before closure)

1. **Term model adopted verbatim.** `form()` is exactly the suggested vocabulary
   (`sym`/`str`/`int`/`quote`/`bquote`/`unquote`/`list`/`dotted_list`/`tuple`/
   `call`), symbols and strings as binaries. No refinement was needed.
2. **`to_doc/2` options.** The map is lowering options — currently just
   `indent` (body step, default 2). `format/2`/`format_binary/2` take the
   *resolver* options map (passed through to the `pe` facade) and lower with
   defaults; callers wanting custom lowering use `to_doc/2` + `pe:format/2`.
3. **Dispatch set.** Special-form rules: `defun`/`defmacro` (single- and
   multi-clause), `lambda`, `match-lambda`, `let`/`let*`/`flet`/`fletrec`,
   `case`, `receive` (with `after`), `cond`, `progn`, `eval-when-compile`.
   `if` and other heads fall through to the generic S-expression rule (aligned
   args). This covers every special form in the corpus.
4. **Slice2 interpreter removed.** The slice2 fixture document-builder is gone
   from `pe_lfe_samples`; the only local helpers there are trivial `form()`
   constructors (sym/call/lst/…). All layout lives in `pe_lfe` (A1S3-16).
5. **Opportunistic cleanups (from running-recommendations).** `run_once/1`
   hardened with `spawn_monitor` (A1-R009); CSV writer escapes binary fields
   (A1-R012); `count_char/2` rewritten as a binary fold instead of a
   list-comprehension count (A1-R010).

## Caveat Checklist (closure)

- **Samples that still render somewhat awkwardly** (all `badness = 0`; these are
  generic-fallback cases a fuller knowledge layer would refine, not engine
  faults):
  - `lfe_08_ets_new` — `(lists:foreach (match-lambda …) (default-places))`
    aligns the `match-lambda` under the `lists:foreach` argument column, so its
    body drifts right. A special form passed as a *call argument* still gets
    generic alignment.
  - `lfe_20_eval_receive` — a `fletrec` function-definition binding
    `(loop (q) (receive …))` renders via the generic list rule, putting `(q)`
    and the `receive` on separate indented lines. `fletrec`/`flet` bindings are
    not yet given clause-like layout.
  - `lfe_09`/`lfe_10` — backquoted data lists align under the enclosing call
    argument (mild rightward drift); acceptable for data literals.
- **Taint / badness:** `badness = 0` for all 60 rows (widths 80/100/60) — every
  form finds a fitting layout, so the all-tainted `optimal/1` path (A1-R001) is
  never hit. `tainted` counts (pruned over-wide sub-layouts, not failures) run
  up to ~150 (highest: `lfe_16_account`, `lfe_07_bq_expand`). Block layouts
  raise `tainted` vs slice2 because they introduce more `nl`-bearing structure
  to explore; this is search bookkeeping, not output overflow.
- **Width 60:** ADDED to the knowledge benchmark (stayed cheap; all `badness = 0`).
- **CSV escaping:** IMPLEMENTED (`escape_csv/1`) and tested, though current
  labels are comma-free, so it is presently a latent guarantee.
- **Parser/source-preservation:** NONE. This slice does not parse `.lfe`, does
  not preserve comments or source spans, and does not guarantee source fidelity.
  Forms are hand-built `pe_lfe:form()` terms; rendered output is a canonical
  shape. Do not infer source-preserving formatting from this slice (A1-R011).

## Closure

Closed at commit `<slice3 SHA>` on 2026-06-22. CDC verification: pending
(operator-run). Total rows: 28. Done: 26. Deferred: 2 (A1S3-27 OTP 22–29
backport; A1S3-28 coverage gate + CAP audit). No-op: 0.

Key rendered evidence (width 80):

```
(defun ackermann
  ((0 n) (+ n 1))
  ((m 0) (ackermann (- m 1) 1))
  ((m n) (ackermann (- m 1) (ackermann m (- n 1)))))

(eval-when-compile
  (defun bq-expand
    ((exp n)
      (case exp
        ((tuple 'unquote e)
          (when (> n 0))
          (tuple 'unquote (bq-expand e (- n 1))))
        ((tuple 'unquote e) e)
        ((cons 'backquote x) (bq-expand-list exp (+ n 1)))
        (x (bq-expand-list x n))))))
```

