# Slice 2: engine-api — ledger

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently. Implementer never marks its own rows CDC-verified. Iteration
> cap: 5. Project `v0.4.0` · arc `arc1-release` · slice `slice2-engine-api`.
> Toolchain rows reconcile via **CI** (no OTP in the CDC sandbox).
> **Naming CONFIRMED (operator, 2026-06-27):** `engine` / `lfmt_engine`.

## Ledger

> CC self-assessment. Base `46240a5` (slice-1 tip); commit `a8edcf8`; branch
> `feature/v0.4.0-release` (worktree `../fmt-v0.4.0-release`). Toolchain rows run
> locally (OTP 28) + "CI reconciles". Every `done` is **proposed-done** until CDC
> reproduces.

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S2-1 | shared options record `#lfmt_opts{engine = fezzik}` + `lfmt:opts()` (opaque) + `lfmt:engine()` types | inspect `src/lfmt.hrl` + `lfmt` exports | serious | slice-doc | done | `src/lfmt.hrl`: `-record(lfmt_opts, {engine = fezzik :: lfmt:engine()})` (single field). `lfmt.erl`: `-opaque opts() :: #lfmt_opts{}`, `-type engine() :: fezzik\|pe\|pc`, `-export_type([opts/0, engine/0])`. | engine-only, no hollow fields |
| A1S2-2 | `lfmt_engine` behaviour with `-callback format(opts(), chardata()) -> {ok,iolist()}\|{error,term()}` | inspect `src/lfmt_engine.erl` | serious | slice-doc | done | `src/lfmt_engine.erl`: `-callback format(lfmt:opts(), unicode:chardata()) -> {ok, iolist()} \| {error, term()}`. | the backend contract |
| A1S2-3 | `lfmt_fezzik` `-behaviour(lfmt_engine)` + implements `format/2`; `format/1` retained | inspect; `dialyzer` behaviour-conformance | serious | slice-doc | done | `lfmt_fezzik.erl` L5 `-behaviour(lfmt_engine)`, exports `format/1, format/2`; `format/1` unchanged. Clean compile (no missing-callback warning) + dialyzer clean = conformance holds. | |
| A1S2-4 | `lfmt:new/1` validation: default fezzik; `pe`/`pc` → `{engine_not_available,E}`; unknown engine → `{unknown_engine,E}`; **unknown option key → `{unknown_option,K}`** | `lfmt_SUITE` cases for each | serious | slice-doc | done | `lfmt_SUITE`: `new_pe_unavailable`/`new_pc_unavailable` (`{engine_not_available,_}`), `new_unknown_engine` (`{unknown_engine,bogus}`), `new_unknown_option` (`{unknown_option,width}`), `new_defaults_fezzik`. All pass. | no-silent-ignore |
| A1S2-5 | `lfmt:format/2` (handle, source) dispatches to the engine; `lfmt:format/1` defaults to fezzik | `lfmt_SUITE` | serious | slice-doc | done | `format2_dispatch` + `format1_default` pass. `format/2` → `engine_module(E):format(Opts, Source)`; `format/1` → `format(new(#{}), Source)`. | |
| A1S2-6 | **parity**: `lfmt:format(lfmt:new(#{engine=>fezzik}), S)` ≡ `lfmt_fezzik:format(S)` over a sample | `lfmt_SUITE` parity test | serious | slice-doc | done | `parity` over 8 inputs (defun/list/quote/map/let/comment/trailing/empty): `lfmt:format(H,S) =:= lfmt_fezzik:format(S)` for all. | API layer changes no output |
| A1S2-7 | **no hollow options**: record's only field is the dispatch selector; `new(#{width=>_})` errors (`unknown_option`) | `lfmt_SUITE` case | serious | scope control | done | `new_unknown_option`: `?assertError({unknown_option, width}, lfmt:new(#{width => 100}))`. `set_opt/3` only accepts `engine`; any other key raises. | honesty at the boundary |
| A1S2-8 | full `ct` green (new `lfmt_SUITE` + existing 274); `compile` zero-warning; `xref` + `dialyzer` clean | `rebar3 ct`/`compile`/`xref`/`dialyzer` | serious | engineering bar | done | `ct` → **All 283 passed** (274 + 9). `compile` zero-warning; `xref` exit 0; `dialyzer` exit 0 (23 files), incl. `lfmt_engine` conformance. | also CI reconciles |
| A1S2-9 | public API exported + doc-commented (`new/1`, `format/1,2`, `opts()`/`engine()`); `pe`/`pc` reserved noted | inspect `lfmt.erl` | serious | slice-doc | done | `-export([new/1, format/1, format/2])` + `-export_type([opts/0, engine/0])`; each function doc-commented; module doc notes `pe`/`pc` reserved (named in `engine()`, `new/1` errors). | stable surface for v0.5.0/v0.6.0 |
| A1S2-10 | engine internals (`lfmt_fezzik_render`/`_util`) untouched; `pe_*`/v0.5.0 untouched; no `0.4.0` tag | `git diff --stat` scoped; `git tag -l 0.4.0` empty | serious | scope control | done | `git diff --stat 46240a5..HEAD -- src/lfmt_fezzik_render.erl src/lfmt_fezzik_util.erl 'src/pe_*.erl' docs/planning/v0.5.0` → **empty**. `git tag -l 0.4.0` → empty. | API layer only |

## Amendments (CC-raised refinements)

_(none — the two design choices below are flagged-but-sanctioned CC choices the
slice-doc explicitly invited, not scope amendments.)_

## Caveats — the two flagged CC choices

1. **`new/1` returns the handle directly and raises on bad input** (a
   constructor), per the slice-doc's stated default. The slice-doc offered
   `{ok,_}|{error,_}` as an alternative "small CC choice — flag it"; I kept the
   raising constructor (bad input to a constructor is a programmer error, and
   `?assertError` testing is clean). `format/*` keeps the engine's tagged
   `{ok,iolist()}|{error,term()}` contract.
2. **`lfmt_fezzik:format/2` normalises `chardata()` → UTF-8 binary before
   delegating to `format/1`**, rather than the slice-doc's bare
   `format(_Opts, Source) -> format(Source)`. Reason: the behaviour callback
   accepts the generic `unicode:chardata()` (right for the multi-engine
   contract + pe/pc), but `format/1`'s real domain is `binary()|string()` (the
   lexer's, which this slice must not touch). A bare delegation would fail
   dialyzer (chardata ⊄ binary()\|string()) or force narrowing the public
   contract. Normalising (`unicode:characters_to_binary/1`, error → `{error,
   {invalid_encoding, _}}`) makes the `chardata()` contract **honest** and
   keeps the engine internals untouched. Behaviour-preserving for all parity
   inputs (binary in → same binary → same output).

## What Worked

- **Tracing the type contract end-to-end before writing the impl.** Checking
  `lfmt_fezzik_lexer:tokens/1`'s real domain (`binary()|string()`) up front
  surfaced the chardata-vs-engine mismatch before it became a dialyzer failure,
  and turned it into a clean, disclosed normalization decision.
- **`engine_module/1` total over `engine()`** (fezzik clause + an
  `engine_not_available` fallback) so the opaque-`opts()` boundary in `format/2`
  stays dialyzer-clean without a defensive sprawl.

## Closure

Self-assessed complete at commit `a8edcf8` (base `46240a5`). Total rows: **10**.
Done: **10**. Deferred: **0**. No-op: **0**. CC self-assessment only — **CDC
verification pending** (`cdc-verification.md`). Sets up `slice3-hex-release`
(package this API in the tarball; vsn → `0.4.0`; publish; tag). CC did **not**
publish or tag.
