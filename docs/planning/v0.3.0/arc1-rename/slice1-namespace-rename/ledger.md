# Slice 1: namespace-rename — ledger

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently. Implementer never marks its own rows CDC-verified. Iteration
> cap: 5. Project `v0.3.0` · arc `arc1-rename` · slice `slice1-namespace-rename`.
> Toolchain rows reconcile via **CI** (no OTP in the CDC sandbox).

## Ledger

> CC self-assessment. Base `feature/fezzik-import` (`51fc1af`); rename commit
> `e469d0f`; branch `feature/v0.3.0-namespace` (worktree `../fmt-v0.3.0-namespace`).
> Toolchain rows run locally **and** flagged "CI reconciles". Every `done` is
> **proposed-done** until CDC reproduces.

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S1-1 | 3 engine modules renamed (`git mv`) with `-module` updated | `git show --name-status` shows `R` for the 3 src files; `grep -l '^-module(lfmt_fezzik' src` | correctness | slice-doc | done | `git diff -M --name-status`: `R078 …/lfmt_fezzik.erl`, `R095 …_cst.erl`, `R099 …_lexer.erl`. `-module(lfmt_fezzik{,_cst,_lexer})` confirmed. | history preserved (renames detected) |
| A1S1-2 | 3 suites + `_SUITE_data` dir renamed with `-module` updated | rename shows `R`; CT `<suite>_SUITE_data` convention honored | correctness | slice-doc | done | `R096 lfmt_fezzik_SUITE`, `R066 …_cst_SUITE`, `R071 …_lexer_SUITE`, `R100 …_lexer_SUITE_data/tq_corpus.lfe`. Data-dir string refs updated to match. | |
| A1S1-3 | all cross-refs + `cst_node()` type updated; **no `r3lfe` survives** | `grep -rn r3lfe src test` → empty | serious | slice-doc | done | `grep -rn r3lfe src test` → **empty**. 581 occurrences resolved via 3 non-overlapping substitutions. | the load-bearing check |
| A1S1-4 | OTP app renamed `fmt` → `lfmt` (`lfmt.app.src` `{application, lfmt}`, `lfmt.erl`, vsn `0.3.0`); app-name references followed | `grep -rn '\bfmt\b' src rebar.config` reviewed; `application` refs updated | serious | slice-doc | done | `src/lfmt.app.src` `{application, lfmt}`, `{vsn, "0.3.0"}`; `src/lfmt.erl` `-module(lfmt)`. `\bfmt\b` survey: only real app-name follow was `pe_lfe.erl` `code:priv_dir` (see A1S1-10 / Amendment 1); other `\bfmt\b` are local `fmt/N` test helpers + LFE fixture strings + comments (correctly untouched). rebar3 builds app as `lfmt`. | repo-wide app rename |
| A1S1-5 | hex metadata **staged, not published** (licenses, links; `rebar3_hex` plugin) | inspect `lfmt.app.src` + `rebar.config`; no `hex publish` run | serious | slice-doc | done | `lfmt.app.src`: `{licenses, ["Apache-2.0"]}`, `{links, [{"GitHub", "https://github.com/lfe/fmt"}]}`. `rebar.config`: `rebar3_hex` added to `project_plugins`; `{deps, []}` unchanged. **No `hex publish` run.** | publish = v0.4.0 |
| A1S1-6 | `rebar3 compile` zero-warning under new names | `rebar3 compile` | serious | engineering bar | done | `rebar3 compile` → "Compiling lfmt", zero warnings. | also CI reconciles |
| A1S1-7 | `rebar3 ct` green (under the still-present v0.1.0 ASCII restriction) | `rebar3 ct` | serious | engineering bar | done | `rebar3 ct` → **All 274 tests passed**. ASCII restriction left intact (slice 2 removes it). | also CI reconciles |
| A1S1-8 | `rebar3 xref` clean — no dangling `r3lfe_*` | `rebar3 xref` | serious | engineering bar | done | `rebar3 xref` exit 0, no undefined/dangling refs. | also CI reconciles |
| A1S1-9 | `rebar3 dialyzer` clean (`no_underspecs` carried) | `rebar3 dialyzer` | serious | engineering bar | done | `rebar3 dialyzer` exit 0, 20 files, no warnings. `-dialyzer({no_underspecs,…})` carried into `lfmt_fezzik`. | also CI reconciles |
| A1S1-10 | `pe_*` module sources + `docs/planning/v0.5.0/` untouched | `git diff <base>..HEAD -- 'src/pe_*.erl' docs/planning/v0.5.0` → empty | serious | scope control | **done (amended)** | `git diff -- 'src/pe_*.erl'` = **exactly one line**: `pe_lfe.erl` `code:priv_dir(fmt)` → `code:priv_dir(lfmt)`. `docs/planning/v0.5.0` diff empty. See Amendment 1. | criterion relaxed by operator decision |
| A1S1-11 | the diff is **names-only** (no function-body logic change) | review `lfmt_fezzik.erl` diff — identifier-level only | serious | scope control | done | Whole-slice diff filtered: every changed content line is an identifier sub, app-metadata, or the one `priv_dir` follow — no logic change. `lfmt_fezzik.erl` diff is identifier-only. | reviewable by eye |
| A1S1-12 | no `0.3.0` tag created in this slice | `git tag -l 0.3.0` → empty | polish | scope control | done | `git tag -l 0.3.0` → empty. | tag at arc close (after slice 2) |

## Amendments (CC-raised refinements)

1. **A1S1-10 relaxed: one app-name-follow line in a `pe_*` module (operator-
   confirmed 2026-06-26).** The `fmt` → `lfmt` app rename forces
   `src/pe_lfe.erl` `base_rules_path/0` to follow the app name —
   `code:priv_dir(fmt)` → `code:priv_dir(lfmt)`. `base_rules_path/0` ←
   `load_rules/0` (the **default** rule registry for `pe_lfe:format`), exercised
   across the pe suite; leaving it `priv_dir(fmt)` returns `{error, bad_name}`
   → `filename:join` crash → pe rule-loading breaks → **`ct` fails**. So gates
   A1S1-4 (app-name refs followed) + A1S1-7 (ct green) are unsatisfiable
   alongside a literal "`pe_*` untouched". Resolution: make the **single**
   app-name-follow (a pure name change, **no pe logic**); the gate now reads
   "`pe_*` untouched **except the one app-name reference the rename requires**".
   `git diff -- 'src/pe_*.erl'` is exactly that one line. The prompt anticipated
   app-name refs ("hunt … references the rename must follow") but assumed none
   lived in `pe_*`; this one did.

## Caveats

- **`src/fmt.erl` → `src/lfmt.erl` shows as delete+add, not a rename.** It is a
  3-line stub (`-module`, blank, `-export([])`); once `-module(fmt)` became
  `-module(lfmt)` the similarity fell below git's 50% rename threshold, so the
  name-status reads `D src/fmt.erl` / `A src/lfmt.erl`. Verified the only content
  difference is the `-module` line (`diff` of the two = line 1 only). No history
  value lost (it is a stub, not an engine module).
- **ct stays green under the v0.1.0 ASCII inline-oracle restriction**, which is
  deliberately left in place — slice 2 (`slice2-harness-unicode`) removes it and
  fixes the underlying `iolist_to_binary` → `unicode:characters_to_binary` helper.
- **Toolchain rows were run locally (OTP 28)**; the ledger marks them "CI
  reconciles" per the arc plan (no OTP in the CDC sandbox).

## What Worked

- **Surveying every `r3lfe` and `\bfmt\b` reference before editing.** It proved
  the 581 `r3lfe` hits reduce to 3 non-overlapping identifiers (one sed pass,
  no ordering hazard) **and** surfaced the single `pe_lfe` app-name collision up
  front — turning a would-be silent scope breach into a confirmed amendment.
- **Filtering the whole-slice diff against the known substitution patterns** to
  prove "names-only" mechanically, rather than eyeballing 581 changes.

## Closure

Self-assessed complete at commit `e469d0f` on `feature/v0.3.0-namespace` (base
`51fc1af`). Total rows: **12**. Done: **12** (A1S1-10 done under the operator-
confirmed amendment). Deferred: **0**. No-op: **0**. CC self-assessment only —
**CDC verification pending** (`cdc-verification.md`). Next: `slice2-harness-unicode`
(operates on the renamed `lfmt_fezzik_SUITE`); the `0.3.0` tag is created at arc
close, after slice 2.
