# Slice 1: namespace-rename — closing report

> CC closing report (implementer self-assessment). Independent verification is
> CDC's, in `cdc-verification.md` (not yet written). Every `done` is
> **proposed-done** until CDC reproduces it (toolchain rows reconcile via CI).
> Project `v0.3.0` · arc `arc1-rename` · slice `slice1-namespace-rename`.
> Base `feature/fezzik-import` (`51fc1af`); rename commit `e469d0f`; branch
> `feature/v0.3.0-namespace` (worktree `../fmt-v0.3.0-namespace`).

## Per-row walk

12 rows at open; **12 walked** (no silent drops; count matches `ledger.md`).
Full Verify output is in `ledger.md`; one-line disposition per row here.

| ID | Status | Evidence (summary) |
|----|--------|--------------------|
| A1S1-1 | done | 3 engine modules renamed `R078/R095/R099`, `-module(lfmt_fezzik*)`. |
| A1S1-2 | done | 3 suites + data dir renamed `R096/R066/R071/R100`; data-dir refs updated. |
| A1S1-3 | done | `grep -rn r3lfe src test` → **empty** (581 occurrences resolved). |
| A1S1-4 | done | app `fmt`→`lfmt` (`lfmt.app.src`/`lfmt.erl`, vsn `0.3.0`); rebuilds as `lfmt`. |
| A1S1-5 | done | hex metadata staged (licenses, GitHub link, `rebar3_hex`); not published. |
| A1S1-6 | done | `rebar3 compile` zero-warning. |
| A1S1-7 | done | `rebar3 ct` → **All 274 passed** (under the carried ASCII restriction). |
| A1S1-8 | done | `rebar3 xref` clean. |
| A1S1-9 | done | `rebar3 dialyzer` clean (20 files). |
| A1S1-10 | done* | pe diff = the **one** app-name-follow line in `pe_lfe.erl`; v0.5.0 untouched. *Amendment 1. |
| A1S1-11 | done | whole-slice diff is identifier-subs + app-metadata + the one `priv_dir` line — names-only. |
| A1S1-12 | done | `git tag -l 0.3.0` → empty. |

**Totals: 12 done · 0 deferred · 0 no-op** (A1S1-10 done under the operator-
confirmed amendment). Strength: all rows **reproduced** locally (toolchain rows
additionally "CI reconciles" per the arc plan). One amendment, disclosed.

## Bubble-up to the arc (arc1-rename)

### 1. Did slice 1 deliver the piece of the arc's capability the arc-plan assigned it?

Yes. The arc-plan slice-1 row: *the pure mechanical rename — `r3lfe_format*` →
`lfmt_fezzik*` (3 modules + 3 suites + `_SUITE_data`), all cross-refs/types, app
`fmt` → `lfmt`, stage hex metadata; names-only diff; `grep -rn r3lfe` empty;
compile/ct/xref/dialyzer green; `pe_*`/v0.5.0 untouched.* All delivered: zero
`r3lfe` survives, app is `lfmt` (vsn `0.3.0`, metadata staged not published),
toolchain green, the diff is names-only. The v0.1.0 ASCII restriction is left
intact for slice 2 (as the arc-plan sequences it).

### 2. What did implementing this slice reveal that the arc-plan did not anticipate?

- **(Load-bearing) The app rename is *not* "names-only with `pe_*` untouched" —
  it forces exactly one `pe_*` line.** `pe_lfe.erl` `base_rules_path/0` does
  `code:priv_dir(fmt)` (the default rule-registry load path). Renaming the app
  to `lfmt` makes `priv_dir(fmt)` return `{error, bad_name}` → crash → `ct`
  fails. The fix is a one-token app-name-follow (`priv_dir(lfmt)`), no pe logic.
  This is precisely "an app-name reference that made it more than names-only"
  the bubble-up prompt names. Surfaced before editing, operator-confirmed, and
  the gate A1S1-10 was relaxed to "`pe_*` untouched **except the one app-name
  reference the rename requires**" (ledger Amendment 1). **Relevant to the arc
  composition row A1-3** ("`pe_*`/v0.5.0 untouched"), which inherits the same
  one-line exception — bubbled to `arc-plan.md` Version History.
- **`src/fmt.erl` → `src/lfmt.erl` renders as delete+add, not a rename.** A
  3-line stub; the `-module` change dropped it below git's 50% rename threshold.
  Verified the only content diff is the `-module` line. No engine-history loss.

### 3. The silent-drop diff at slice scale

- **Specified → delivered:** module/suite/data-dir renames ✓; all cross-refs +
  type ✓; `grep r3lfe` empty ✓; app `fmt`→`lfmt` + vsn + metadata staged ✓;
  compile/ct/xref/dialyzer green ✓; names-only ✓; no `0.3.0` tag ✓.
- **Disclosed-not-dropped:** the one `pe_lfe` app-name-follow line (Amendment 1).
- **Deferred (planned, not dropped):** the Unicode harness fix + ASCII-restriction
  removal → slice 2, exactly as the arc-plan sequences.
- **Silent drops: none.**

## Slice-close arc-plan update

Part-IV question — *did slice 1 uncover anything that should change
`arc-plan.md`?* — **yes, additively** (no slice-breakdown change): the arc
composition row **A1-3** asserts "`pe_*`/v0.5.0 untouched", which slice 1 showed
must carry a one-line exception (the `pe_lfe` `priv_dir` app-name-follow).
Recorded in `arc-plan.md` Version History (v2.1) naming slice 1 as the source,
so the arc-close composition check verifies the *accurate* claim. Slices 1 & 2
stand; no re-sequencing.

## Open items for CDC / operator

- **`cdc-verification.md` pending** — reproduce `grep -rn r3lfe` (empty), the
  pe one-line diff, the names-only property, and (via CI) compile/ct/xref/dialyzer.
- **Ratify Amendment 1** (the `pe_lfe` app-name-follow) at the arc level — it is
  the one place this slice crossed the "`pe_*` untouched" line, by necessity.
- **No `CLAUDE.md`** still records the layout/close-set convention (carried from
  v0.1.0/v0.2.0) — raised, not created unilaterally.
- **Base reminder:** this branches off `feature/fezzik-import` (not `main`) per
  operator decision; the v0.1.0/v0.2.0 → `main` merge is still outstanding.
