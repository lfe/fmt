# v0.3.0 — project plan (Namespace under lfmt + honest harness)

> Plan-of-record for the **v0.3.0** project: put the imported Fezzik engine under
> the `lfmt_` namespace, rename the OTP app + future hex package `fmt` → `lfmt`,
> and clear the carried v0.1.0 test-harness debt. Part of the Fezzik-migration
> saga (v0.1.0 → v0.4.0). Design reference: `workbench/fezzik-migration-plan.md`
> §5, §7.
>
> **First code-change project — CI-gated.** v0.1.0/v0.2.0 were git+docs only
> (fully CDC-reproducible). v0.3.0 changes Erlang source, so its composition
> rows depend on `rebar3 compile`/`ct`/`xref`/`dialyzer` — reconciled by **CI**,
> the part the CDC sandbox can't run.
>
> **Why not collapsed.** Per the operator's single-slice-collapse rule
> (2026-06-26), thin one-slice projects skip the project/arc ceremony. v0.3.0 is
> **two** slices' worth (rename; harness fix) — a genuine multi-slice arc — so it
> keeps the full structure.

## Definition of done, and boundaries

**v0.3.0 delivers:**

- The three Fezzik modules + their three CT suites + the `_SUITE_data` dir
  renamed `r3lfe_format*` → `lfmt_fezzik*`, all cross-references updated.
- The OTP app + future hex package renamed `fmt` → `lfmt` (`lfmt.app.src`,
  `lfmt.erl`), `vsn` `0.3.0`, hex metadata **staged** (not published).
- The carried v0.1.0 **Unicode harness fix**: inline oracle helpers use
  `unicode:characters_to_binary` (not `iolist_to_binary`), and the
  7-bit-ASCII restriction on the inline-oracle corpus is **removed** — every
  corpus file goes through every oracle.
- Green across `compile`/`ct`/`xref`/`dialyzer`; `pe_*` and `docs/planning/v0.5.0`
  untouched; tag `0.3.0`.

**v0.3.0 explicitly does NOT:** rename `pe_*` → `lfmt_pe_*` (→ v0.5.0); split the
renderer, publish to hex, or rewire `rebar3_lfe` (→ v0.4.0 — metadata is *staged*
here, not published).

## Arc roadmap

| Arc | Capability | Status | Depends on |
|-----|-----------|--------|------------|
| `arc1-rename` | Fezzik under the `lfmt_` namespace (app `lfmt`) **and** an honest, un-restricted test harness | planned (v2.1; 2 slices) | v0.1.0+v0.2.0 import merged (the `r3lfe_*` modules present) |

No imported historical arcs live under v0.3.0 (the rename produces *new* fmt
history), so numbering starts at **arc1** — per the operator's increment rule.

## Current status

Planned, not started. Prerequisite: v0.1.0/v0.2.0 merged to where the
`r3lfe_format*` modules + suites are present (currently `feature/fezzik-import`;
cleanest to start v0.3.0 from that line once v0.1.0/v0.2.0 are gated + merged to
`main`).

## Project Ledger (DoD composition rows — LEDGER-DISCIPLINE Section C)

> Opens here; closes (per-row walk) in `closing-report.md`. Class-(b) reproduced
> at **project scale** (CI for the toolchain rows).

Definition of done: *Fezzik is `lfmt`-namespaced (app + modules), the test
harness is unicode-honest and un-restricted, the toolchain is green, `pe`/v0.5.0
are untouched, and `0.3.0` is tagged.*

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| P-1 | arc1-rename closed + composed | ptr: `arc1-rename/closing-report.md` | correctness | project-plan | open | | class-(a) |
| P-2 | **DoD demonstrable at project scale**: `grep -rn r3lfe src test` empty; `lfmt_fezzik*` modules compile + `ct` green (full corpus, no ASCII restriction) + `xref` + `dialyzer` clean; app is `lfmt`; `pe_*`/v0.5.0 untouched; `0.3.0` tagged | project-scale demo + **CI** | serious | project-plan | open | | class-(b); toolchain rows = CI |
| P-3 | findings dispositioned — incl. **closing** the carried v0.1.0 Unicode-harness finding (its disposition is slice2) | ptr: Version History + v0.1.0 project-plan back-link | correctness | bubble-up | open | | class-(c) |

## Version History

- **v1.0 — 2026-06-26** (initial; planned forward). Roadmap (`arc1-rename`, two
  slices: `slice1-namespace-rename`, `slice2-harness-unicode`), DoD + boundaries,
  project-ledger. **Absorbs the carried v0.1.0 finding** (the inline-oracle
  `iolist_to_binary` → `unicode:characters_to_binary` fix) as slice 2 — giving
  it the concrete planned home it lacked. This closes the loop the v0.1.0
  closing-report opened ("tracked, not yet a planned slice").
