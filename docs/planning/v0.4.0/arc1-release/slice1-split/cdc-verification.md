# CDC verification — v0.4.0 · arc1-release / slice1-split

Verifier: Claude (Cowork chat seat, acting as CDC — independent of CC).
Date: 2026-06-26.
Reviewed: branch `feature/v0.4.0-release`; base `main` `4bf3af0`; split `f4790e1`,
hygiene `46240a5`.

## Verification boundary

Reproduced (git/source) the structural + **layering** claims; the
behaviour-identity golden (A1S1-2) and the toolchain (A1S1-5/-6) are
**attested by CC** (OTP 28 local, sha256 golden) → reconcile via **CI**.

## Per-row verdict

| ID | CC status | CDC verdict | Basis |
|----|-----------|-------------|-------|
| A1S1-1 | done | **reproduced** | 4 artifacts on the branch: `lfmt_fezzik.erl` **57**, `lfmt_fezzik_render.erl` **1087**, `lfmt_fezzik_util.erl` **809**, `lfmt_fezzik.hrl` **5**. (1869 → 1958, the +89 = headers/exports/qualification — sane for a split.) |
| A1S1-2 | done | **attested** (CI) | Byte-identical corpus golden (sha256 `2a7e56b6…` pre/post) — CC-run; can't regenerate without OTP. The right *kind* of proof (reproducible in principle); CI/ct reconciles. |
| A1S1-3 | done | **reproduced** | **Acyclic layering confirmed mechanically:** `render → lfmt_fezzik:` = **0**; `util → render/lfmt_fezzik:` = **0**; `lfmt_fezzik → render/util` = **5** (one-way). Layering `lexer → cst → util → render → fezzik`, lower never calls up. |
| A1S1-4 | done | **reproduced + endorsed** | The 3-module shape (not 4) is the *correct* outcome: the proposed render/clause/data seams cut through one mutually-recursive SCC; separating them = circular module deps. CC kept the SCC whole (`render`) and extracted only acyclic leaves (`util`), **no forced indirection** — exactly the plan's sanction. The 0-up-call result (A1S1-3) is the structural evidence the SCC was respected. |
| A1S1-5 | done | **attested** (CI) | `rebar3 ct` All 274 — CC-run. |
| A1S1-6 | done | **attested** (CI) | compile zero-warning, dialyzer clean (22 files), types/`no_underspecs`/`cst_node()` distributed — CC-run. |
| A1S1-7 | done | **reproduced** | `lfmt_fezzik.erl` exports `format/1` (+ `regime/2` TEST); public entry unchanged. |
| A1S1-8 | done | **reproduced** | commit `f4790e1` = `src/lfmt_fezzik{,_render,_util}.erl` + `.hrl` (split, src-only); commit `46240a5` = `test/lfmt_fezzik_SUITE.erl` (hygiene, test-only). Cleanly separated. |
| A1S1-9 | done | **reproduced** (count = CI) | commit 2 diff shows `conf_wide_sweep` `iolist_to_binary` → `fmt_output_bin` (×2). The "0 skipped (was 2)" count is `ct:log` (CI). Closes arc row A1-5. |
| A1S1-10 | done | **reproduced** | `git diff main..tip -- 'src/pe_*.erl' docs/planning/v0.5.0` → empty; `git tag -l 0.4.0` → none. |

**Tally:** 10 rows walked. 7 reproduced, 3 attested-at-CI-boundary, 0 deferred,
0 no-op, 0 rejected.

## Bubble-up check (Part IV)

1. **Delivered its assigned arc piece?** Yes — the engine is decomposed with
   clean one-way layering, behaviour preserved (golden), and the carried v0.3.0
   hygiene closed.
2. **Silent-drop diff honest?** Yes. The headline deviation (3 modules, not 4)
   was *pre-authorized* by the plan's "split is a proposal / disclose the merged
   seam" sanction — CC computed the SCC, disclosed it, and added no indirection.
   Not a scope amendment; a disclosed design outcome.
3. **Arc-plan change decision.** CC recorded arc-plan v1.2 (the 3-module shape,
   so slice 2 packages the right tarball). **I concur** — and slice 2's
   `slice-doc` lists the exact artifact set (incl. the `.hrl`).

## Findings

- **F1 — computing the SCC before splitting is exemplary (endorse).** "The
  helpers are likely mutually recursive" became a precise, disclosable fact (one
  23-fn SCC across all three proposed seams), which *handed* CC the real seams.
  This is the "split is a proposal" caution paying off exactly as designed — the
  alternative (forcing 4 modules) would have meant circular deps or artificial
  indirection.
- **F2 — the golden is the right refactor proof.** Capturing the 32-file golden
  on `main` *before* the split makes "behaviour identical" a hard sha256 check,
  not a hope on lenient oracles. Reconciles on CI.
- **F3 (low-priority, carry to slice 2) — 31 lines >100 cols in
  `lfmt_fezzik_render.erl`.** A cosmetic consequence of module-qualifying calls;
  CC correctly did **not** run a global `rebar3 fmt` (it would touch the
  already-non-clean `pe_*` files — a scope breach — and the plugin won't take
  per-file args). **Action for slice 2:** confirm whether CI/release enforces
  `erlfmt --check`. If yes, scope erlfmt config or wrap the 31 lines (the repo
  is already not erlfmt-clean, so likely *not* a CI gate); if no, it's cosmetic.
  Does **not** affect tarball validity (line width is irrelevant to the package).

## Closure

**CDC accepts slice 1 (split).** Structure + the load-bearing acyclic-layering
claim independently reproduced; the 3-module SCC-respecting decomposition is the
correct, plan-sanctioned outcome; behaviour-identity + toolchain attested with CI
reconciliation; the v0.3.0 hygiene is closed. Closed first pass.

Next: `slice2-hex-release`. F3 (erlfmt line-width) carried to it as a
confirm-or-disclose item. Arc not closed (slices 2 + 3 remain).

Reviewed by: CDC (Cowork chat seat).
