# arc1-rename — plan

> The arc that brings Fezzik to a clean **`lfmt_` namespace** (OTP app + future
> hex package `fmt` → `lfmt`) **and** clears the carried v0.1.0 test-harness
> debt, so the engine enters v0.4.0 (split/publish) namespaced and fully honest.
> Project: **v0.3.0**. Two slices (this arc is genuinely multi-slice — not a
> collapse case). Master reference: `workbench/fezzik-migration-plan.md` §5, §7.

## Why this arc

After the import, `fmt` holds two engines: the `pe_*` line and the imported
`r3lfe_format*` Fezzik line, still wearing `rebar3_lfe` names. The repo's
namespace decision is that every module is `lfmt_`-prefixed and the app is
`lfmt`. This arc makes the Fezzik half conform.

It also closes a debt: v0.1.0/arc7-import surfaced a latent Fezzik test-harness
bug — the inline oracle helpers flatten formatter output with `iolist_to_binary`,
corrupting the >127 codepoints the formatter emits for multibyte UTF-8, so two
corpus files were excluded from the inline-oracle path. That finding was routed
here ("v0.3.0 or earlier") and **gets its concrete slice now** (slice 2).

`pe_*` is **not** touched (its rename rides the v0.5.0 line). And rename stays
separated from the v0.4.0 renderer split so "rename" and "restructure" never mix
in one diff.

## Slice breakdown

| # | Slice | Scope | Gate |
|---|-------|-------|------|
| 1 | `slice1-namespace-rename` | the pure, mechanical rename: `r3lfe_format*` → `lfmt_fezzik*` (3 modules + 3 suites + `_SUITE_data`), all cross-refs/types, app `fmt` → `lfmt` (`lfmt.app.src`/`lfmt.erl`, vsn `0.3.0`), stage hex metadata | **names-only diff**; `grep -rn r3lfe src test` empty; compile/ct/xref/dialyzer green; `pe_*`/v0.5.0 untouched |
| 2 | `slice2-harness-unicode` | the carried v0.1.0 fix: inline oracle helpers (`assert_idempotent`/`_token`/`_ast` in `lfmt_fezzik_SUITE`) use `unicode:characters_to_binary`; **remove** the `is_seven_bit_ascii` restriction on `full_corpus/0` so every corpus file flows through every oracle | the 2 multibyte files (`core-macros.lfe`, `clj-tests.lfe`) pass the inline oracles; full corpus green; no ASCII carve-out remains |

**Order matters:** rename first (slice 1) keeps that diff *pure names* —
maximally reviewable; ct is already green under the v0.1.0 ASCII restriction, so
the rename needs no logic change. Slice 2 then operates on the *renamed*
`lfmt_fezzik_SUITE`, swapping the flatten + dropping the restriction. Two clean
diffs instead of one mixed one.

## Arc Ledger (composition rows — LEDGER-DISCIPLINE Section B)

> Opens here; closes (per-row walk) in `closing-report.md`. Class-(b) reproduced
> at arc scale (CI for the toolchain rows).

Capability: *Fezzik is `lfmt`-namespaced (app + modules) with an honest,
un-restricted test harness; toolchain green; `pe`/v0.5.0 untouched.*

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1-1 | slice 1 (namespace-rename) closed | ptr: `slice1-namespace-rename/cdc-verification.md` | correctness | arc-plan | open | | class-(a) |
| A1-2 | slice 2 (harness-unicode) closed | ptr: `slice2-harness-unicode/cdc-verification.md` | correctness | arc-plan | open | | class-(a) |
| A1-3 | **composes**: no `r3lfe` anywhere; `lfmt_fezzik*` modules + app `lfmt`; full-corpus `ct` green with **no ASCII carve-out**; compile/xref/dialyzer clean; `pe_*`/v0.5.0 untouched | arc-scale demo + **CI** | serious | arc-plan | open | | class-(b); reproduce at arc scale |
| A1-4 | carried **v0.1.0 Unicode-harness finding closed** here (disposition = slice 2) | ptr: slice2 cdc + v0.1.0 project-plan back-link | correctness | bubble-up | open | | class-(c) — closes the v0.1.0 carry-out |

## Out of scope → later

- **Renderer split** (`lfmt_fezzik.erl` → `lfmt_fezzik_{render,clause,data}`) →
  v0.4.0.
- **hex publish** → v0.4.0 (metadata staged here, not published).
- **`rebar3_lfe` rewire / engine deletion** → v0.4.0.
- **`pe_*` → `lfmt_pe_*`** → v0.5.0.

## How we work

Peer frame; CC implements walking a ledger; CDC verifies independently;
implementer never marks its own work verified; iteration cap 5/slice. Sandbox
cannot mutate git or run the toolchain — hand the operator any `git`/`rm`; the
compile/ct/xref/dialyzer rows reconcile via **CI**. The rename slice leans hard
on mechanical checks (`grep -rn r3lfe`, the `pe_*` no-touch diff, xref). Load
**collaboration-framework** + **erlang-guidelines**. Ledger IDs: arc-ledger
`A1-<row>`; slice ledgers `A1S<n>-<row>`.

## Version History

- **v2.1 — 2026-06-26** (surfaced by **slice 1** close/bubble-up). Recorded a
  one-line exception to the arc's "`pe_*` untouched" claim: the `fmt` → `lfmt`
  app rename forces `src/pe_lfe.erl` `base_rules_path/0` to follow the app name
  (`code:priv_dir(fmt)` → `code:priv_dir(lfmt)`), or pe rule-loading crashes and
  `ct` fails (operator-confirmed amendment to slice-1 gate A1S1-10). **Arc
  composition row A1-3** ("`pe_*`/v0.5.0 untouched") therefore reads "untouched
  **except the single app-name reference the rename requires**"; the arc-close
  check must verify that accurate claim, not the literal one. A pure name change,
  no pe logic; no change to the slice breakdown (slices 1 & 2 stand).
- **v2.0 — 2026-06-26** (CDC, planning v0.3.0 forward). Restructured from the
  original single-slice rename into a **two-slice arc**: added
  `slice2-harness-unicode` to absorb the carried v0.1.0 Unicode-harness finding
  (giving it the concrete home it lacked), and brought the plan to
  collaboration-framework v2.1 (arc-ledger; slice breakdown). The rename scope
  detail moved into `slice1-namespace-rename/slice-doc.md`. Substantive rename
  unchanged.
- **v1.0 — 2026-06-25** (initial). Single-slice rename plan (`r3lfe_format*` →
  `lfmt_fezzik*`, `fmt` → `lfmt`, hex metadata staged), pre-v2.1.
