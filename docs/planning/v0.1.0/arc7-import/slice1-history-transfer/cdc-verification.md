# CDC verification — v0.1.0 · arc7-import / slice1-history-transfer

Verifier: Claude (Cowork chat seat, acting as CDC — independent of the
implementer, CC).
Date: 2026-06-26.
Reviewed: branch `feature/fezzik-import`; base `05fc025`, merge `d879c90`,
corpus re-point `3177954` (slice-1 tip). Imported DAG root `c5bfc71` (rewritten
from `0f74364`).

## Verification boundary (named, per the honesty discipline)

The CDC sandbox has **git, read-only** against all branches but **no OTP/rebar3
toolchain**. So this pass splits cleanly:

- **Reproduced** (I re-ran the Verify and observed the same result): every
  git-checkable row — history, scope, diffs, greps, counts. 7 of 12 rows.
- **Attested, not reproduced here** (CC ran the command and reported output; I
  cannot re-run it in this sandbox): the five toolchain rows — compile, ct,
  xref, dialyzer, OTP-28. Their reconciliation path is **branch CI** (the repo
  carries dialyzer/ct CI jobs); running CI green on `feature/fezzik-import` is
  the `attested → reproduced/reconciled` step, recommended before the arc's
  formal close.

This is the same boundary the pe slice CDC passes recorded; I state it up front
rather than implying I ran a toolchain I do not have.

## Per-row verdict

| ID | CC status | CDC verdict | Basis (what I actually ran / read) |
|----|-----------|-------------|-------------------------------------|
| A7S1-1 | done | **reproduced** | `git diff --name-status 05fc025..3177954` = exactly the 8 imported paths' files (3 `src/r3lfe_*`, 3 suites, `tq_corpus.lfe`, the whole `docs/design/022-lfe-format/` tree). Engine-src commit count = **29** (matches). See F4 on the 43/44. |
| A7S1-2 | done | **reproduced** | Root `c5bfc71` author-date `2026-06-13 16:56` + committer-date `2026-06-15 12:02` are **identical** to original `0f74364`. `--follow`: lexer→`c5bfc71` (root), formatter→`ce03797` (A3 birth), cst→`e3bbade` (arc2 birth) — exactly as CC stated. History preserved. |
| A7S1-3 | done | **attested** (boundary) | `rebar3 compile` zero-warning — CC-run; not reproducible without OTP. CI reconciles. |
| A7S1-4 | done | **attested** (boundary) | 3 suites runnable + `lfe` dep resolves — CC-run. Diff confirms suites present + `tq_corpus.lfe` imported (reproduced); the *run* is attested. |
| A7S1-5 | done | **reproduced** (mechanism) | Re-point commit `3177954` touches **only** the 3 suites (no `src/`). Diff = `integration_files/0` → `code:lib_dir(lfe)` + `is_seven_bit_ascii/1` filter on `full_corpus/0` (the inline-oracle feed); `conf_wide_sweep`/`corpus_sweep_all` retain `integration_files() ++ tq_corpus` over the full 32 files. Oracle bodies unchanged. See F1. The *32-file count* itself is attested (ct:log). |
| A7S1-6 | done | **attested** (boundary) | "All 274 tests passed" — CC-run; CI reconciles. The diff structure is consistent with the claim. |
| A7S1-7 | done | **attested** (boundary) | `rebar3 xref` exit 0 — CC-run. |
| A7S1-8 | done | **attested** (boundary) | `rebar3 dialyzer` 20 files no warnings — CC-run. |
| A7S1-9 | done | **reproduced** | `git diff --stat 05fc025..3177954 -- 'src/pe_*.erl' 'test/pe_*' docs/planning/v0.5.0` → **empty**. pe + v0.5.0 provably untouched. |
| A7S1-10 | done | **reproduced** | `git grep 'lfmt_' 3177954 -- src test` → **0**. `git tag --contains 3177954` → **none** (slice1 created no tags; the `0.1.0` tag from slice2 points at the historical `A6·S0` commit, not a descendant of the tip). |
| A7S1-11 | done | **reproduced** | Caveats present + specific (exact 32-file corpus enumerated; large-file test re-pointed at `guard_SUITE.lfe`, ran not skipped). |
| A7S1-12 | done | **attested** (boundary) | OTP-28 green — folds into A7S1-3/-6/-8; CI reconciles. |

**Tally:** 12 rows walked (matches the 12-row open ledger — no silent drops).
7 reproduced, 5 attested-at-boundary (toolchain), 0 deferred, 0 no-op, 0
rejected.

## Bubble-up check (PROJECT-MANAGEMENT Part IV)

1. **Delivered its assigned arc piece?** Yes — confirmed against the arc-plan
   slice-1 gate. History preserved (reproduced), corpus made real (32 files,
   reproduced mechanism), suites green (attested). The arc's "code + history +
   green suites" half is delivered.
2. **Silent-drop diff honest?** Yes. The two Unicode files are **not dropped** —
   I verified they remain in `conf_wide_sweep`/`corpus_sweep_all` (full corpus);
   only the *inline-oracle* feed (the buggy `iolist_to_binary` path) excludes
   them. The harness fix is genuinely out of arc7-import scope (import + docs/
   tag) and is routed upward. No silent drops.
3. **Arc-plan change decision.** CC already updated `arc-plan.md` (v1.1) with the
   Unicode harness finding and the `--follow` wording correction, with no
   slice-breakdown change. **I concur:** slices 1 & 2 stand; no re-sequencing or
   new arc7-import slice is forced. One CDC-added condition — see F5.

## Findings

- **F1 — The Unicode handling is scope-preserving, not spec-softening (endorse).**
  This was the row most at risk of a softpedalled `done`. The diff shows the
  restriction lives only in the inline-oracle discovery (`full_corpus/0`); the
  same idempotence/token/AST-equivalence properties are still asserted on
  `core-macros.lfe` and `clj-tests.lfe` via the Unicode-safe sweep path. No
  coverage is lost; the buggy path is simply not fed inputs it corrupts. Honest.

- **F2 — Toolchain rows rest on CC attestation, not CDC reproduction (boundary,
  not defect).** Five rows (compile/ct/xref/dialyzer/OTP-28) cannot be re-run in
  the CDC sandbox. CC's evidence is specific (274 tests, 20 dialyzer files, exit
  codes) and credible, but the independent `reproduced` step is **CI on
  `feature/fezzik-import`**. Recommend running it before the arc closes; the arc
  composition check (Part V) wants this green anyway.

- **F3 — `--follow` gate wording correction is valid (endorse).** The original
  gate ("`--follow` back to `0f74364` on each module") is unsatisfiable for the
  formatter/cst (a file can't be followed before it was born). CC's reframing
  (DAG root is `0f74364`→`c5bfc71`; per-file `--follow` reaches each file's
  birth) is correct and already bubbled into the arc-plan. Reproduced.

- **F4 — 43 vs 44 commit count, reconciled (no defect).** CC reports 43 imported
  commits touch the 8 paths; my `git log 05fc025..3177954` over those paths
  returns 44. The difference is exactly the **local re-point commit `3177954`**
  (which edits the 3 suites, themselves among the 8 paths): 43 imported + 1
  local = 44. The engine-src count (29) matches with no ambiguity. Both figures
  are correct under their stated denominator.

- **F5 — The routed Unicode harness fix needs a concrete home before it can be
  lost (CDC action item).** It currently lives only in `arc-plan.md`'s "Findings
  carried forward" / Version History, recommended for "v0.3.0 or earlier." That
  is adequate *tracking* but not yet a *planned slice*. Recommend recording it
  explicitly in `v0.3.0/arc1-rename`'s arc-plan (or a dedicated harness-fix
  slice) when that arc is planned, so a finding surfaced in v0.1.0 is not
  orphaned across two project boundaries. Not a slice-1 blocker.

## Closure

**CDC accepts slice 1 (history-transfer).** The git-verifiable core — history
preservation, scope containment, the corpus re-point mechanism, pe/v0.5.0
isolation, no rename/tag leakage — is **independently reproduced** and clean.
The five toolchain rows are **attested by CC** with CI as the named
reconciliation path (F2). The bubble-up is honest and the arc-plan was updated
correctly. No iterations required (closed first pass).

Conditions carried to arc close: (1) CI green on `feature/fezzik-import`
reconciles the toolchain rows; (2) the Unicode harness fix gets a planned home
(F5).

Reviewed by: CDC (Cowork chat seat). Independent gate for the *arc* close
(Part V) should be a fresh context or the operator, not this seat.
