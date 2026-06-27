# v0.3.0 — project closing report

> Project-level close for **v0.3.0** (Namespace under lfmt + honest harness).
> Assembled by **CDC**; the **project gate (go / adjust / kill) is the
> operator's**, with an independent context, PENDING. Branch
> `feature/v0.3.0-namespace` (tip `d70d8b1`).

## 1. Definition of done — verdict

**Met** (toolchain pending CI). Fezzik is `lfmt`-namespaced (modules + app, vsn
`0.3.0`, hex metadata staged-not-published); the inline test harness is
unicode-honest with no ASCII carve-out; `pe`/v0.5.0 untouched bar the single
app-name line the rename forces. Boundaries held: no `pe_*` rename, no split,
no publish.

## 2. Arc walk

One arc in the roadmap; **one** walked.

| Arc | Outcome | Close |
|-----|---------|-------|
| `arc1-rename` | **delivered** | `arc1-rename/closing-report.md` — 4 arc-ledger rows done (toolchain via CI); both slices CDC-closed; `0.3.0` tag + gate operator-pending. |

## 3. Composition check (Project Ledger per-row walk)

| ID | Class | Status | Evidence |
|----|-------|--------|----------|
| P-1 | (a) arc closed | **done** | `arc1-rename/closing-report.md` — assembled, 4/4 rows; arc gate operator-pending. |
| P-2 | (b) DoD demonstrable | **done (toolchain = CI)** | At project scale on `feature/v0.3.0-namespace`: `git grep r3lfe` empty; `lfmt_fezzik*` + app `lfmt`; `is_seven_bit_ascii` gone; `pe_*` diff = one app-name line; v0.5.0 untouched. compile/ct(274)/xref/dialyzer CC-attested → **CI reconciles**. `0.3.0` tag = operator step (see arc close §5). |
| P-3 | (c) findings dispositioned | **done** | Carried **v0.1.0 Unicode-harness finding CLOSED** (slice 2). New finding (conf_wide_sweep) routed to v0.4.0 — see §4. |

**Silent-drop diff at project scale:** DoD-as-specified vs as-delivered — all
present; toolchain disclosed + CI-routed. No silent drops.

**Tally:** 3 project-ledger rows done (P-2 toolchain via CI). 0 deferred, 0 no-op.

## 4. Findings carried out of the project

- **Closed here:** the v0.1.0 Unicode-harness finding (was the *carried-in* item)
  — disposition delivered by slice 2. The loop v0.1.0 opened is shut.
- **New, routed to v0.4.0 (non-blocking hygiene):** `conf_wide_sweep` flattens
  with `iolist_to_binary` and so silently *skips* the 2 multibyte corpus files.
  **Not a coverage gap** (`corpus_sweep_all` + the four inline oracles cover
  them), but inconsistent with the honest-harness goal. Recommended: align its
  flatten with `fmt_output_bin` during v0.4.0 (it touches the suite anyway), or a
  small hygiene slice. Logged in slice-2 `cdc-verification.md` F3 + arc close §6.

## 5. Project gate (operator)

**PENDING — operator (Duncan), with an independent context.** go / adjust / kill
against the DoD. Recommended: **go**, conditioned on **CI green on
`feature/v0.3.0-namespace`** (reconciles the toolchain rows).

**Operator steps to complete the close (sandbox can't do git):**
1. CI green on the branch → reconciles P-2 toolchain.
2. Tag `0.3.0` (annotated) on the v0.3.0 tip; verify `0.2.0 < 0.3.0`.
3. **Merge into `main`** — and this is the gate before v0.4.0: per the
   branch/merge strategy, `main` must carry **v0.1.0 + v0.2.0 + v0.3.0** before
   the v0.4.0 branch is cut. Cleanest: merge `feature/fezzik-import` (v0.1.0+
   v0.2.0) → `main`, then `feature/v0.3.0-namespace` → `main`, then tag `0.3.0`
   on `main`. (We're three branches deep off `feature/fezzik-import`; this is the
   consolidation point.)

Completing these unblocks the **v0.4.0** project (split → publish → integrate),
which branches off the fully-merged `main` — the first project that publishes to
hex, and the home for the `conf_wide_sweep` hygiene follow-up.

Assembled by: CDC (Cowork chat seat), 2026-06-26.
