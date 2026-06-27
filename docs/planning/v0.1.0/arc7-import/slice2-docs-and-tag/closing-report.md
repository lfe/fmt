# Slice 2: docs-and-tag — closing report

> CC closing report (implementer self-assessment). Independent verification is
> CDC's, in `cdc-verification.md` (not yet written). Every `done` is
> **proposed-done** until CDC reproduces it.
> Project `v0.1.0` · arc `arc7-import` · slice `slice2-docs-and-tag`.
> Slice base `3177954` (slice-1 tip); moves commit `f963976`; tag `0.1.0` →
> `d2e79c7`. Branch `feature/fezzik-import` (worktree `../fmt-fezzik-import`).

## Per-row walk

9 rows at open; **9 walked** (no silent drops; count matches `ledger.md`). Full
Verify output is in `ledger.md`; one-line disposition per row here.

| ID | Status | Evidence (summary) |
|----|--------|--------------------|
| A7S2-1 | done | 6 arc dirs `arc1-lexer…arc6-release` under `docs/planning/v0.1.0/`; `git mv` renames, commit `f963976`. |
| A7S2-2 | done* | 6 loose files moved (`cc-prompt-gallery`, `cc-prompts`, `formatting-gallery`, `formatting-rules`, `rebar3-lfe-provider`, `SMOKE`). *Scope corrected from "seven" — `RESEARCH-BOOTSTRAP.md` never existed (Amendment 1). |
| A7S2-3 | done | `--follow` reaches imported origin across the rename: `formatting-rules.md`→`8ea7ada`, `arc1-lexer/cc-prompt.md`→root `c5bfc71`. |
| A7S2-4 | done | `docs/design/022-lfe-format/` now holds **only** `arc7-rules-v2`. |
| A7S2-5 | done | `0.1.0` annotated tag → `d2e79c7`. |
| A7S2-6 | done | Tag target unique via `--grep='Implement Arc A6·S0'` → `d2e79c7` (Amendment 2: bare `A6·S0` matches 2). |
| A7S2-7 | done | `3177954..HEAD` = 33× `R100`, docs only, `0 ±`; no `src/`/`test/`. |
| A7S2-8 | done | `v0.5.0` + `arc7-import` diff empty. |
| A7S2-9 | done | This report. |

**Totals: 9 done · 0 deferred · 0 no-op.** Strength: all rows **reproduced**
(commands run and observed at the committed state / tag). Two disclosed
deviations carried as ledger Amendments, not silent drops.

## Bubble-up to the arc (arc7-import)

### 1. Did slice 2 deliver the piece of the arc's capability the arc-plan assigned it?

Yes. The arc-plan slice-2 row: *`git mv` the imported arc1-lexer … arc6-release
dirs + spec/gallery/bootstrap/smoke into `docs/planning/v0.1.0/` (per §7a, minus
arc7); tag `0.1.0` (rewritten A6·S0).* Delivered: the 6 dev-arc dirs + 6 real
loose files relocated history-preserving; `arc7-rules-v2` left for v0.2.0;
`0.1.0` annotated on the imported `A6·S0` (`d2e79c7`). The arc-plan gate
("0.1.0 docs land per the map; `git log --follow` intact; `0.1.0` resolves to the
correct imported commit; nothing under v0.5.0 disturbed; arc7 left in place") is
met — with the documented correction that the "bootstrap" file in the map is a
phantom.

### 2. What did implementing slice 2 reveal that the arc-plan did not anticipate?

- **The §7a map (and the arc-plan's "bootstrap") names a file that never
  existed** — `RESEARCH-BOOTSTRAP.md` is absent from the imported tree and from
  all of `rebar3_lfe` history. The v0.1.0 loose-file set is **6**, not 7.
- **The `A6·S0` token is not a unique locator** — a later "Sidecar" commit
  references it in its body. The unique anchor is the full message `Implement
  Arc A6·S0`. The v0.2.0/arc8 work, which tags `0.2.0` by the same method,
  should anchor on full messages too, not the short `A·S` token.
- **Planning-tree co-location is split across worktrees.** The `arc7-import/`
  planning docs live in the *main* worktree (uncommitted), not on
  `feature/fezzik-import`, so the intended "v0.1.0/ holds arc1-6 alongside
  arc7-import" end-state only materialises after the branch merges to main and
  those docs are committed. Not a slice defect; a coordination note for the
  merge/close.

### 3. The silent-drop diff at slice scale

- **Specified → delivered:** 6 dev-arc dirs ✓; loose spec/gallery/smoke files ✓
  (6 real, not the phantom 7th); `arc7-rules-v2` left ✓; `0.1.0` tag on A6·S0 ✓;
  history preserved ✓; no code change ✓; v0.5.0/arc7-import untouched ✓.
- **Deferred-with-rationale:** README pointer to the living spec
  (`formatting-rules.md` / `formatting-gallery.md`) — explicitly *not* a slice
  gate (§7a raises it); left as a follow-up.
- **Corrected-not-dropped:** the phantom `RESEARCH-BOOTSTRAP.md` (Amendment 1).
- **Silent drops: none.**

## Slice-close arc-plan update

Part-IV question — *did slice 2 uncover anything that should change
`arc-plan.md`?* — **yes, additively**: the arc-plan's slice-2 line says
"bootstrap", i.e. the phantom file, and its slice-2 gate inherits the same
`0.1.0`-by-message tagging that the `A6·S0` ambiguity touches. The slice
breakdown is otherwise correct and complete (both slices delivered). `arc-plan.md`
updated with a Version History **v1.2** entry naming slice 2 as the source for
(a) the phantom-bootstrap correction and (b) the full-message tag-anchor note
for v0.2.0/arc8. No re-sequencing; no new arc7-import slice.

## Arc-close readiness (this is the arc's last slice)

`arc7-import` has two slices; both are now CC-closed. The arc is **not yet
closed** — per the framework an arc closes only when its last slice is
**CDC-closed**. Pending: `cdc-verification.md` for slices 1 and 2, then the
arc-level `closing-report.md` (composition check: do the two slices recompose
into "Fezzik's code + history live in fmt with the 0.1.0 baseline established"?)
and the bubble-up to the v0.1.0 project. Flagged so the arc close is not
declared by fiat.

## Open items for CDC / operator

- **`cdc-verification.md` pending** (this slice) — re-run the moves/tag checks,
  reproduce the two Amendments, verify the bubble-up.
- **Ratify Amendment 1** (phantom `RESEARCH-BOOTSTRAP.md`) — confirm the v0.1.0
  loose-file set is 6, and consider correcting migration-plan §7a so v0.2.0/arc8
  does not re-encounter it.
- **No `CLAUDE.md`** still (carried from slice 1) to record the confirmed layout
  + close-set convention — raised, not created unilaterally.
