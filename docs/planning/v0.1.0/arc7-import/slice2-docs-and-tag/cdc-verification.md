# CDC verification — v0.1.0 · arc7-import / slice2-docs-and-tag

Verifier: Claude (Cowork chat seat, acting as CDC — independent of CC).
Date: 2026-06-26.
Reviewed: branch `feature/fezzik-import`; slice base `3177954`, moves commit
`f963976`, tag `0.1.0` → `d2e79c7`.

## Verification boundary

Slice 2 is **docs-and-tag only — no toolchain rows**, so unlike slice 1 there is
no attestation gap: every one of the 9 rows is git-checkable and was
**independently reproduced** in the CDC sandbox.

## Per-row verdict

| ID | CC status | CDC verdict | Basis (what I ran) |
|----|-----------|-------------|---------------------|
| A7S2-1 | done | **reproduced** | `git ls-tree feature/fezzik-import -- docs/planning/v0.1.0` → `arc1-lexer arc2-cst arc3-printer arc4-indent arc5-provider arc6-release` all present. |
| A7S2-2 | done | **reproduced** (corrected scope) | 6 loose files present (`SMOKE`, `cc-prompt-gallery`, `cc-prompts`, `formatting-gallery`, `formatting-rules`, `rebar3-lfe-provider`); no `RESEARCH-BOOTSTRAP.md`. The "seven" was a plan error (see F1) — correctly handled as Amendment 1, not a silent drop. |
| A7S2-3 | done | **reproduced** | `--follow` crosses the `f963976` rename: `formatting-rules.md` → `8ea7ada` (imported A7·S2a, 2026-06-15); `arc1-lexer/cc-prompt.md` → root `c5bfc71` (2026-06-13). History intact. |
| A7S2-4 | done | **reproduced** | `git ls-tree feature/fezzik-import -- docs/design/022-lfe-format/` → **only** `arc7-rules-v2`. Left for v0.2.0/arc8. |
| A7S2-5 | done | **reproduced** | `git for-each-ref refs/tags/0.1.0` → `type=tag` (annotated), tagger Duncan McGreggor, target `d2e79c7`, subject "Implement Arc A6·S0 …". |
| A7S2-6 | done | **reproduced** | `--grep='A6·S0'` → **2** commits; `--grep='Implement Arc A6·S0'` → **unique** `d2e79c7`. Confirms the ambiguity and the correct anchor (Amendment 2). |
| A7S2-7 | done | **reproduced** | `f963976` = **33 files, 0 insertions, 0 deletions, all `R100`** (pure renames); every path under `docs/`. No `src/`/`test/`/`rebar.config`. |
| A7S2-8 | done | **reproduced** | `git show --stat f963976 -- docs/planning/v0.5.0 docs/planning/v0.1.0/arc7-import` → **empty**. pe + the migration arc untouched. |
| A7S2-9 | done | **reproduced** | `closing-report.md` present with final listing, tag SHA `d2e79c7`, and arc7-rules-v2 confirmed left for v0.2.0. |

**Tally:** 9 rows walked (matches the 9-row open ledger — no silent drops).
9 reproduced, 0 attested-only, 0 deferred, 0 no-op, 0 rejected.

## Bubble-up check (PROJECT-MANAGEMENT Part IV)

1. **Delivered its assigned arc piece?** Yes — the 0.1.0 design record is placed
   and the `0.1.0` baseline tag exists, exactly the arc-plan slice-2 gate.
2. **Silent-drop diff honest?** Yes. Specified→delivered is complete at the
   *corrected* scope (6 dirs + 6 loose files + tag); the phantom 7th file is a
   disclosed plan error, not a drop. The README-pointer for the living spec is
   correctly carried as a non-gating follow-up.
3. **Arc-plan change decision.** CC updated `arc-plan.md` (v1.2) with both
   findings, no slice-breakdown change. **I concur.** Two CDC follow-throughs:
   F1 (fix migration-plan §7a — done in this pass) and F2 (propagate the
   full-message tag anchor to v0.2.0/arc8).

## Findings

- **F1 — `RESEARCH-BOOTSTRAP.md` is untracked, and the error is mine (fixed).**
  The precise status: the file **exists on disk** in `rebar3_lfe` but is
  **untracked** (`git status` → `??`, no history) — so `filter-repo` could not
  import it, and CC could not `git mv` it. CC's "never existed [in history]" is
  correct for git purposes; "untracked" is the exact nuance. The root cause is
  **my** migration-plan §7a, which listed it (I had seen it in a working-tree
  `ls` and didn't notice it was uncommitted). I have **corrected §7a** in this
  pass: dropped `RESEARCH-BOOTSTRAP.md`, count now 6 loose files, with a dated
  note. CC's handling (move the 6 real files, disclose the 7th as Amendment 1)
  was exactly right.

- **F2 — full-message tag anchor must propagate to v0.2.0/arc8.** The `A6·S0`
  token matched 2 commits; `0.2.0` faces the same risk (the refined-brute tip
  message). `v0.2.0/arc8-docs-and-tag/arc-plan.md` should instruct anchoring the
  `0.2.0` tag on a full, unique commit message, not a short token. (Action item
  for when arc8 is executed; recorded here.)

- **F3 — `formatting-rules.md` --follow origin is an imported A7 commit, not the
  root (expected).** It traces to `8ea7ada` (A7·S2a), the file's last
  substantive touch in the imported history — history is preserved across the
  rename; a per-file `--follow` reaching the file's own history (not the DAG
  root) is correct, same pattern as slice 1's F3.

## Closure

**CDC accepts slice 2 (docs-and-tag).** All 9 rows independently reproduced;
no toolchain boundary; bubble-up honest; arc-plan updated correctly. The one
defect surfaced was in my own plan doc (§7a), now fixed (F1). No iterations
required (closed first pass).

**This was arc7-import's last slice. Both slices are now CDC-closed** → the arc
is ready for its formal close (arc-level `closing-report.md` + composition check
+ bubble-up to the v0.1.0 project), subject to the open structural decisions
raised to the operator (arc-ledger retrofit; project-close shape; independent
arc-gate identity) and the CI reconciliation of slice 1's toolchain rows.

Reviewed by: CDC (Cowork chat seat).
