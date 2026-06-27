# Slice 1: place-and-tag — ledger

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently (reads the moved tree + tag + ancestry, not summaries).
> Implementer never marks its own rows CDC-verified. Iteration cap: 5.
> Project `v0.2.0` · arc `arc8-docs-and-tag` · slice `slice1-place-and-tag`.

## Ledger

> CC self-assessment. Slice base = `f963976` (v0.1.0/slice2 tip); move commit
> `51fc1af`; tag `0.2.0` → `5334ff8`. Branch `feature/fezzik-import` (worktree
> `../fmt-fezzik-import`). Every `done` is **proposed-done** until CDC reproduces.

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A8S1-1 | `arc7-rules-v2/` moved into `docs/planning/v0.2.0/` (history-preserving) | `git ls-tree <tip> -- docs/planning/v0.2.0/arc7-rules-v2`; rename shows `R100` | correctness | arc-plan | done | `git diff --name-status f963976..HEAD` → **26× `R100`**, all under `docs/planning/v0.2.0/arc7-rules-v2/`. Commit `51fc1af`. `git mv`, not copy+delete. | |
| A8S1-2 | history preserved across the move | `git log --follow docs/planning/v0.2.0/arc7-rules-v2/cc-prompt.md \| tail` reaches imported origin | serious | history preservation | done | `--follow …/arc7-rules-v2/cc-prompt.md` → origin `8ea7ada` (2026-06-15, imported), crossing the `51fc1af` rename. | sampled one file |
| A8S1-3 | the staging dir `docs/design/022-lfe-format/` is removed (empty after the move) | `git ls-tree <tip> -- docs/design/022-lfe-format` → empty; path absent | serious | scope control | done | After the `git mv`, dir empty → `rmdir` (rc 0); `ls -d docs/design/022-lfe-format` → "No such". Completes the doc-split. | |
| A8S1-4 | `0.2.0` annotated tag on the refined-brute tip, located by full message | `git for-each-ref refs/tags/0.2.0`; `git log --all -F --grep='A7·S6 — gallery regen + full sweep'` → unique | serious | arc-plan | done | Full-message anchor → **unique** `5334ff8` "A7·S6 — gallery regen + full sweep". `git show 0.2.0`: annotated, Tagger Duncan, → `5334ff8`. | **operator-confirmed tip `5334ff8`** (2026-06-26); code identical to alt `5086e4e` |
| A8S1-5 | `0.2.0` is a descendant of `0.1.0` (DAG-ordered tags) | `git merge-base --is-ancestor 0.1.0 0.2.0 && echo ok` | serious | correctness | done | `git merge-base --is-ancestor 0.1.0 0.2.0` → 0 (`0.1.0 < 0.2.0 ✓`). | |
| A8S1-6 | docs-move + tag only — no code change | `git diff --name-status <base>..<tip>` → `arc7-rules-v2` rename(s) only; no `src/`/`test/` | serious | scope control | done | `f963976..HEAD` = 26× `R100`, all `docs/planning/v0.2.0/arc7-rules-v2/`; no `src/`/`test/`/`rebar.config`. | |
| A8S1-7 | `docs/planning/v0.1.0/`, `docs/planning/v0.5.0/`, `arc7-import/` untouched | `git diff --stat <base>..<tip> -- docs/planning/v0.1.0 docs/planning/v0.5.0` → empty (modulo the new v0.2.0 tree) | serious | scope control | done | `git diff --stat f963976..HEAD -- docs/planning/v0.1.0 docs/planning/v0.5.0` → **empty**. (arc7-import is not on this branch — main worktree.) | |
| A8S1-8 | closing report: final `docs/planning/v0.2.0/` listing + tag SHA + ancestry confirmed | closing-report check | serious | methodology | done | `closing-report.md` written: listing, tag `5334ff8`, ancestry confirmed. | |

## Amendments (CC-raised refinements)

_(none — the two v0.1.0/slice-2 findings were pre-absorbed into this project's
plan: the full-message tag anchor and the `RESEARCH-BOOTSTRAP` phantom are both
in project-plan v1.0 / arc-plan v1.1, so neither re-surfaced as a new amendment
here. The tag-target operator decision was confirmed via the planned protocol,
not raised as a deviation.)_

## Caveats

- The placed `arc7-rules-v2/` keeps its `rebar3_lfe` archival shape (per-arc
  `cc-prompt-*.md`) — an archived design record, not active framework slices.
- `0.2.0` is a **source-history marker, not buildable** — the tagged commit
  carries only engine files (no `app.src`/`rebar.config`). First buildable tag
  is `0.4.0`.
- `docs/planning/v0.2.0/` on the branch now holds only `arc7-rules-v2/`; the
  `arc8-docs-and-tag/` planning tree + `project-plan.md` live in the **main**
  worktree (uncommitted), not on `feature/fezzik-import` — same split as v0.1.0;
  resolves at merge to main.

## What Worked

- **Reusing the v0.1.0/slice-2 finding without re-discovering it.** The
  full-message tag anchor (`A7·S6 — gallery regen + full sweep` → unique) was
  already baked into the plan, so the ambiguous-short-token trap was avoided by
  design, not by re-tripping it.
- **Confirming the operator tag decision with the code-identity fact in hand**
  (`5086e4e..5334ff8` diff = docs only) — the choice was informed, not blind.

## Closure

Self-assessed complete. Move commit `51fc1af`; tag `0.2.0` → `5334ff8`
("A7·S6 — gallery regen + full sweep"). Total rows: **8**. Done: **8**.
Deferred: **0**. No-op: **0**. CC self-assessment only — **CDC verification
pending** (`cdc-verification.md`). As arc8's **only** slice, this close feeds
directly into the arc close (`arc8-docs-and-tag/closing-report.md`) once CDC
verifies.
