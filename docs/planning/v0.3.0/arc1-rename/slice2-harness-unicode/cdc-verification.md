# CDC verification — v0.3.0 · arc1-rename / slice2-harness-unicode

Verifier: Claude (Cowork chat seat, acting as CDC — independent of CC).
Date: 2026-06-26.
Reviewed: branch `feature/v0.3.0-namespace`; base `e469d0f` (slice 1), fix commit
`d70d8b1`.

## Verification boundary

Reproduced (git/source) every structural row; the four-way toolchain result
(ct/compile/xref/dialyzer) is **attested by CC** (OTP 28 local), reconciled via
**CI on the branch**.

## Per-row verdict

| ID | CC status | CDC verdict | Basis |
|----|-----------|-------------|-------|
| A1S2-1 | done | **reproduced** | `fmt_output_bin/1` defined (L719), used in the **four** corpus-fed inline oracles — `assert_idempotent` (L707/709), `assert_token_preservation` (L729), `assert_ast_equiv` (L739), `assert_comment_preservation` (L1137, the Amendment-1 fourth). Remaining `iolist_to_binary` calls are non-corpus tests (hardcoded ASCII literals) or the input-side flatten — verified by reading the sites. |
| A1S2-2 | done | **reproduced** | `git grep is_seven_bit_ascii d70d8b1 -- test` → **empty**; `full_corpus/0` filter gone. |
| A1S2-3 | done | **attested** (CI) | Count 82→84 (the 2 multibyte files now feed the inline oracles) is a `ct:log` value — the *code path* that includes them is reproduced (no filter); the pass itself is ct/CI. |
| A1S2-4 | done | **attested** (CI) | `rebar3 ct` All 274 — CC-run. |
| A1S2-5 | done | **attested** (CI) | compile zero-warning, xref + dialyzer clean — CC-run. |
| A1S2-6 | done | **reproduced** | `git diff --name-only e469d0f..d70d8b1` → **only** `test/lfmt_fezzik_SUITE.erl`. |
| A1S2-7 | done | **reproduced** | `git diff --stat e469d0f..d70d8b1 -- src docs/planning/v0.5.0` → **empty** (engine + pe + v0.5.0 untouched). |
| A1S2-8 | done | **reproduced** | `closing-report.md` present with the input count + "carried v0.1.0 finding CLOSED". |

**Tally:** 8 rows walked. 5 reproduced, 3 attested-at-CI-boundary, 0 deferred,
0 no-op, 0 rejected.

## Bubble-up check (Part IV)

1. **Delivered its assigned arc piece?** Yes — the inline oracles are
   Unicode-safe (`fmt_output_bin`), the ASCII carve-out is gone, and the corpus
   feeds all 84 inputs.
2. **Silent-drop diff honest?** Yes. The one unanticipated item — a **fourth**
   inline oracle (`assert_comment_preservation`) with the same bug — was caught
   by the gate (first ct run failed `oracle_comment_preservation`), fixed
   identically, and disclosed as Amendment 1 + bubbled to arc-plan v2.2. No
   silent drops.
3. **Arc-plan change decision.** CC recorded arc-plan v2.2 (fourth helper; A1-4
   carried-finding closed), no slice-breakdown change. **I concur.**

## Findings

- **F1 — the fourth-helper amendment is exemplary protocol behaviour (endorse).**
  Lifting the ASCII restriction *surfaced* `assert_comment_preservation`'s
  identical `iolist_to_binary` bug on the first ct run — the gate caught the
  prompt's incomplete enumeration, not guesswork. CC fixed it within the slice's
  stated *purpose* ("make the inline oracle helpers Unicode-safe") and disclosed
  it. This is the per-row-walk discipline doing its job.
- **F2 — the carried v0.1.0 finding is genuinely closed (verified).** The
  inline-oracle `iolist_to_binary`→`unicode:characters_to_binary` fix + the
  removed carve-out is exactly the disposition v0.1.0 routed here. Arc-ledger
  A1-4 closes.
- **F3 (new, low-priority — NOT a slice-2 defect) — `conf_wide_sweep` still
  silently skips the 2 multibyte files.** `conf_wide_sweep` is a *separate*
  skip-on-error sweep (try/catch + `Skipped` counter) that flattens with
  `iolist_to_binary`, which **throws** on codepoints >255 → the two multibyte
  files are caught and counted as *skipped*, not exercised. This is **not a
  coverage gap**: `corpus_sweep_all` (which uses `unicode:characters_to_binary`)
  *does* cover them, and now so do the four inline oracles. It's a residual
  inconsistency with the "honest harness" goal (a "wide sweep" that quietly skips
  2 files), out of slice 2's gate (inline oracles + `is_seven_bit_ascii`).
  **Recommended hygiene follow-up** (v0.4.0 or a later slice): switch
  `conf_wide_sweep`'s flatten to `fmt_output_bin` so it stops silently skipping
  multibyte input. Logged here so it isn't lost.

## Closure

**CDC accepts slice 2 (harness-unicode).** Structural rows reproduced; toolchain
rows attested with CI reconciliation; the fourth-helper amendment is sound; the
carried v0.1.0 finding is closed. Closed first pass.

**Both slices of arc1-rename are now CDC-closed** → the arc is ready for its
close (`closing-report.md`, the `0.3.0` tag, then the v0.3.0 project close), with
CI green on the branch as the toolchain reconciliation. F3 is carried forward as
a non-blocking hygiene item.

Reviewed by: CDC (Cowork chat seat).
