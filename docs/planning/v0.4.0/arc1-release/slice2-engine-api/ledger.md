# Slice 2: engine-api — ledger

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently. Implementer never marks its own rows CDC-verified. Iteration
> cap: 5. Project `v0.4.0` · arc `arc1-release` · slice `slice2-engine-api`.
> Toolchain rows reconcile via **CI** (no OTP in the CDC sandbox).
> **Naming CONFIRMED (operator, 2026-06-27):** `engine` / `lfmt_engine`.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S2-1 | shared options record `#lfmt_opts{engine = fezzik}` + `lfmt:opts()` (opaque) + `lfmt:engine()` types | inspect `src/lfmt.hrl` + `lfmt` exports | serious | slice-doc | open | | engine-only (no hollow fields) |
| A1S2-2 | `lfmt_engine` behaviour with `-callback format(opts(), chardata()) -> {ok,iolist()}\|{error,term()}` | inspect `src/lfmt_engine.erl` | serious | slice-doc | open | | the backend contract |
| A1S2-3 | `lfmt_fezzik` `-behaviour(lfmt_engine)` + implements `format/2`; `format/1` retained | inspect; `dialyzer` behaviour-conformance | serious | slice-doc | open | | Dialyzer flags missing callbacks |
| A1S2-4 | `lfmt:new/1` validation: default fezzik; `pe`/`pc` → `{engine_not_available,E}`; unknown engine → `{unknown_engine,E}`; **unknown option key → `{unknown_option,K}`** | `lfmt_SUITE` cases for each | serious | slice-doc | open | | the no-silent-ignore guarantee |
| A1S2-5 | `lfmt:format/2` (handle, source) dispatches to the engine; `lfmt:format/1` defaults to fezzik | `lfmt_SUITE` | serious | slice-doc | open | | |
| A1S2-6 | **parity**: `lfmt:format(lfmt:new(#{engine=>fezzik}), S)` ≡ `lfmt_fezzik:format(S)` over a sample | `lfmt_SUITE` parity test over a corpus sample | serious | slice-doc | open | | the API layer changes no output |
| A1S2-7 | **no hollow options**: record's only field is the dispatch selector; `new(#{width=>_})` errors (`unknown_option`) | `lfmt_SUITE` case | serious | scope control | open | | enforces honesty at the API boundary |
| A1S2-8 | full `ct` green (new `lfmt_SUITE` + existing 274); `compile` zero-warning; `xref` + `dialyzer` clean | `rebar3 ct`/`compile`/`xref`/`dialyzer` | serious | engineering bar | open | | CI reconciles |
| A1S2-9 | public API exported + doc-commented (`new/1`, `format/1,2`, `opts()`/`engine()`); `pe`/`pc` reserved noted | inspect `lfmt.erl` | serious | slice-doc | open | | the stable surface for v0.5.0/v0.6.0 |
| A1S2-10 | engine internals (`lfmt_fezzik_render`/`_util`) untouched; `pe_*`/v0.5.0 untouched; no `0.4.0` tag | `git diff --stat` scoped; `git tag -l 0.4.0` empty | serious | scope control | open | | this slice adds an API layer, not engine changes |

## Amendments (CC-raised refinements)

_(none yet)_

## Caveats

_(CC fills at close — esp. the final `new/1` return style if it deviated, and
any naming swap.)_

## What Worked

_(CC fills at close.)_

## Closure

_(CC fills at close: commit SHA(s), ledger SHA, totals. CDC verification in
`cdc-verification.md`.)_
