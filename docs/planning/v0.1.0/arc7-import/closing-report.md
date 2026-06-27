# arc7-import — closing report (arc close)

> Arc-level close for `v0.1.0 / arc7-import`. Assembled by **CDC** (the seat that
> ran both slice verifications). Per LEDGER-DISCIPLINE Section B, the independent
> **arc-gate sign-off is the operator's, not this seat's** — left PENDING below.
> Branch `feature/fezzik-import` (tip `f963976`; tag `0.1.0` → `d2e79c7`).

## 1. Capability — restated and verdict

**Capability (from `arc-plan.md`):** relocate Fezzik into `fmt` with full,
authorship-preserving git history and establish the 0.1.0 brute baseline
(design record + `0.1.0` tag), keeping the suites honest and `pe`/v0.5.0
untouched.

**Verdict: delivered** (git-verifiable core independently reproduced; one
composition sub-row — green suites at arc scale — is **attested by CC, pending
CI reconciliation**; see A7-3). No silent drops at arc scale.

## 2. Slice walk

Two slices in the arc-plan breakdown; **two** walked here (count matches — no
arc-scale silent drop).

| Slice | Outcome | CDC close |
|-------|---------|-----------|
| slice 1 — history-transfer | **delivered** | `cdc-verification.md`: 7/12 rows reproduced, 5 toolchain rows attested (CI reconciles); accepted first pass. |
| slice 2 — docs-and-tag | **delivered** | `cdc-verification.md`: 9/9 rows reproduced (no toolchain boundary); accepted first pass. |

## 3. Composition check (Arc Ledger per-row walk)

Class-(b) row A7-3 is **reproduced at arc scale** (an end-to-end demonstration,
not inherited from the slices), to the extent the CDC sandbox allows; the
suites-green sub-claim is the one CI-gated piece.

| ID | Class | Status | Evidence (reproduced at arc scale unless noted) |
|----|-------|--------|--------------------------------------------------|
| A7-1 | (a) child closed | **done** | `slice1-history-transfer/cdc-verification.md` — accepted. (attested by pointer) |
| A7-2 | (a) child closed | **done** | `slice2-docs-and-tag/cdc-verification.md` — accepted. (attested by pointer) |
| A7-3 | (b) compose | **done (1 sub-row CI-pending)** | End-to-end at arc scale: **(i) history** — DAG root `c5bfc71` author/committer dates identical to original `0f74364`; `--follow` traces each module to its origin. **(ii) baseline docs** — `git ls-tree feature/fezzik-import -- docs/planning/v0.1.0` → arc1-lexer…arc6-release + 6 loose files. **(iii) tag** — `git for-each-ref 0.1.0` → annotated → `d2e79c7` (unique `Implement Arc A6·S0`). **(iv) corpus real** — re-point diff confirmed (32 files, not 1). **(v) suites green** — CC-attested `rebar3 ct` 274 pass; **reconciles on CI** for `feature/fezzik-import`. (i)–(iv) reproduced by CDC; (v) attested. |
| A7-4 | (c) finding | **done** | Unicode inline-oracle defect → routed to v0.3.0; recorded arc-plan v1.1 + slice-1 cdc F5. |
| A7-5 | (c) finding | **done** | `RESEARCH-BOOTSTRAP` phantom → migration §7a fixed; `A6·S0` anchor → full-message rule; recorded arc-plan v1.2 + slice-2 cdc F1/F2. |
| A7-6 | (c) finding | **done** | `--follow` gate wording corrected; recorded arc-plan v1.1 + slice-1 cdc F3. |

**Silent-drop diff at arc scale:** arc-capability-as-specified (import + history
+ 0.1.0 baseline docs + tag + honest suites + pe untouched) vs as-delivered —
**all present**; the only non-reproduced sub-claim (suites green) is disclosed
and CI-routed, not dropped. **No silent drops.**

**Tally:** 6 arc-ledger rows, all walked. 6 done (A7-3 with one CI-pending
sub-row). 0 deferred, 0 no-op.

## 4. Accumulated arc-plan change log

Three tracked changes bubbled into `arc-plan.md` during the arc (drift visible
in one place): **v1.1** (slice 1 — Unicode defect routed out; `--follow`
wording), **v1.2** (slice 2 — phantom file; tag-anchor rule), **v1.3** (CDC at
close — Arc Ledger retrofit). The slice breakdown never changed; no remediation
slice was forced.

## 5. Bubble-up to the project (v0.1.0)

1. **Did this arc deliver its capability as `project-plan.md` defines it?**
   Yes — arc7-import *is* v0.1.0's only active arc (the arc1-6 dirs are the
   imported historical record, not arcs we execute). Import + history + 0.1.0
   baseline + honest corpus delivered; pe untouched. Against the v0.1.0 DoD
   (see `../project-plan.md`), the project's substantive work is complete.
2. **What did this arc reveal that the project plan did not anticipate?**
   - One finding **escapes v0.1.0 entirely**: the Unicode inline-oracle harness
     fix belongs to a later project (recommended v0.3.0). The project-plan
     change-log should carry it forward so it is not orphaned at the v0.1.0→
     v0.2.0 boundary. *(CDC action item — also slice-1 cdc F5.)*
   - A migration-plan (`workbench/`) error (`RESEARCH-BOOTSTRAP` phantom) was
     a cross-cutting doc bug, now fixed; v0.2.0/arc8 must anchor `0.2.0` on a
     full commit message (slice-2 cdc F2).
3. **Silent-drop diff at arc scale, rolled to the project:** nothing the v0.1.0
   roadmap expected from this arc failed to land. The CI reconciliation of the
   suites-green sub-row is the one open condition carried to the project gate.

## 6. Arc gate (operator)

**PENDING — operator (Duncan).** The composition is assembled and the
git-verifiable rows reproduced; the gate decision (accept the arc / require CI
first / adjust) is the operator's, per the independence rule. Recommended gate
condition: **CI green on `feature/fezzik-import`** reconciles A7-3(v), after
which the arc is unconditionally closeable.

Assembled by: CDC (Cowork chat seat), 2026-06-26.
