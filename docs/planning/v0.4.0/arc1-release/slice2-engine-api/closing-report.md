# Slice 2: engine-api — closing report

> CC closing report (implementer self-assessment). Independent verification is
> CDC's, in `cdc-verification.md` (not yet written). Every `done` is
> **proposed-done** until CDC reproduces it (toolchain rows via CI).
> Project `v0.4.0` · arc `arc1-release` · slice `slice2-engine-api`.
> Base `46240a5` (slice-1 tip); commit `a8edcf8`; branch `feature/v0.4.0-release`
> (worktree `../fmt-v0.4.0-release`).

## Per-row walk

10 rows at open; **10 walked** (no silent drops; matches `ledger.md`). Summary
per row; full evidence in `ledger.md`.

| ID | Status | Evidence (summary) |
|----|--------|--------------------|
| A1S2-1 | done | `#lfmt_opts{engine=fezzik}` (hrl); `lfmt:opts()` opaque + `engine()` types, exported. |
| A1S2-2 | done | `lfmt_engine` `-callback format(lfmt:opts(), unicode:chardata()) -> {ok,iolist()}\|{error,term()}`. |
| A1S2-3 | done | `lfmt_fezzik` `-behaviour(lfmt_engine)` + `format/2`; `format/1` retained; conformance clean. |
| A1S2-4 | done | `lfmt_SUITE`: default fezzik; pe/pc→`engine_not_available`; bogus→`unknown_engine`; width→`unknown_option`. |
| A1S2-5 | done | `format2_dispatch` + `format1_default` pass. |
| A1S2-6 | done | `parity` over 8 inputs: `lfmt:format(H,S) =:= lfmt_fezzik:format(S)`. |
| A1S2-7 | done | `new(#{width=>100})` → `{unknown_option, width}` (no hollow opts). |
| A1S2-8 | done | ct **283** passed; compile zero-warning; xref + dialyzer clean. |
| A1S2-9 | done | API exported + doc-commented; pe/pc reserved noted. |
| A1S2-10 | done | render/util + pe/v0.5.0 diff empty; no `0.4.0` tag. |

**Totals: 10 done · 0 deferred · 0 no-op.** All **reproduced** locally
(toolchain also "CI reconciles"). No amendments; two flagged CC choices below.

## Bubble-up to the arc (arc1-release)

### 1. Did slice 2 deliver the piece of the arc's capability the arc-plan assigned it?

Yes. The arc-plan slice-2 row: *the multi-engine public API — `#lfmt_opts{engine}`,
the `lfmt_engine` behaviour, `lfmt:new/1` + `format/1,2` dispatch, `lfmt_fezzik`
implementing the behaviour; fezzik wired, pe/pc reserved (honest error); no hollow
options; dialyzer behaviour conformance; ct green.* All delivered, as a thin
layer with the engine internals (`lfmt_fezzik_render`/`_util`) **untouched**.

### Final API surface

```erlang
%% src/lfmt.hrl
-record(lfmt_opts, {engine = fezzik :: lfmt:engine()}).   % engine-only, real selector

%% src/lfmt_engine.erl  (behaviour)
-callback format(lfmt:opts(), unicode:chardata()) -> {ok, iolist()} | {error, term()}.

%% src/lfmt.erl  (public API)
-opaque opts()  :: #lfmt_opts{}.
-type   engine() :: fezzik | pe | pc.
new(map())                         -> opts().      % validates; raises on bad input
format(opts(), unicode:chardata()) -> {ok,iolist()}|{error,term()}.   % dispatch
format(unicode:chardata())         -> {ok,iolist()}|{error,term()}.   % default fezzik

%% src/lfmt_fezzik.erl
-behaviour(lfmt_engine).  format/1 (back-compat) + format/2 (callback).
```

`new/1` errors: `unknown_engine` / `engine_not_available` (pe|pc) / `unknown_option`.

### 2. What did implementing this slice reveal — the two flagged CC choices

Both are choices the slice-doc explicitly invited; neither changes scope or the
engine:

- **`new/1` raises (constructor), not `{ok,_}|{error,_}`** — the slice-doc's
  stated default, kept (the slice-doc offered the tagged-return as a flaggable
  alternative). Bad input to a constructor is a programmer error.
- **`format/2` normalises `chardata()` → UTF-8 binary before delegating to
  `format/1`** (not the slice-doc's bare `format(Source)`). The behaviour
  rightly accepts generic `unicode:chardata()` (for pe/pc), but `format/1`'s
  domain is `binary()|string()` (the lexer's, untouchable this slice). Bare
  delegation would either fail dialyzer or force narrowing the public contract;
  normalising makes the `chardata()` contract honest, dialyzer-clean, and
  engine-internals-untouched. Behaviour-preserving (parity green).

### 3. The silent-drop diff at slice scale

- **Specified → delivered:** record + opaque types ✓; behaviour ✓; `new/1`
  validation incl. unknown-option ✓; `format/1,2` dispatch ✓; parity ✓; fezzik
  conformance ✓; `lfmt_SUITE` ✓; ct/compile/xref/dialyzer green ✓; internals +
  pe/v0.5.0 untouched ✓; no `0.4.0` tag ✓.
- **Disclosed CC choices:** the two above (flagged, not dropped).
- **Silent drops: none.**

## Slice-close arc-plan update

Part-IV question — *did slice 2 uncover anything that should change
`arc-plan.md`?* The arc's slice breakdown (split → engine-api → publish →
integrate) stands. One packaging note for slice 3: the hex tarball must now
include `src/lfmt.erl`, `src/lfmt_engine.erl`, **`src/lfmt.hrl`**, and the
`src/lfmt_fezzik*.erl` + `src/lfmt_fezzik.hrl` set. Recorded in `arc-plan.md`
Version History. No re-sequencing.

## Open items for CDC / operator

- **`cdc-verification.md` pending** — reproduce `lfmt_SUITE` (validation +
  parity), the behaviour conformance (clean dialyzer), and the
  internals-untouched diff.
- **Ratify the two flagged CC choices** (raising `new/1`; chardata
  normalization in `format/2`).
- **No `CLAUDE.md`** still records the layout/close-set convention (carried since
  v0.1.0) — raised, not created unilaterally.
- Next: `slice3-hex-release` (vsn → `0.4.0`, full metadata + hrls in the
  tarball, `rebar3 hex publish`, tag `0.4.0`) — publish/tag reserved for it +
  arc close.
