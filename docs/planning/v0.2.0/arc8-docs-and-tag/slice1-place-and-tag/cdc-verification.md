# CDC verification — v0.2.0 · arc8-docs-and-tag / slice1-place-and-tag

Verifier: Claude (Cowork chat seat, acting as CDC — independent of CC).
Date: 2026-06-26.
Reviewed: branch `feature/fezzik-import`; slice base `f963976`, move commit
`51fc1af`, tag `0.2.0` → `5334ff8`.

## Verification boundary

Docs-and-tag only — **no toolchain rows**. Every one of the 8 rows is
git-checkable and was **independently reproduced** in the CDC sandbox.

## Per-row verdict

| ID | CC status | CDC verdict | Basis (what I ran) |
|----|-----------|-------------|---------------------|
| A8S1-1 | done | **reproduced** | `51fc1af` = **26 `R100`** renames, **all** under `docs/planning/v0.2.0/arc7-rules-v2/` (grep for any path outside it → empty). |
| A8S1-2 | done | **reproduced** | `--follow …/arc7-rules-v2/cc-prompt.md` → origin `8ea7ada` (2026-06-15, imported), crossing the `51fc1af` rename. |
| A8S1-3 | done | **reproduced** | `git ls-tree feature/fezzik-import -- docs/design/022-lfe-format` → **0 entries** (staging dir gone). |
| A8S1-4 | done | **reproduced** | `0.2.0` is `type=tag` (annotated), tagger Duncan, → `5334ff8`, subj "A7·S6 — gallery regen + full sweep"; full-message grep → **unique**. |
| A8S1-5 | done | **reproduced** | `git merge-base --is-ancestor 0.1.0 0.2.0` → 0 (`0.1.0 < 0.2.0`). |
| A8S1-6 | done | **reproduced** | `f963976..51fc1af` = 26 `R100`, **0 insertions / 0 deletions**; no `src/`/`test/`/`rebar.config`. |
| A8S1-7 | done | **reproduced** | `git show --stat 51fc1af -- docs/planning/v0.1.0 docs/planning/v0.5.0` → **empty**. |
| A8S1-8 | done | **reproduced** | `closing-report.md` present in the slice dir (per-row walk + bubble-up). |

**Tally:** 8 rows walked (matches the 8-row open ledger). 8 reproduced, 0
attested-only, 0 deferred, 0 no-op, 0 rejected. No amendments (the two
v0.1.0/slice-2 findings were pre-absorbed into the v0.2.0 plan — confirmed: the
full-message anchor and the absent phantom both appear in project-plan v1.0 /
arc-plan v1.1, so neither re-surfaced).

## Bubble-up check (Part IV)

1. **Delivered its assigned arc piece?** Yes — the v0.2.0 design record is placed
   and the `0.2.0` tag marks the refined-brute tip, exactly the arc8 capability.
2. **Silent-drop diff honest?** Yes — specified→delivered complete (move + dir
   removal + tag); no drops. The README-pointer follow-up is correctly
   non-gating.
3. **Arc-plan change decision.** CC asked the Part-IV question and recorded a
   **"no change"** verdict (the plan anticipated the anchor, the phantom, and
   the tag decision) rather than bumping the Version History hollowly. **I
   concur** — a "no change, asked-and-answered" outcome is valid and correctly
   *not* a vacuous version bump.

## Findings

- **F1 — clean reuse of prior-arc findings (endorse).** The full-message tag
  anchor and the no-phantom expectation were pre-absorbed into the v0.2.0 plan,
  so the ambiguous-token trap was avoided *by design*, not re-tripped. This is
  the bubble-up loop working as intended — a v0.1.0 discovery prevented a
  v0.2.0 defect.
- **F2 — no CI dependency at this scale.** Unlike v0.1.0 (whose toolchain rows
  await CI), v0.2.0 is pure docs+tag, so the slice/arc/project composition is
  fully reproducible now. No reconciliation pending.

## Closure

**CDC accepts slice 1 (place-and-tag).** All 8 rows independently reproduced;
bubble-up honest; no amendments; closed first pass. As arc8's only slice, this
feeds directly into the arc close (`closing-report.md`, assembled next).

Reviewed by: CDC (Cowork chat seat).
