# CDC verification — v0.3.0 · arc1-rename / slice1-namespace-rename

Verifier: Claude (Cowork chat seat, acting as CDC — independent of CC).
Date: 2026-06-26.
Reviewed: branch `feature/v0.3.0-namespace`; base `51fc1af`, rename commit
`e469d0f`.

## Verification boundary

First code-change slice → split evidence:
- **Reproduced** (re-ran in the CDC sandbox): every git-checkable row — the
  rename set, `grep r3lfe`, the `pe_*` diff, names-only, app rename, hex
  staging, deps, tag absence. 8 of 12 rows.
- **Attested, not reproduced here** (CC ran locally on OTP 28; no toolchain in
  the CDC sandbox): the four engineering-bar rows — compile, ct, xref,
  dialyzer. Reconcile via **CI on `feature/v0.3.0-namespace`**.

## Per-row verdict

| ID | CC status | CDC verdict | Basis |
|----|-----------|-------------|-------|
| A1S1-1 | done | **reproduced** | `git diff -M` → `R078 lfmt_fezzik.erl`, `R095 _cst`, `R099 _lexer` (renames detected, history preserved). |
| A1S1-2 | done | **reproduced** | `R096 _SUITE`, `R066 _cst_SUITE`, `R071 _lexer_SUITE`, `R100 _SUITE_data/tq_corpus.lfe`. |
| A1S1-3 | done | **reproduced** | `git grep -c r3lfe e469d0f -- src test` → **no matches**. The load-bearing rename check holds. |
| A1S1-4 | done | **reproduced** | `lfmt.app.src` = `{application, lfmt, [{vsn,"0.3.0"}…]}`; `fmt.app.src`→`lfmt.app.src` (R067); `fmt.erl`→`lfmt.erl`. App-name follow = the one `pe_lfe` line (F1). |
| A1S1-5 | done | **reproduced** | `lfmt.app.src` carries `{licenses,["Apache-2.0"]}` + GitHub `{links…}`; `rebar.config` `project_plugins` has `rebar3_hex`; `{deps, []}` unchanged. No publish. |
| A1S1-6 | done | **attested** (CI) | `rebar3 compile` zero-warning as `lfmt` — CC-run. |
| A1S1-7 | done | **attested** (CI) | `rebar3 ct` All 274 passed (under the still-present ASCII restriction) — CC-run. |
| A1S1-8 | done | **attested** (CI) | `rebar3 xref` clean — CC-run. |
| A1S1-9 | done | **attested** (CI) | `rebar3 dialyzer` clean, `no_underspecs` carried — CC-run. |
| A1S1-10 | done (amended) | **reproduced** | `git diff -- 'src/pe_*.erl'` = **exactly one line** (`pe_lfe.erl` `priv_dir(fmt)`→`priv_dir(lfmt)`); `docs/planning/v0.5.0` diff empty. See F1. |
| A1S1-11 | done | **reproduced** | Filtered the renderer diff for any changed line *not* an identifier/module substitution → **empty**. Names-only proven mechanically, not eyeballed. |
| A1S1-12 | done | **reproduced** | `git tag -l 0.3.0` → none (tag is created at arc close, after slice 2). |

**Tally:** 12 rows walked (matches the 12-row open ledger). 8 reproduced,
4 attested-at-CI-boundary, 0 deferred, 0 no-op, 0 rejected.

## Bubble-up check (Part IV)

1. **Delivered its assigned arc piece?** Yes — Fezzik is `lfmt`-namespaced
   (modules + app), `grep r3lfe` empty, toolchain green (attested).
2. **Silent-drop diff honest?** Yes. The one item the plan didn't anticipate —
   an app-name reference *inside* `pe_lfe` — was surfaced, operator-confirmed,
   amended (A1S1-10), and bubbled to `arc-plan.md` v2.1. No silent drops; the
   ASCII restriction is explicitly *left* for slice 2 (disclosed, not dropped).
3. **Arc-plan change decision.** CC updated `arc-plan.md` v2.1 so arc
   composition row A1-3 now reads "`pe_*` untouched **except the single
   app-name reference the rename requires**." **I concur** — that is the
   accurate composition claim, and the arc-close check must verify *that*, not
   the literal "zero pe lines." No further arc-plan change needed.

## Findings

- **F1 — the `pe_lfe` app-name follow is legitimate and minimal (endorse).**
  Renaming the OTP app `fmt` → `lfmt` is a runtime-visible change: `pe_lfe`'s
  `base_rules_path/0` reads `code:priv_dir(fmt)` to load the default rule
  registry, so leaving it returns `{error, bad_name}` and crashes `ct`. The fix
  is a one-token name change, no pe logic (reproduced: the entire `pe_*` diff is
  that single line). This is the correct handling of a "names-only" claim
  meeting reality — surfaced, confirmed, amended, bubbled — not a scope breach.
  The honest reframing is "names-only, *including* the app-name references the
  rename forces," of which there was exactly one in `pe_*`.
- **F2 — names-only verified mechanically (endorse the method).** CC proved
  "names-only" by filtering the diff against the known substitution patterns
  rather than eyeballing 581 changes; I reproduced the same filter (empty
  residue). This is the right way to make a large mechanical diff checkable.
- **F3 — toolchain rows await CI.** Same boundary as v0.1.0: compile/ct/xref/
  dialyzer are CC-attested (OTP 28 local) and reconcile on CI for the branch.

## Closure

**CDC accepts slice 1 (namespace-rename).** Git-verifiable core independently
reproduced (rename + history, no `r3lfe`, the one-line `pe_lfe` follow, names-only,
hex staged, no tag); four toolchain rows attested with CI as the reconciliation
path. Bubble-up honest; arc-plan amended correctly. Closed first pass.

**Arc not closed** — `slice2-harness-unicode` is still open. The `0.3.0` tag and
the arc/project close come after slice 2. Carried to arc close: CI green on the
branch (F3) reconciles the four toolchain rows.

Reviewed by: CDC (Cowork chat seat).
