# v0.2.0 — project plan (Refined-brute docs + tag)

> Plan-of-record for the **v0.2.0** project: land the refined brute-force
> formatter's design record and its `0.2.0` source-history tag. Part of the
> Fezzik-migration saga (v0.1.0 → v0.4.0). Design reference:
> `workbench/fezzik-migration-plan.md`.
>
> **Planned forward (contrast with v0.1.0).** v0.1.0's project-plan was a
> *retrofit* written at close; this one is written *before* execution — the
> top-down half of the loop, the way the framework intends. The v2.1 structure
> (project-ledger; arc with arc-ledger; a nested slice) is in place from the
> start.

## Definition of done, and boundaries

**v0.2.0 delivers:**

- The refined-brute design record — the imported `arc7-rules-v2` docs — placed
  under `docs/planning/v0.2.0/`, history preserved.
- The annotated **`0.2.0` tag** on the imported refined-brute tip (a
  source-history marker, not a buildable release).
- The imported `docs/design/022-lfe-format/` **staging dir emptied and removed**
  (its last contents, `arc7-rules-v2`, move here) — completing the doc-split
  begun in v0.1.0/slice2.

**v0.2.0 explicitly does NOT:** import anything (the refined-brute *code* and its
full history already arrived via v0.1.0/arc7-import's single `filter-repo` +
merge — v0.2.0 adds only its docs + tag); rename modules (→ v0.3.0); build,
split, or publish (→ v0.4.0).

**Why thin is correct.** Because one continuous history can't be imported in
pieces, v0.1.0 necessarily carried the 0.2.0 commits already. v0.2.0's
per-project work is therefore just *its own* docs and tag — small, but kept its
own project per the operator's versions-as-projects decision (2026-06-25).

## Arc roadmap

| Arc | Capability | Status | Depends on |
|-----|-----------|--------|------------|
| `arc8-docs-and-tag` | place `arc7-rules-v2` docs under `docs/planning/v0.2.0/` + tag `0.2.0` | planned (v2.1; one nested slice) | v0.1.0/arc7-import (import + slice2 doc-split) merged |

Numbering is **arc8** because v0.2.0 also holds the imported historical dev arc
`arc7-rules-v2` (kept at 7 — history is not renumbered); the fmt-side work
increments after it. The imported arc carries no roadmap row (it is an archived
record, not an arc this project executes).

## Current status

Planned, not started. Prerequisite: v0.1.0/arc7-import merged to where
`docs/design/022-lfe-format/arc7-rules-v2/` and the refined-brute tip are
present (they are, on `feature/fezzik-import`).

## Project Ledger (DoD composition rows — LEDGER-DISCIPLINE Section C)

> Opens here; closes (per-row walk) in `closing-report.md`. Class-(b) reproduced
> at **project scale**, not inherited from the arc.

Definition of done: *the refined-brute design record is placed under
`docs/planning/v0.2.0/`, the `0.2.0` tag marks the refined-brute tip, the
staging dir is gone, and v0.1.0/v0.5.0 are untouched.*

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| P-1 | arc8-docs-and-tag closed + composed | ptr: `arc8-docs-and-tag/closing-report.md` | correctness | project-plan | open | | class-(a); attested by pointer |
| P-2 | **DoD demonstrable at project scale**: `docs/planning/v0.2.0/arc7-rules-v2/` present with history; `0.2.0` resolves to the refined-brute tip and is a descendant of `0.1.0`; `docs/design/022-lfe-format/` gone; v0.1.0/v0.5.0 untouched | project-scale demo (tree + tag + ancestry + diff) | serious | project-plan | open | | class-(b) — reproduce at project scale |
| P-3 | arc bubble-up findings dispositioned | ptr: Version History below | correctness | bubble-up | open | | class-(c) |

## Version History

- **v1.0 — 2026-06-26** (initial; planned forward). Roadmap (single arc
  `arc8-docs-and-tag`, one nested slice), DoD + boundaries, project-ledger rows.
  Carries in the v0.1.0 bubble-up rule: **anchor the `0.2.0` tag on a full,
  unique commit message** (short tokens like `A7·S6` are not unique locators)
  and **do not expect a `RESEARCH-BOOTSTRAP.md`** (it was an untracked phantom).
