# v0.1.0 — project closing report

> Project-level close for **v0.1.0** (Import & establish the brute baseline).
> Assembled by **CDC**; the **project gate (go / adjust / kill) is the
> operator's**, with an independent context, per LEDGER-DISCIPLINE Section C.
> Branch `feature/fezzik-import` (tip `f963976`; tag `0.1.0` → `d2e79c7`).

## 1. Definition of done — verdict

**Met** (git-verifiable core reproduced; one sub-claim — green suites at project
scale — attested by CC, **pending CI**). Fezzik lives in `fmt` with preserved
history; the 0.1.0 design record is placed and the `0.1.0` tag resolves; the
corpus is real; `pe`/v0.5.0 untouched. The boundaries held: no rename, no
build/publish, no arc7/`0.2.0` — those remain v0.2.0–v0.4.0.

## 2. Arc walk

One arc in the roadmap; **one** walked (count matches — no project-scale silent
drop). The imported `arc1-lexer … arc6-release` are an archived record, not
roadmap arcs.

| Arc | Outcome | Close |
|-----|---------|-------|
| `arc7-import` | **delivered** | `arc7-import/closing-report.md` — 6 arc-ledger rows walked; composition reproduced at arc scale (suites-green CI-pending); arc gate pending operator. |

## 3. Composition check (Project Ledger per-row walk)

Class-(b) reproduced at **project scale** (a fresh-clone demonstration), not
inherited from the arc.

| ID | Class | Status | Evidence |
|----|-------|--------|----------|
| P-1 | (a) arc closed | **done** | `arc7-import/closing-report.md` — assembled, 6/6 rows; arc-gate operator-pending. (attested by pointer) |
| P-2 | (b) DoD demonstrable | **done (suites CI-pending)** | At project scale on `feature/fezzik-import`: history (DAG root `c5bfc71`↔`0f74364`, dates identical; `--follow` to origins), placed 0.1.0 record (`ls docs/planning/v0.1.0` → arc1-6 + 6 loose), resolvable tag (`0.1.0` → `d2e79c7`, annotated, unique anchor), real corpus (32 files), `pe`/v0.5.0 untouched (empty diff). Suites-green (`rebar3 ct` 274) **attested by CC → reconciles on CI**. (i)–(v git) reproduced by CDC. |
| P-3 | (c) findings dispositioned | **done** | Arc bubble-up findings routed: Unicode harness fix → v0.3.0 (project-plan v1.0 change-log); §7a phantom fixed; `A6·S0` → full-message anchor rule for v0.2.0/arc8. |

**Silent-drop diff at project scale:** DoD-as-specified vs as-delivered — all
present; the suites-green sub-claim is disclosed and CI-routed, not dropped.
**No silent drops.**

**Tally:** 3 project-ledger rows walked. 3 done (P-2 with one CI-pending
sub-row). 0 deferred, 0 no-op.

## 4. Findings carried out of the project

- **Unicode inline-oracle harness fix** (`iolist_to_binary` →
  `unicode:characters_to_binary` in `assert_idempotent`/`_token`/`_ast`): a real
  latent Fezzik test-harness defect, contained in v0.1.0 (Unicode files routed
  to the Unicode-safe sweep path) and **routed to v0.3.0**. Must get a concrete
  slice when v0.3.0 is planned — currently tracked, not yet planned.
- **v0.2.0/arc8 must anchor the `0.2.0` tag on a full commit message** (the
  short token is ambiguous), and must not expect a `RESEARCH-BOOTSTRAP.md`.

## 5. Project gate (operator)

**PENDING — operator (Duncan), with an independent context.** Decision:
go / adjust / kill against the DoD. Composition is assembled and the
git-verifiable rows reproduced. Recommended gate condition: **CI green on
`feature/fezzik-import`** reconciles P-2's suites-green sub-row; then v0.1.0 is
unconditionally **go**, which unblocks the **v0.2.0** project (arc8: place
`arc7-rules-v2` docs + tag `0.2.0`).

> Note on merge: the import + 0.1.0 baseline currently live on
> `feature/fezzik-import`; the planning tree (`arc7-import/`, this report,
> `project-plan.md`) lives in the main worktree. A clean close also wants the
> branch merged to `main` and the planning docs committed — an operator git
> step (sandbox cannot mutate git).

Assembled by: CDC (Cowork chat seat), 2026-06-26.
