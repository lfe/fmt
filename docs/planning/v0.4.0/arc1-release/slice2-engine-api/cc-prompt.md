# CC prompt — fmt v0.4.0 · arc1-release / slice2-engine-api

You are CC. Build the **multi-engine public API** so it ships in 0.4.0 and the
v0.5.0/v0.6.0 engines slot in behind it: a shared options record, an
`lfmt_engine` **behaviour**, and `lfmt:new/1` + `lfmt:format/1,2` dispatch, with
`lfmt_fezzik` implementing the behaviour. **Do not touch the engine internals**
(`lfmt_fezzik_render`/`_util`) — this is a thin API layer on top. You run `git`
+ the toolchain directly.

Target OTP 28. Load **collaboration-framework** (ledger discipline) and
**erlang-guidelines** (`02-api-design` first, then `01-core-idioms`,
`04-data-and-types`, `15-testing`).

## Naming — confirmed

Field/behaviour name is **confirmed** (operator, 2026-06-27): **`engine`** /
**`lfmt_engine`**, values `fezzik|pe|pc`. Implement as written — no need to ask.

## Read first

- `docs/planning/v0.4.0/project-plan.md` and `arc1-release/arc-plan.md`.
- This slice's `slice-doc.md` (the full API design) and `ledger.md`.

## Base

`feature/v0.4.0-release` after slice 1 (the split: `lfmt_fezzik` + `_render` +
`_util` + `.hrl`).

## Build (per the slice-doc design)

1. **`src/lfmt.hrl`** — `-record(lfmt_opts, {engine = fezzik :: lfmt:engine()}).`
   Engine-only — it's the real dispatch selector, **no hollow fields**.
2. **`src/lfmt_engine.erl`** — behaviour:
   `-callback format(lfmt:opts(), unicode:chardata()) -> {ok,iolist()}|{error,term()}`.
3. **`src/lfmt.erl`** (replace the empty stub) — `-include("lfmt.hrl")`;
   `-type engine() :: fezzik|pe|pc`; `-opaque opts() :: #lfmt_opts{}`;
   `-export([new/1, format/1, format/2])` + `-export_type([opts/0, engine/0])`.
   - `new/1`: map → opaque handle; **validate** — default `fezzik`; `pe`/`pc` →
     `error({engine_not_available, E})`; unknown engine → `error({unknown_engine, E})`;
     **unknown option key → `error({unknown_option, K})`** (so nothing is silently
     ignored). Returns the handle directly (constructor; raises on bad input).
   - `format/2` (handle, source) → `(engine_module(E)):format(Opts, Source)`.
   - `format/1` (source) → `format(new(#{}), Source)`.
   - `engine_module(fezzik) -> lfmt_fezzik` (only fezzik at 0.4.0).
4. **`src/lfmt_fezzik.erl`** — add `-behaviour(lfmt_engine)` + `format/2`:
   `format(_Opts, Source) -> format(Source).` Keep `format/1` (back-compat).
   Do **not** change the engine logic.

## Tests — `test/lfmt_SUITE.erl`

- `new(#{})` defaults to fezzik; `new(#{engine=>fezzik})` ok.
- `new(#{engine=>pe})` / `pc` → `{engine_not_available, _}`; `new(#{engine=>bogus})`
  → `{unknown_engine, _}`; `new(#{width=>100})` → `{unknown_option, width}`.
- `format/2` dispatches; `format/1` defaults.
- **Parity:** for a sample of inputs, `lfmt:format(lfmt:new(#{engine=>fezzik}), S)`
  equals `lfmt_fezzik:format(S)` (the API layer changes no output).

## Engineering bar

- `rebar3 ct` green (new `lfmt_SUITE` + existing 274); `compile` zero-warning;
  `xref` clean; `dialyzer` clean **including `lfmt_engine` behaviour conformance
  for `lfmt_fezzik`**. (CI reconciles.)
- `git diff --stat` shows **no** change to `lfmt_fezzik_render.erl` /
  `lfmt_fezzik_util.erl` (engine internals untouched); `pe_*` + `docs/planning/
  v0.5.0` untouched; `git tag -l 0.4.0` empty.

## Working ledger + close

Update `ledger.md` per-row (toolchain rows note "CI reconciles"). At close write
`closing-report.md`: per-row walk + bubble-up (final API surface; any naming or
`new/1`-return-style deviation; confirm engine internals untouched). Don't mark
your own rows CDC-verified. Sets up slice 3 (hex-release packages this API).
