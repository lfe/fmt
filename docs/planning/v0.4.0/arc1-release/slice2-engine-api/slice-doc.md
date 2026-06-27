# Slice 2: engine-api

> Project: `v0.4.0`
> Arc: `arc1-release`
> Slice: `slice2-engine-api`
> Status: planned for CC
> Prior: `slice1-split` (CDC-closed) · Next: `slice3-hex-release`

## Purpose

Establish the **multi-engine public API** so it ships in the first release and
the v0.5.0 (pretty-expressive) and v0.6.0 (pretty-canny) engines slot in behind
it without breaking callers. Three pieces: a shared options record, an
`lfmt_engine` **behaviour** (the backend contract), and an `lfmt:new/1` +
`lfmt:format/1,2` dispatch layer. `fezzik` is wired; `pe`/`pc` are reserved
(named in the type, honest error if selected).

## Naming — CONFIRMED (operator, 2026-06-27)

Field **`engine`**, behaviour **`lfmt_engine`**, engine values
`fezzik | pe | pc` → modules `lfmt_fezzik | lfmt_pe | lfmt_pc`. Settled — no
further confirmation needed; implement as written.

## The API (the design)

### Shared options record — `src/lfmt.hrl`

```erlang
-record(lfmt_opts, {engine = fezzik :: lfmt:engine()}).
```

**`engine`-only for 0.4.0** — and that one field is the *real* dispatch selector
(consumed by `lfmt:format/2`, not silently ignored), so the record has **zero
hollow options**. It's the shared, extensible container: `width`, `indent`, etc.
get added **when an engine actually consumes them** (pe is width-native → likely
v0.5.0). Until then, `new/1` *rejects* unknown option keys (below) so no option
is ever silently dropped.

### The behaviour — `src/lfmt_engine.erl`

```erlang
-module(lfmt_engine).
-callback format(lfmt:opts(), unicode:chardata()) ->
    {ok, iolist()} | {error, term()}.
```

Every engine module implements `format/2` (opts-first, matching the handle-first
public API). This is the contract `lfmt_pe`/`lfmt_pc` will implement later.

### The dispatch — `src/lfmt.erl` (currently an empty stub)

```erlang
-module(lfmt).
-include("lfmt.hrl").
-export([new/1, format/1, format/2]).
-export_type([opts/0, engine/0]).

-type engine() :: fezzik | pe | pc.
-opaque opts()  :: #lfmt_opts{}.

-spec new(map()) -> opts().
%% builds + validates; returns the opaque formatter handle.
%%   unknown engine          -> error({unknown_engine, E})
%%   reserved (pe|pc)         -> error({engine_not_available, E})
%%   unknown option key       -> error({unknown_option, K})   % no hollow opts
new(Map) -> ...

-spec format(opts(), unicode:chardata()) -> {ok, iolist()} | {error, term()}.
format(#lfmt_opts{engine = E} = Opts, Source) ->
    (engine_module(E)):format(Opts, Source).

-spec format(unicode:chardata()) -> {ok, iolist()} | {error, term()}.
format(Source) -> format(new(#{}), Source).   % default engine = fezzik

engine_module(fezzik) -> lfmt_fezzik.          % only fezzik mapped at 0.4.0
```

`new/1` returns the handle directly and **raises** on invalid input (a
constructor; bad input is a programmer error). `format/*` keeps the engine's
tagged `{ok, iolist()} | {error, term()}` contract. (If you'd rather `new/1` be
`{ok,_}|{error,_}`, that's a small CC choice — flag it.)

### Fezzik implements the behaviour — `src/lfmt_fezzik.erl`

```erlang
-behaviour(lfmt_engine).
-export([format/1, format/2, regime/2]).
format(Source) -> ...                     % unchanged back-compat entry
format(_Opts, Source) -> format(Source).  % behaviour impl; 0.4.0 opts carry only
                                          % `engine` (the selector), so no fezzik
                                          % param to read yet — NOT hollow
```

`format/1` stays (back-compat + what `format/2` delegates to). When `width`
lands, `format/2` will read `Opts#lfmt_opts.width`.

## Scope

In scope: the record (hrl), the `lfmt_engine` behaviour, the `lfmt` dispatch
(`new/1` + `format/1,2` + `engine_module/1`), `lfmt_fezzik` behaviour
conformance, and a new `lfmt_SUITE`. Out of scope: **any change to the engine
internals** (`lfmt_fezzik_render`/`_util` — untouched); `width`/other options;
`pe`/`pc` implementations; hex publish (slice 3); `rebar3_lfe` (slice 4).

## Dependency / base

`feature/v0.4.0-release` after slice 1 (routes to the split `lfmt_fezzik`).

## Success criteria (gate)

- `#lfmt_opts{engine}` record + `lfmt:opts()`/`engine()` types; `lfmt_engine`
  behaviour with `-callback format/2`.
- `lfmt_fezzik` declares `-behaviour(lfmt_engine)` and implements `format/2`;
  `format/1` retained; **Dialyzer behaviour-conformance passes**.
- `lfmt:new/1` validates: default `fezzik`; `pe`/`pc` → `{engine_not_available}`;
  unknown engine → `{unknown_engine}`; **unknown option key → `{unknown_option}`**
  (proves no silent-ignore).
- `lfmt:format/2` (handle, source) dispatches to `lfmt_fezzik`; `lfmt:format/1`
  defaults to fezzik.
- **Parity:** `lfmt:format(lfmt:new(#{engine=>fezzik}), S)` ≡
  `lfmt_fezzik:format(S)` over a sample corpus (the API layer changes no output).
- `lfmt_SUITE` covers the above; full `ct` green (new suite + existing 274);
  `compile` zero-warning; `xref` + `dialyzer` clean.
- Engine internals (`lfmt_fezzik_render`/`_util`) untouched; `pe_*`/v0.5.0
  untouched; no `0.4.0` tag.

## Handoff

CC provides: the record + behaviour + dispatch + Fezzik conformance + `lfmt_SUITE`;
the parity evidence; green ct/compile/xref/dialyzer; a per-row ledger walk +
`closing-report.md`. This makes the public API real for slice 3 to package and
slice 4 to consume.
