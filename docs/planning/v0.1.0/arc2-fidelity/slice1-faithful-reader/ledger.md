# arc2 / slice1: faithful reader

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A2S1-1 | `form()` += `{float,_}`,`{binary,_}`,`{map,_}`,`{splice,_}` (**not** `{char}` — amended, see below); strings stay `{str,_}`, not collapsed | code review; compile | serious | slice1 spec | done (amended) | `pe_lfe:form()` gains the four; `{str,binary()}` retained. `{char}` dropped (operator 2026-06-25): in LFE a char *is* an int, so `lfe_io` cannot produce it; `{splice}` added for faithful `,@' (21× in corpus). See Amendments | char→int amendment |
| A2S1-2 | each new constructor renders correctly (`#"…"`/`#B(…)`, `#M(…)`, canonical float, `,@`) | eunit golden per kind | correctness | losslessness | done | `pe_lfe_literal_tests` (11): float `float_to_binary/2 [short]`; binary printable→`#"…"`, bytes→`#B(…)`, empty→`#B()`; map `#M(k v …)`; splice `,@x`; `{str}`/binary escaping — each asserts re-read equality | |
| A2S1-3 | new constructors break neither existing lowering nor slice9 registry dispatch | full eunit; registry tests | serious | regression safety | done | `rebar3 eunit` 351/0 incl. the slice9 byte-identical 80-row baseline (`pe_lfe_registry_tests`) — `render_symbol` leaves all 20 samples unchanged | |
| A2S1-4 | `pe_lfe_read` converts all leaf+compound kinds to exact `form()` | eunit via `read_string/1` | correctness | reader | done | `pe_lfe_read_tests` (26): leaves, calls, tuples, dotted, quote-family+splice, code-vs-data, faithful float/binary/map/str, mixed | |
| A2S1-5 | no fallback/genericisation — unmodeled term → `{unmodeled_construct,_}` | eunit | serious | fidelity boundary | done | `convert/2` `Other` clause raises; `fallback/1` deleted; `unmodeled_construct_errors_test` (fun, pid). `safe_format_binary` retained as bench-only latency tooling, not on the faithful path | contrast slice6 `safe_*` net |
| A2S1-6 | top-level line captured from `parse_file/1` `{Sexpr,Line}` | eunit | polish | positions | done | `read_forms/1` returns `[{form(), Line}]`; `read_forms_captures_line_test` | |
| A2S1-7 | quote-family head atoms confirmed vs `lfe_parse`/`lfe_scan`, cited | code review | serious | correctness over guessing | done | reader module doc cites `lfe_parse` reductions 7–10 (incl. `,@`→`['comma-at',X]`→`{splice}`); `render_symbol` replicates `lfe_io_write:quote_symbol/2` + `lfe_scan:{start_,}symbol_char/1` (cited), verified against LFE as oracle | |
| A2S1-8 | AST round-trip `read(format(F)) =:= F` over examples/*.lfe + test/*.lfe + cl/clj | eunit over `code:lib_dir(lfe)` | correctness | the gate | done | `pe_lfe_roundtrip_tests:corpus_round_trip_test_` — **739/739 forms structurally equal** | slice7-style invariance |
| A2S1-9 | 0 `unmodeled_construct` across the corpus | round-trip run | serious | completeness | done | audit reports **0 unmodeled** across all corpus files | |
| A2S1-10 | formatted output is valid re-readable LFE | round-trip run (re-read succeeds) | serious | validity | done | implied by A2S1-8 (re-read of every form succeeds and matches) | |
| A2S1-11 | cheap idempotence spot-check (full suite = slice3) | eunit | polish | preview | done | `idempotence_spot_check_test` — `format∘format == format` on every church.lfe form | |
| A2S1-12 | `lfe` stays test-profile; engine zero-runtime-dep; no runtime flip | `rebar.config` review | serious | dep posture | done | `{deps, []}` unchanged; `lfe` under `test` profile; `render_symbol` replicates LFE's grammar in-tree rather than calling `lfe_io`, so `src/` stays dep-free | runtime flip is later/operator-gated |
| A2S1-13 | zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | engineering bar | done | `rebar3 compile` (warnings-as-errors) clean; `xref` clean; `dialyzer` rc=0 | |
| A2S1-14 | eunit floor green | `rebar3 eunit` | serious | engineering bar | done | 351/0; proper 8/8; ct 2/2 | |
| A2S1-15 | comments + intra-form spans deferred to slice2 | ledger review | correctness | deferred | done | reader module doc states the boundary; char/string *surface syntax* (`#\`/`"`) also deferred to the slice2 token layer | re-entry: slice2 comment-fidelity |

## Amendments

- **A2S1-1/2 — `{char}` dropped; `{splice}` added (operator decision 2026-06-25).**
  Census + probe showed `lfe_io` (the reader this slice is scoped to) reads a
  character `#\x` as its **integer** and a string `"…"` as a **char-list** —
  inherent LFE/Lisp semantics, so the `#\`/`"` *surface syntax* is not
  recoverable here (it needs the slice2 token/span layer). The corpus contains
  **0** chars. So `{char}` is not added; a char reads as an int and renders as an
  int (value-faithful, round-trips). Conversely `,@` (comma-at, **21×** in the
  corpus) *is* distinguishable and slice6 dropped its `@`, so a faithful
  `{splice}` node was added (sanctioned by the scope fence's "new leaf styles may
  need a palette entry — record it"). Strings remain a proper `{str, binary()}`
  leaf via a printable-list heuristic (not slice6's printed-text hack).
- **`pe_lfe` robustness (knowledge-layer, not engine):** `block`/`block_doc` now
  handle an empty body (`(head)` with no body) — a `case` whose clause list is
  empty, as `try`'s `(case …)` section reads. Previously `join_nl([])` crashed;
  slice6's `safe_format_binary` net hid it. Engine (`pe_*`) untouched.

## Caveat Checklist (closure)

- **New `form()` constructors + rendering:** `{float}`→`float_to_binary/2 [short]`
  (shortest round-trippable); `{binary}`→`#"…"` if printable-ASCII else
  `#B(byte …)` (empty→`#B()`); `{map}`→`#M(k v …)`; `{splice}`→`,@x`. Symbols
  `|…|`-quoted per LFE's grammar when bare would not re-read.
- **Corpus round-trip:** 739 / 739 forms; `unmodeled_construct` count **0**.
- **New palette style forced:** none — the four constructors are leaves/prefixes
  reusing existing combinators; no new `apply_style` clause or registry rule.
- **Float-printing choice:** `float_to_binary(F, [short])`; round-trip proven by
  `float_reads_back_equal_test` and the corpus (~222 floats).
- **Idempotence spot-check:** `format∘format == format` holds on every
  church.lfe form.
- **Deferred to slice2:** comments, intra-form source spans, and the `#\`/`"`
  surface syntax for chars/strings (value-faithful here, syntax-faithful later).

## Closure

Closed at commit: _pending_.
CDC verification: _pending_.
