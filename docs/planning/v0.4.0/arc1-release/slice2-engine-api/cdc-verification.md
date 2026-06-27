# CDC verification — v0.4.0 · arc1-release / slice2-engine-api

Verifier: Claude (Cowork chat seat, acting as CDC — independent of CC).
Date: 2026-06-27.
Reviewed: branch `feature/v0.4.0-release`; slice commit `a8edcf8` (base = slice-1
tip).

## Verification boundary

Reproduced (source/git) the API surface, validation, scope, and the parity
*mechanism*; the toolchain (ct 283 / compile / xref / dialyzer incl. behaviour
conformance) is **attested by CC** (OTP 28 local) → reconciles via **CI**.

## Per-row verdict

| ID | CC status | CDC verdict | Basis |
|----|-----------|-------------|-------|
| A1S2-1 | done | **reproduced** | `src/lfmt.hrl`: `-record(lfmt_opts, {engine = fezzik :: lfmt:engine()})` — engine-only, documented as the real dispatch selector (no hollow fields). |
| A1S2-2 | done | **reproduced** | `src/lfmt_engine.erl`: `-callback format(lfmt:opts(), unicode:chardata()) -> {ok,iolist()}\|{error,term()}`. |
| A1S2-3 | done | **reproduced** | `lfmt_fezzik`: `-behaviour(lfmt_engine)`; **two** `format` clauses — `format/1` (binary()\|string(), retained) + `format/2` (the callback). |
| A1S2-4 | done | **reproduced** | `new/1`: `set_opt` rejects unknown keys → `{unknown_option,K}`; `validate` → fezzik ok / pe\|pc `{engine_not_available}` / else `{unknown_engine}`. `lfmt_SUITE` asserts all four. |
| A1S2-5 | done | **reproduced** | `format/2` dispatches via `engine_module/1` → `lfmt_fezzik`; `format/1` defaults to `new(#{})`. |
| A1S2-6 | done | **reproduced (binary inputs); see F2** | Parity test asserts `lfmt:format(new(#{engine=>fezzik}), S) =:= lfmt_fezzik:format(S)` over 8 inputs — **all binaries**. For valid binaries the normalization is identity, so parity holds. String / invalid-utf8 inputs are not parity-tested (F2). |
| A1S2-7 | done | **reproduced** | Record is engine-only; `new(#{width=>100})` → `{unknown_option, width}` (test `no_hollow`/`unknown_option`). No option silently dropped. |
| A1S2-8 | done | **attested** (CI) | ct **283** (274+9), compile zero-warning, xref clean, dialyzer clean incl. `lfmt_engine` behaviour conformance — CC-run (OTP 28). |
| A1S2-9 | done | **reproduced** | `lfmt` exports `new/1, format/1, format/2` + `-export_type([opts/0, engine/0])`; doc-comments on each; `pe`/`pc` reserved + documented. |
| A1S2-10 | done | **reproduced** | `git show --stat a8edcf8` = only `lfmt.{erl,hrl}`, `lfmt_engine.erl`, `lfmt_fezzik.erl` (+17), `lfmt_SUITE.erl`. Diff vs `render`/`util`/`pe_*`/`docs/planning/v0.5.0` → **empty**. `git tag -l 0.4.0` → none. |

**Tally:** 10 rows walked. 8 reproduced, 1 reproduced-with-finding (A1S2-6),
1 attested-at-CI-boundary (A1S2-8). 0 deferred, 0 no-op, 0 rejected.

## Bubble-up check (Part IV)

1. **Delivered its arc piece?** Yes — the multi-engine API (record + behaviour +
   `new/1` + dispatch + Fezzik conformance) is in place; engine internals
   untouched.
2. **Silent-drop diff honest?** Yes. CC's two deviations from the slice-doc
   sketch are *flagged, not silent* (new/1 raises; format/2 normalizes) and both
   are disclosed in the closing report. No silent drops.
3. **Arc-plan change?** CC recorded arc-plan v1.4 (slice-3 packaging note: the
   tarball must now include `lfmt.erl`/`lfmt_engine.erl`/`lfmt.hrl`). Concur —
   that's already reflected in slice 3's docs.

## Findings

- **F1 — `new/1` raises (endorse).** Matches the slice-doc's stated default for a
  constructor; bad input (unknown engine/option, reserved pe/pc) is a programmer
  error and errors clearly. Clean.
- **F2 — `format/2` chardata→binary normalization: sound, but parity is tested
  for binary inputs only.** `lfmt_fezzik:format/2` does
  `unicode:characters_to_binary(Source)` then delegates to `format/1`. The
  rationale is good: the behaviour rightly accepts generic `chardata()` (for
  pe/pc), while `format/1`'s domain is `binary()|string()`, so normalizing keeps
  the contract Dialyzer-honest without touching engine internals. **Verified
  behaviour-preserving for valid binaries** (characters_to_binary is identity on
  valid UTF-8; the 8-input parity test is all binaries). **Two untested edges:**
  (a) *string* inputs — the API path normalizes string→binary before `format/1`,
  the direct call passes the string; equivalence rests on the lexer treating
  `string ≡ utf8-binary` (plausible, untested here); (b) *invalid-UTF-8 binary* —
  the API path now returns `{error, {invalid_encoding, _}}`, a cleaner error than
  bare `format/1` would give (a minor, arguably-better behaviour change).
  **Practical risk ≈ nil:** the real consumer (rebar3_lfe's provider) always
  passes a `file:read_file` **binary**, where normalization is identity.
  **Recommended (non-blocking) follow-up:** add a string-input parity case to
  `lfmt_SUITE` to close the gap explicitly. Logged here.
- **F3 — toolchain attested.** ct 283 etc. are CC-run; CI reconciles (same
  boundary as the other v0.4.0 slices).

## Closure

**CDC accepts slice 2 (engine-api).** API surface, validation, no-hollow-options,
and scope independently reproduced; the two CC choices are sound and disclosed;
parity holds for the (binary) inputs that the real consumer uses. Closed first
pass, with the F2 string-input parity case as a non-blocking follow-up.

Arc **not** closed — slices 3 (hex-release) and 4 (rebar3-integration, planned in
`rebar3_lfe/docs/design/023-lfmt-integration/`) remain. Toolchain reconciles on CI.

Reviewed by: CDC (Cowork chat seat).
