# Slice 2: docs-and-tag — ledger

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state (reads the moved tree + tag, re-derives the
> tagged commit by message). Implementer never marks its own rows CDC-verified.
> Iteration cap: 5. Project `v0.1.0` · arc `arc7-import` · slice
> `slice2-docs-and-tag`.

## Ledger

> CC self-assessment. Slice base = slice-1 tip `3177954`; moves commit
> `f963976`; tag `0.1.0` → `d2e79c7`. Branch `feature/fezzik-import` (worktree
> `../fmt-fezzik-import`). Every `done` is **proposed-done** until CDC reproduces.

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A7S2-1 | the six `arc1-lexer … arc6-release` dirs moved into `docs/planning/v0.1.0/` | `ls docs/planning/v0.1.0/` | correctness | §7a map | done | `ls docs/planning/v0.1.0/` → `arc1-lexer arc2-cst arc3-printer arc4-indent arc5-provider arc6-release` (+ loose files). Staged as `git mv` renames (33× `R100`), commit `f963976`. | `git mv`, not copy+delete |
| A7S2-2 | the loose spec/gallery files moved into `docs/planning/v0.1.0/` | `ls docs/planning/v0.1.0/*.md` | correctness | §7a map | done | **6** loose files moved: `cc-prompt-gallery`, `cc-prompts`, `formatting-gallery`, `formatting-rules`, `rebar3-lfe-provider`, `SMOKE`. **`RESEARCH-BOOTSTRAP.md` does not exist** and never did (see Amendment 1). | criterion's "seven" corrected to six — Amendment 1 |
| A7S2-3 | history preserved across the moves | `git log --follow docs/planning/v0.1.0/formatting-rules.md \| tail` reaches rebar3_lfe origin | serious | history preservation | done | `--follow formatting-rules.md` → origin `8ea7ada` (2026-06-15, imported); `--follow arc1-lexer/cc-prompt.md` → root `c5bfc71` (2026-06-13). Both cross the `f963976` rename. | sampled one loose file + one dir file |
| A7S2-4 | `arc7-rules-v2/` left in place under `docs/design/022-lfe-format/`, untouched | `ls docs/design/022-lfe-format/` | serious | scope control | done | `ls docs/design/022-lfe-format/` → **only** `arc7-rules-v2`. Not in the slice rename set. | belongs to v0.2.0/arc8 |
| A7S2-5 | `0.1.0` annotated tag created on the imported `A6·S0` commit | `git show 0.1.0 \| head` | serious | migration plan §4 | done | `git show 0.1.0`: annotated tag, Tagger Duncan McGreggor, → commit `d2e79c7`. | rewritten hash; located by message |
| A7S2-6 | the tagged commit is the unique `A6·S0` e2e-CLI commit | `git log --all --grep='A6·S0' --oneline` → single match; matches tag | serious | correctness | done | `--grep='A6·S0'` returns **2** (`d2e79c7` + `e1e5871` "Sidecar", a body-reference). Anchored on the full message `--grep='Implement Arc A6·S0'` → **unique** `d2e79c7` = "Implement Arc A6·S0 — e2e CLI test + fix bare-provider app discovery". Tag resolves there. | guard met via precise anchor — Amendment 2 |
| A7S2-7 | no code change in this slice — docs + tag only | `git diff --stat <base>..HEAD` → only doc renames | serious | scope control | done | `git diff --name-status 3177954..HEAD` → **33× `R100`**, all under `docs/`; `0 insertions, 0 deletions`. No `src/`/`test/`/`rebar.config`. | |
| A7S2-8 | `docs/planning/v0.5.0/` (pe) and `docs/planning/v0.1.0/arc7-import/` (this arc) untouched by the moves | `git diff <base>..HEAD -- docs/planning/v0.5.0 docs/planning/v0.1.0/arc7-import` → empty | serious | scope control | done | `git diff --stat 3177954..HEAD -- docs/planning/v0.5.0 docs/planning/v0.1.0/arc7-import` → **empty**. (arc7-import is not on this branch — it lives in the main worktree; see closing-report.) | |
| A7S2-9 | closing report: final `docs/planning/v0.1.0/` listing + tagged SHA + confirms arc7 remains for v0.2.0 | closing-report check | serious | methodology | done | `closing-report.md` written: final listing, tag SHA `d2e79c7`, arc7-rules-v2 confirmed left for v0.2.0. | |

## Amendments (CC-raised refinements)

1. **`RESEARCH-BOOTSTRAP.md` is a phantom — criterion A7S2-2 corrected from
   "seven loose files" to six.** The migration-plan §7a map and this ledger
   listed `RESEARCH-BOOTSTRAP.md` as a 7th loose file to move. It is **not in
   the imported tree and never existed anywhere in `rebar3_lfe`**:
   `git log --all --follow -- 'docs/design/022-lfe-format/RESEARCH-BOOTSTRAP.md'`
   is empty, and `git -C …/rebar3_lfe log --all -- '**/RESEARCH-BOOTSTRAP.md'`
   is empty. You cannot `git mv` a file that never existed; the 6 real loose
   files are moved. This is a plan error, disclosed — **not** a silent drop.
   Bubbled to `arc-plan.md` ("bootstrap" in its slice-2 line is the same
   phantom).

2. **`--grep='A6·S0'` returns 2 matches, not the "single match" the prompt
   expects.** The second (`e1e5871` "Sidecar: fix r3lfe_prv_clean …") references
   "the A6·S0 fix" in its body. The tag target is unambiguous by full message:
   `--grep='Implement Arc A6·S0'` → unique `d2e79c7`. Tagged that; the literal
   single-match guard was satisfied by tightening the anchor, and the deviation
   is disclosed rather than worked around silently.

## Caveats

- The moved `arcN-*` dirs keep their `rebar3_lfe` archival shape (per-arc
  `cc-prompt-*.md`), not the fmt slice layout — an archived design record, as
  the slice-doc intends.
- `formatting-rules.md` + `formatting-gallery.md` are the **living Fezzik spec**;
  a README pointer to them (migration-plan §7a) is **not** a gate for this slice
  and is left as a follow-up.
- The intended end-state "v0.1.0/ holds arc1-6 **alongside** arc7-import" is not
  visible on `feature/fezzik-import`: the `arc7-import/` planning tree lives in
  the **main worktree** (staged/untracked), not on the branch. The co-location
  resolves when the branch merges to main and the planning docs are committed.

## What Worked

- **Verifying the source before running the prompt's `git mv` loop.** The loop
  would have died on `RESEARCH-BOOTSTRAP.md`; a 30-second history check turned a
  hard failure into a disclosed plan correction.
- **Anchoring the tag on the full commit message, not the short token.** The
  `A6·S0` token alone is ambiguous (2 hits); `Implement Arc A6·S0` is unique.

## Closure

Self-assessed complete. Moves commit `f963976`; tag `0.1.0` → `d2e79c7`
("Implement Arc A6·S0 — e2e CLI test + fix bare-provider app discovery").
Total rows: **9**. Done: **9**. Deferred: **0**. No-op: **0** (A7S2-2 done at
corrected scope of 6 files; the phantom 7th is Amendment 1). CC self-assessment
only — **CDC verification pending** (`cdc-verification.md`). This is the **last
slice of arc7-import**: once CDC closes slices 1 and 2, the arc is ready for its
formal close (arc-level `closing-report.md` + composition check + bubble-up to
the project).
