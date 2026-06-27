# Slice 1: namespace-rename

> Project: `v0.3.0`
> Arc: `arc1-rename`
> Slice: `slice1-namespace-rename`
> Status: planned for CC
> Next: `slice2-harness-unicode` (operates on the renamed suite)

## Purpose

The **pure, mechanical** rename: bring the imported Fezzik engine under the
`lfmt_` namespace and rename the OTP app + future hex package `fmt` → `lfmt`. No
logic changes — the diff is reviewable as "names only." The carried Unicode
harness fix is **slice 2**, deliberately kept out of this diff.

## Scope

### Module + suite renames (`git mv`, history follows)

| from | to | `-module(...)` |
|---|---|---|
| `src/r3lfe_format_lexer.erl` | `src/lfmt_fezzik_lexer.erl` | `lfmt_fezzik_lexer` |
| `src/r3lfe_format_cst.erl` | `src/lfmt_fezzik_cst.erl` | `lfmt_fezzik_cst` |
| `src/r3lfe_formatter.erl` | `src/lfmt_fezzik.erl` | `lfmt_fezzik` |
| `test/r3lfe_formatter_SUITE.erl` | `test/lfmt_fezzik_SUITE.erl` | `lfmt_fezzik_SUITE` |
| `test/r3lfe_format_cst_SUITE.erl` | `test/lfmt_fezzik_cst_SUITE.erl` | `lfmt_fezzik_cst_SUITE` |
| `test/r3lfe_format_lexer_SUITE.erl` | `test/lfmt_fezzik_lexer_SUITE.erl` | `lfmt_fezzik_lexer_SUITE` |
| `test/r3lfe_format_lexer_SUITE_data/` | `test/lfmt_fezzik_lexer_SUITE_data/` | (CT `<suite>_SUITE_data` convention) |

### Cross-reference updates (every call site + type)

- `r3lfe_format_lexer:` → `lfmt_fezzik_lexer:`, `r3lfe_format_cst:` →
  `lfmt_fezzik_cst:`, `r3lfe_formatter:` → `lfmt_fezzik:` — across all modules
  and suites.
- `-type r3lfe_format_cst:cst_node()` references → `lfmt_fezzik_cst:cst_node()`.
- The `-ifdef(TEST). -export([regime/2]).` and
  `-dialyzer({no_underspecs, format/1}).` attributes travel intact into
  `lfmt_fezzik`.
- End state: `grep -rn r3lfe src test` → **empty**.

### App / package rename (repo-wide — the app is shared)

- `src/fmt.app.src` → `src/lfmt.app.src`; `{application, lfmt, [...]}`; `vsn`
  `"0.3.0"`.
- `src/fmt.erl` → `src/lfmt.erl` (a stub); `-module(lfmt)`.
- **Check for app-name references** the rename must follow:
  `application:*(fmt …)`, any CT/test config naming the `fmt` app, relx/release
  stanzas. The app contains *both* `pe_*` and the Fezzik modules, so this is a
  repo-wide app rename — but **no `pe_*` module source changes**.
- `rebar.config`: keep `{deps, []}` (engine runtime-dep-free; `lfe` stays
  test-only). **Stage** hex metadata for v0.4.0: `{licenses, ["Apache-2.0"]}`,
  `{links, [...]}` in `lfmt.app.src`; `rebar3_hex` in `project_plugins`. Stage
  only — **do not publish** (that's v0.4.0).

## Dependency

Runs on the import line (the `r3lfe_format*` modules must be present). Base off
`main` if `feature/fezzik-import` is already merged there, else off
`feature/fezzik-import` — either works for this slice. The operator's hard
constraint (2026-06-26) is only that **all of v0.1.0–v0.3.0 reach `main` before
the v0.4.0 branch is cut**, not where v0.3.0 is based. Confirm with the operator.

## Out of scope

- The Unicode harness fix + removing the ASCII restriction → **slice 2**. This
  slice leaves the v0.1.0 ASCII carve-out exactly as-is (ct stays green under
  it); slice 2 removes it.
- The `0.3.0` **tag** is created at **arc completion (after slice 2)**, marking
  the complete v0.3.0 state (namespace + honest harness) — not in this slice.
- `pe_*` → `lfmt_pe_*` (v0.5.0); renderer split / publish / rewire (v0.4.0).

## Success criteria (gate)

- All renames done via `git mv` (history preserved); `-module`/refs updated.
- `grep -rn r3lfe src test` → empty.
- `rebar3 compile` zero-warning; `rebar3 ct` green (under the still-present ASCII
  restriction); `rebar3 xref` + `rebar3 dialyzer` clean.
- App is `lfmt` (`lfmt.app.src`, `vsn 0.3.0`); hex metadata staged, not
  published.
- **`pe_*` module sources untouched** (`git diff -- src/pe_*.erl` empty) and
  `docs/planning/v0.5.0/` untouched.
- The diff is **names-only**: renames + identifier substitutions + app.src
  metadata; no function-body logic changes (spot-check the `lfmt_fezzik.erl`
  diff is identifier-level only).
- No `0.3.0` tag yet.

## Handoff

CC provides: the rename committed (history-preserving `git mv`s); the green
toolchain output; the empty `grep -rn r3lfe`; the `pe_*` no-touch diff; a per-row
ledger walk; `closing-report.md` (per-row walk + bubble-up to the arc).
