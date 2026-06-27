# Slice 2: harness-unicode

> Project: `v0.3.0`
> Arc: `arc1-rename`
> Slice: `slice2-harness-unicode`
> Status: planned for CC
> Prior: `slice1-namespace-rename` (operates on the renamed `lfmt_fezzik_SUITE`)

## Purpose

Close the carried v0.1.0 finding: make the inline oracle helpers Unicode-safe so
the two multibyte corpus files no longer have to be excluded. After this, **every
corpus file flows through every oracle** — the test harness is honest, with no
ASCII carve-out.

## Background (the carried finding)

v0.1.0/arc7-import found that `lfmt_fezzik`'s formatter emits Unicode codepoints
(> 127) in its output iolist for multibyte-UTF-8 sources, which re-read correctly
**only** via `unicode:characters_to_binary`. The inline oracle helpers
(`assert_idempotent` / `assert_token_preservation` / `assert_ast_equiv`) flatten
with `iolist_to_binary`, which mangles those codepoints (re-read →
`invalid_encoding`). As a stopgap, v0.1.0 added an `is_seven_bit_ascii` filter to
`full_corpus/0` (the inline-oracle feed), excluding the two offending files
(`core-macros.lfe`, `clj-tests.lfe`); they stayed covered by the Unicode-safe
sweeps (`corpus_sweep_all` / `conf_wide_sweep`, which already use
`unicode:characters_to_binary`). This slice removes the stopgap by fixing the
root cause.

## Scope

In scope (all within `test/lfmt_fezzik_SUITE.erl`):

- Replace `iolist_to_binary(...)` with `unicode:characters_to_binary(...)` in the
  three inline oracle helpers' flatten of formatter output. Handle the return
  contract: `unicode:characters_to_binary/1` returns `binary()` on success but
  `{error,_}`/`{incomplete,_}` on bad input — assert/extract the binary so a
  malformed result fails loudly rather than silently comparing wrong types.
- **Remove** the `is_seven_bit_ascii/1` filter from `full_corpus/0` so all corpus
  files feed the inline oracles. Remove the helper if now unused.

Out of scope: the formatter itself (`lfmt_fezzik.erl`) — no engine change; the
sweeps (already Unicode-safe); any rename (done in slice 1); the `0.3.0` tag
(created at arc close).

## Dependency

Continues `feature/v0.3.0-namespace` on top of slice 1 (`e469d0f`), so it edits
the already-renamed `lfmt_fezzik_SUITE`.

## Success criteria (gate)

- The three inline oracle helpers flatten with `unicode:characters_to_binary`;
  `grep iolist_to_binary` in the suite's oracle path → gone (or justified if any
  remains for genuinely-binary inputs).
- `is_seven_bit_ascii` is removed; `grep -rn is_seven_bit_ascii test` → empty.
- The two multibyte files (`core-macros.lfe`, `clj-tests.lfe`) pass the inline
  oracles (idempotence / token-preservation / AST-equivalence) — the inline
  oracle input count now equals the full corpus (no exclusion); state the count.
- Full `rebar3 ct` green; `compile`/`xref`/`dialyzer` still clean. (CI reconciles.)
- Diff confined to `test/lfmt_fezzik_SUITE.erl`; `lfmt_fezzik.erl` (engine) and
  other modules untouched; `pe_*` + `docs/planning/v0.5.0/` untouched.

## Handoff

CC provides: the harness fix committed; the inline-oracle input count showing the
2 files now included; green ct/compile/xref/dialyzer (local + CI); a per-row
ledger walk; `closing-report.md` with the bubble-up to the arc. **This is arc1's
last slice** — its close feeds the arc close (`arc1-rename/closing-report.md`,
the `0.3.0` tag, and the v0.3.0 project close).
