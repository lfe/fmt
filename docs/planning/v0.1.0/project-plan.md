# v0.1.0 — project plan (Import & establish the brute baseline)

> Plan-of-record for the **v0.1.0** project: bring the proven brute-force LFE
> formatter ("Fezzik") into `lfe/fmt` with full git history and establish the
> 0.1.0 baseline. Part of the Fezzik-migration *saga* (v0.1.0 → v0.4.0; we track
> at project = version scale, not saga scale). Design reference:
> `workbench/fezzik-migration-plan.md`.
>
> **Retrofit note (disclosed, per spec-keeping):** v0.1.0 was planned arc-first,
> before the collaboration-framework v2.1 project-management layer existed. This
> `project-plan.md` is written **at project close** to complete the v2.1
> structure and to set the template for v0.2.0–v0.4.0. It records the roadmap
> and DoD as they actually held; it is not a fiction of having planned top-down.

## Definition of done, and boundaries

**v0.1.0 delivers:**

- The Fezzik engine — `r3lfe_format_lexer` / `r3lfe_format_cst` /
  `r3lfe_formatter` + their three CT suites + `tq_corpus.lfe` — **imported into
  `fmt` with full, authorship-preserving git history** (one `filter-repo` +
  `merge --allow-unrelated-histories`).
- The **0.1.0 baseline**: the imported arc1-6 design record placed under
  `docs/planning/v0.1.0/`, and the annotated **`0.1.0` tag** on the imported
  `A6·S0` commit (a source-history marker, not a buildable release).
- The corpus made **real** (re-pointed off the absent `_integration/` onto the
  `lfe` test-dep corpus), so the suites are honest rather than hollow.
- `pe` (v0.5.0) and the rest of the repo **untouched**.

**v0.1.0 explicitly does NOT:** rename modules to `lfmt_*` (→ v0.3.0); split,
build, or publish (→ v0.4.0); place the `arc7-rules-v2` docs or tag `0.2.0`
(→ v0.2.0). Modules stay at `r3lfe_*` names through this project.

## Arc roadmap

| Arc | Capability | Status | Depends on |
|-----|-----------|--------|------------|
| `arc7-import` | the import + 0.1.0 baseline (history-transfer; docs-and-tag) | **CDC-closed; arc-gate pending operator + CI** | — |

This project has **one active arc**. (Numbering is arc7 because v0.1.0 also
holds the imported historical dev arcs `arc1-lexer … arc6-release` as an
archived record — they are not arcs this project executes, so they carry no
roadmap row.) No second arc is conceivable for v0.1.0, so the roadmap is
genuinely single-arc; the project ledger below therefore leans directly on the
arc.

## Current status

Both slices of `arc7-import` are CDC-closed (slice 1: 7/12 reproduced + 5
toolchain attested; slice 2: 9/9 reproduced). Arc `closing-report.md` assembled;
**arc gate + project gate pending operator**, with **CI green on
`feature/fezzik-import`** as the one open reconciliation (the green-suites
sub-claim).

## Project Ledger (DoD composition rows — LEDGER-DISCIPLINE Section C)

> Opens here (retrofit) and closes — per-row walk — in `closing-report.md`.
> Class-(b) reproduced at **project scale**, not inherited from the arc.

Definition of done: *Fezzik lives in `fmt` with preserved history; the 0.1.0
baseline (design record + tag) is established; the corpus is real; pe untouched.*

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| P-1 | arc7-import closed + composed | ptr: `arc7-import/closing-report.md` | correctness | project-plan | open | | class-(a); attested by pointer |
| P-2 | **DoD demonstrable at project scale**: a fresh clone of `fmt`@`feature/fezzik-import` shows Fezzik with preserved history, the placed 0.1.0 design record, the resolvable `0.1.0` tag, a real corpus, and green suites | project-scale demo (DAG + tree + tag + CI) | serious | project-plan | open | | class-(b) — reproduce at project scale; suites=CI |
| P-3 | arc bubble-up findings dispositioned (Unicode harness fix carried to v0.3.0; §7a fixed; arc8 tag-anchor rule) | ptr: Version History below | correctness | bubble-up | open | | class-(c) |

## Version History

- **v1.0 — 2026-06-26** (initial; retrofit at project close). Roadmap (single
  arc `arc7-import`), DoD + boundaries, and the project-ledger DoD rows recorded
  to complete the v2.1 structure. **Carried-forward finding (from arc7-import
  bubble-up):** the Unicode inline-oracle harness fix
  (`iolist_to_binary` → `unicode:characters_to_binary`) escapes v0.1.0 entirely
  and is routed to **v0.3.0**; logged here so it is not orphaned at the
  v0.1.0 → v0.2.0 boundary.
