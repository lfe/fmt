# Slice 1: history-transfer — closing report

> CC closing report (implementer self-assessment). Independent verification is
> CDC's job, in `cdc-verification.md` (not yet written). Every `done` below is
> **proposed-done** until CDC reproduces it against the DAG and diffs.
> Project `v0.1.0` · arc `arc7-import` · slice `slice1-history-transfer`.
> Commits: base `05fc025`; merge `d879c90` ("Import Fezzik…"); corpus re-point
> `3177954`. Branch `feature/fezzik-import` (worktree `../fmt-fezzik-import`).
>
> **Layout note (disclosed, not silent):** this is the **first**
> `closing-report.md` in the project. The pe slices (`v0.5.0`) fold closure into
> `ledger.md` and add `cdc-verification.md`; there are no other closing-reports.
> Per operator confirmation (2026-06-26), arc7-import adopts the v2.1 close-set
> (`closing-report.md` by CC + `cdc-verification.md` by CDC) going forward. The
> existing dirs are **not** migrated (`docs/planning/…`, non-zero-padded
> `arc7`/`slice1`); naming that dissonance rather than migrating it in-flight.

## Per-row walk

12 rows at open; **12 walked here** (no silent drops; row count matches
`ledger.md`). Full Verify-command output lives in `ledger.md`; this is the
disposition + a one-line evidence pointer per row.

| ID | Status | Evidence (summary — full output in `ledger.md`) |
|----|--------|--------------------------------------------------|
| A7S1-1 | done | Extract = exactly the 8 paths; 43 commits touch imported paths, **29** touch the 3 engine `src` files; root `c5bfc71` (=`0f74364`). |
| A7S1-2 | done | Merge `d879c90`; **43 imported commits in fmt's DAG**, full date+subject set **identical** to extract; root author/date preserved. `--follow`: lexer→root, formatter→`ce03797` (A3 birth), cst→`e3bbade` (arc2 birth). |
| A7S1-3 | done | `rebar3 compile` zero-warning under `warnings_as_errors`/`warn_unused_import`/`warn_export_vars`; no friction. |
| A7S1-4 | done | 3 suites run; `lfe` dep resolves (`code:lib_dir(lfe)`); `tq_corpus.lfe` present. |
| A7S1-5 | done | Commit `3177954`, discovery source only; `ct:log` "32 total .lfe files" / "Wide sweep over 32" / inline oracles "82 inputs". |
| A7S1-6 | done | Full `rebar3 ct` → **All 274 tests passed** (272 Fezzik + 2 pe), reproduced at committed SHA `3177954`. |
| A7S1-7 | done | `rebar3 xref` exit 0, no dangling refs, at `3177954`. |
| A7S1-8 | done | `rebar3 dialyzer` exit 0, 20 files, no warnings, reproduced at `3177954`. |
| A7S1-9 | done | `git diff --stat 05fc025 -- 'src/pe_*.erl' 'test/pe_*' docs/planning/v0.5.0` → empty; full change set = 8 Fezzik paths + 3 re-pointed suites only. |
| A7S1-10 | done | `grep -rn 'lfmt_fezzik\|lfmt_' src test` → empty; `git tag -l` → empty. |
| A7S1-11 | done | Caveats stated below + in `ledger.md` (exact corpus; large-file test ran, not skipped). |
| A7S1-12 | done | compile + ct(274) + xref + dialyzer all green under OTP 28 (rebar3 3.27.0, erts 16.1.1). |

**Totals: 12 done · 0 deferred · 0 no-op.** Strength (per LEDGER-DISCIPLINE
v2.0 ladder): A7S1-2/-6/-8 were initially **attested** (claimed by content
equivalence to a working-tree run), then promoted to **reproduced** by
re-running at the committed SHA `3177954` and (for -2) counting the imported
commits in fmt's DAG. The remaining rows are **reproduced** (commands run and
observed). None rest on bare assertion.

## Bubble-up to the arc (arc7-import)

### 1. Did slice 1 deliver the piece of the arc's capability the arc-plan assigned it?

Yes. The arc-plan slice-1 row ("history-transfer") gate was: *all Fezzik
commits present in fmt's DAG with original authorship/dates (`git log --follow`
works back to `0f74364`); `rebar3 compile` zero-warning; `rebar3 ct` green;
corpus sweep exercises a disclosed, non-trivial file count (not 1).* Each is
met: 43 imported commits with original dates; zero-warning compile under the
original `r3lfe_*` names; ct 274-green; sweep over 32 files (0 skipped), up from
the hollow 1. The arc's "code + history + green suites" half — the part the
arc-plan flagged as carrying the engineering risk — is delivered.

### 2. What did implementing slice 1 reveal that the arc-plan did not anticipate?

Four items, smallest to largest:

- **The `--follow`-to-`0f74364` gate is per-file imprecise.** It holds for the
  **lexer** (the only file present at the root commit); the formatter and cst
  were born later (A3 `ce03797`; arc2 `e3bbade`), so `--follow` reaches *their
  birth*, not the root — a file cannot be followed before it existed. The DAG
  root for all three is `0f74364`→`c5bfc71`. The gate's intent (history traces
  to origin) is met; its literal wording ("on each module") is not achievable
  and should be reworded for slice-2's reading.
- **Commit-count framing.** The import carries **43** commits touching the 8
  paths; the arc-plan's "~29 commits" counts only the 3 engine `src` files (also
  confirmed = 29). Both true; the 43 is the figure a DAG inspection returns.
- **A third `_integration` discovery site the prompt did not name.** Beyond the
  formatter + cst suites, `r3lfe_format_lexer_SUITE`'s
  `round_trip_integration_files` also discovers `_integration` **and asserts
  `length > 0`** — so it would have *failed hard*, not passed hollowly. Re-pointed
  it too (raised as ledger Amendment 1).
- **(Load-bearing) A latent Unicode defect in Fezzik's inline oracle helpers.**
  The formatter correctly emits Unicode codepoints (>127) and round-trips them
  via `unicode:characters_to_binary`; but the inline oracle helpers
  (`assert_idempotent` / `assert_token_preservation` / `assert_ast_equiv`)
  flatten with `iolist_to_binary`, which mangles those codepoints (re-read throws
  `invalid_encoding`). Exactly the 2 multibyte files in the dep corpus
  (`core-macros.lfe`, `clj-tests.lfe`) trip it; all 31 pass the Unicode-safe
  sweeps. The arc-plan assumed re-pointing was a clean green change; it instead
  **surfaced a real test-harness bug**. Handled within slice scope by restricting
  only the inline-oracle `full_corpus/0` to 7-bit-ASCII (discovery source; the
  2 files stay covered by the sweeps), leaving the oracle helpers untouched
  (out of scope). See ledger Amendment 2. **This finding routes above
  arc7-import** (the arc is import + docs/tag; fixing the helpers is neither) —
  recommended home: a dedicated test-harness fix slice in the v0.3.0 rename line
  or earlier, swapping `iolist_to_binary` → `unicode:characters_to_binary` in
  the inline helpers. Recorded in `arc-plan.md` Version History as surfaced-by
  slice 1.

### 3. The silent-drop diff at slice scale

- **Specified → delivered:** extract 8 paths ✓; merge unrelated history ✓;
  compile zero-warning under `r3lfe_*` ✓; ct green, 3 suites ✓; corpus re-point
  off `_integration` ✓; xref ✓; dialyzer ✓; pe/v0.5.0 untouched ✓; no rename,
  no tags ✓. All specified items delivered.
- **Deferred-with-rationale:** (a) 2 Unicode files excluded from the
  **inline-oracle** path only — still exercised by the sweeps; (b) the
  `iolist_to_binary` harness fix — out of arc7-import scope, routed upward.
- **Silent drops: none.**

## Slice-close arc-plan update

Asking the required Part-IV question — *did slice 1 uncover anything that should
change `arc-plan.md`?* — the answer is **yes, additively**: the slice breakdown
(slices 1 & 2) is unchanged and correct, but two findings must be recorded so
they are not lost (the harness defect; the extraction-tip drift), and the
`--follow` gate wording should be corrected for slice 2. `arc-plan.md` is
updated accordingly (body note + new Version History entry naming slice 1 as the
source), per the plan-change discipline. No re-sequencing or new arc7-import
slice is forced.

## Open items for CDC / operator

- **`cdc-verification.md` pending** — independent re-run of the reproducible
  rows + verification of this bubble-up (Part IV check), including the decision
  on whether the harness finding warrants a tracked routing artifact.
- **No `CLAUDE.md`** exists to record the confirmed layout choice (Part VI says
  to record it; "if none exists, raise it as a follow-up"). Raising it here:
  worth a one-line `CLAUDE.md` stating planning artifacts live under
  `docs/planning/vX.Y.Z/…` and arc7+ uses the v2.1 close-set — **not** created
  unilaterally.
- **Disclosed gap:** `arc-plan.md` predates v2.1 and lacks a formal arc-ledger
  *section* (composition rows). Not retrofitted here (that is arc-planning work,
  not slice-1 close); named so it is a disclosed gap, not a silent one.
