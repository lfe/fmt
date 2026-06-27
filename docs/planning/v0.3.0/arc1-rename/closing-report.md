# arc1-rename — closing report (arc close)

> Arc-level close for `v0.3.0 / arc1-rename`. Assembled by **CDC**; the
> independent **arc-gate sign-off is the operator's**, PENDING below. Branch
> `feature/v0.3.0-namespace` (slice-1 `e469d0f`, slice-2 `d70d8b1`).

## 1. Capability — restated and verdict

**Capability (from `arc-plan.md`):** Fezzik is `lfmt`-namespaced (app + modules)
with an honest, un-restricted test harness; toolchain green; `pe`/v0.5.0
untouched (except the one app-name reference the rename forces).

**Verdict: delivered.** Git-verifiable composition reproduced; the toolchain
(compile/ct/xref/dialyzer) is CC-attested (OTP 28) and **reconciles on CI** —
the one open condition, same boundary as v0.1.0.

## 2. Slice walk

Two slices in the breakdown; **two** walked (count matches).

| Slice | Outcome | CDC close |
|-------|---------|-----------|
| slice 1 — namespace-rename | **delivered** | `cdc-verification.md`: 8/12 reproduced, 4 toolchain attested (CI); the one `pe_lfe` app-name line confirmed minimal; names-only proven mechanically. |
| slice 2 — harness-unicode | **delivered** | `cdc-verification.md`: 5/8 reproduced, 3 toolchain attested (CI); fourth-helper amendment sound; carried v0.1.0 finding closed. |

## 3. Composition check (Arc Ledger per-row walk)

| ID | Class | Status | Evidence |
|----|-------|--------|----------|
| A1-1 | (a) child closed | **done** | `slice1-namespace-rename/cdc-verification.md` — accepted. |
| A1-2 | (a) child closed | **done** | `slice2-harness-unicode/cdc-verification.md` — accepted. |
| A1-3 | (b) compose | **done (toolchain = CI)** | Reproduced at arc scale: `git grep r3lfe` → **empty**; modules are `lfmt_fezzik*`, app is `lfmt` (`lfmt.app.src` `{application, lfmt}` vsn `0.3.0`); `is_seven_bit_ascii` gone (**no ASCII carve-out**); `pe_*` diff = the **single** `priv_dir(fmt→lfmt)` line; `docs/planning/v0.5.0` untouched. Full-corpus `ct` green (84 inline-oracle inputs) + compile/xref/dialyzer = CC-attested, **CI reconciles**. |
| A1-4 | (c) finding | **done** | Carried **v0.1.0 Unicode-harness finding CLOSED** — disposition = slice 2 (`fmt_output_bin` + carve-out removed). Back-link: v0.1.0 project-plan v1.0 change-log. |

**Silent-drop diff at arc scale:** capability-as-specified vs as-delivered — all
present, with two *disclosed* refinements (the one-line `pe_lfe` app-name follow;
the fourth inline-oracle helper). No silent drops.

**Tally:** 4 arc-ledger rows, all done (A1-3 toolchain via CI). 0 deferred,
0 no-op.

## 4. Accumulated arc-plan change log

`arc-plan.md` grew v2.0 (forward plan: 2 slices + arc-ledger), v2.1 (slice-1
`pe_lfe` app-name exception), v2.2 (slice-2 fourth-helper + A1-4 closed). The
slice breakdown never changed; no remediation slice forced.

## 5. The `0.3.0` tag (operator step)

Per the plan, `0.3.0` is tagged at **arc close** — the first **buildable**
milestone (the `lfmt` app exists, compiles, ct-green), unlike the
source-history-only `0.1.0`/`0.2.0`. **Operator action** (sandbox can't tag):
tag `0.3.0` (annotated) on the v0.3.0 tip. Per the branch/merge strategy,
cleanest **on `main` after the v0.3.0 branch merges**, so `git checkout 0.3.0`
and `main` agree. Verify `git merge-base --is-ancestor 0.2.0 0.3.0`.

## 6. Bubble-up to the project (v0.3.0)

1. **Delivered its capability as `project-plan.md` defines it?** Yes — arc1 is
   v0.3.0's only arc; namespace + honest harness delivered. Against the v0.3.0
   DoD, the substantive work is complete (toolchain pending CI).
2. **Revealed anything the project plan didn't anticipate?** Two in-arc
   refinements (both disclosed, neither changing scope): the `pe_lfe` app-name
   follow, and the fourth inline-oracle helper. One **new non-blocking finding**
   bubbles to the project: `conf_wide_sweep` silently skips the 2 multibyte
   files (`iolist_to_binary` throw) — not a coverage gap (covered by
   `corpus_sweep_all` + the inline oracles), recommended as a **v0.4.0 hygiene
   follow-up** (align its flatten with `fmt_output_bin`).
3. **Silent-drop diff at arc scale, rolled to the project:** nothing the v0.3.0
   roadmap expected failed to land. Open conditions: CI green (toolchain) + the
   `0.3.0` tag.

## 7. Arc gate (operator)

**PENDING — operator (Duncan).** Composition assembled, git-rows reproduced.
Recommended gate condition: **CI green on `feature/v0.3.0-namespace`** reconciles
A1-3's toolchain claims; then the arc is closeable, the `0.3.0` tag placed, and
v0.3.0 ready for project close.

Assembled by: CDC (Cowork chat seat), 2026-06-26.
