# Slice 2: harness-unicode — closing report

> CC closing report (implementer self-assessment). Independent verification is
> CDC's, in `cdc-verification.md` (not yet written). Every `done` is
> **proposed-done** until CDC reproduces it (toolchain rows via CI).
> Project `v0.3.0` · arc `arc1-rename` · slice `slice2-harness-unicode`.
> Base `e469d0f` (slice-1 tip); fix commit `d70d8b1`; branch
> `feature/v0.3.0-namespace` (worktree `../fmt-v0.3.0-namespace`).

## Per-row walk

8 rows at open; **8 walked** (no silent drops; count matches `ledger.md`). Full
Verify output is in `ledger.md`; one-line disposition per row here.

| ID | Status | Evidence (summary) |
|----|--------|--------------------|
| A1S2-1 | done | `fmt_output_bin/1` (unicode flatten, binary()-guarded) used in all 4 corpus-fed inline oracles; no `iolist_to_binary` on formatter output remains in the oracle path. |
| A1S2-2 | done | `is_seven_bit_ascii` filter removed from `full_corpus/0`; helper deleted; `grep -rn is_seven_bit_ascii test` empty. |
| A1S2-3 | done | `ct:log` "over **84** inputs" (was 82); the 2 multibyte files now pass all four inline oracles. |
| A1S2-4 | done | `rebar3 ct` → **All 274 passed** (after Amendment 1). |
| A1S2-5 | done | compile zero-warning; xref clean; dialyzer clean. |
| A1S2-6 | done | `git diff --name-only e469d0f..HEAD` → only `test/lfmt_fezzik_SUITE.erl`. |
| A1S2-7 | done | engine `lfmt_fezzik.erl` + `pe_*` + `docs/planning/v0.5.0` diff empty. |
| A1S2-8 | done | this report (count + carried-finding-closed below). |

**Totals: 8 done · 0 deferred · 0 no-op.** Strength: all rows **reproduced**
locally (toolchain rows also "CI reconciles"). One amendment, disclosed.

## The carried v0.1.0 finding is now CLOSED

The finding opened in `v0.1.0/arc7-import/slice1-history-transfer` (ledger
Amendment 2): the inline oracle helpers flattened the formatter's
codepoint-bearing output with `iolist_to_binary`, mangling multibyte UTF-8, so
`core-macros.lfe` and `clj-tests.lfe` were excluded from the inline-oracle corpus
via an `is_seven_bit_ascii` stopgap. As of this slice the root cause is fixed
(`unicode:characters_to_binary` via `fmt_output_bin/1`), the stopgap is removed,
and **both files pass all four inline oracles** (input count 82 → 84). The
v0.1.0 carry-out is discharged; nothing about it remains deferred.

## Bubble-up to the arc (arc1-rename)

### 1. Did slice 2 deliver the piece of the arc's capability the arc-plan assigned it?

Yes. The arc-plan slice-2 row: *inline oracle helpers use
`unicode:characters_to_binary`; remove the `is_seven_bit_ascii` restriction so
every corpus file flows through every oracle; the 2 multibyte files pass; full
corpus green; no ASCII carve-out remains.* All delivered: the helpers are
Unicode-safe, the restriction is gone, the 2 files pass, ct is 274-green, and no
carve-out remains. This is also arc-ledger row **A1-4** (carried v0.1.0 finding
closed here) — discharged.

### 2. What did implementing this slice reveal that the arc-plan did not anticipate?

- **There were four inline oracle helpers, not three.** The prompt (and the
  v0.1.0 finding write-ups) named `assert_idempotent`,
  `assert_token_preservation`, `assert_ast_equiv`. `assert_comment_preservation`
  is a fourth `full_corpus`-fed inline oracle with the identical
  `iolist_to_binary`-on-formatter-output bug; it failed on the first ct run once
  the ASCII restriction was lifted. Fixed identically (ledger Amendment 1). The
  lesson for the record: the v0.1.0 finding under-counted the affected helpers by
  one — the gate (ct green) caught it, not the enumeration.

### 3. The silent-drop diff at slice scale

- **Specified → delivered:** unicode flatten in the inline oracles ✓; restriction
  removed + helper deleted ✓; 2 multibyte files pass ✓; count stated (82→84) ✓;
  ct/compile/xref/dialyzer green ✓; diff confined to the suite ✓; engine/pe/v0.5.0
  untouched ✓; no `0.3.0` tag ✓.
- **Expanded-not-dropped:** the fourth helper (`assert_comment_preservation`),
  disclosed as Amendment 1.
- **Silent drops: none.**

## Slice-close arc-plan update

Part-IV question — *did slice 2 uncover anything that should change
`arc-plan.md`?* The slice breakdown is unchanged and now complete (both slices
delivered). The only finding (a fourth affected helper) is contained within this
slice and recorded as Amendment 1; it does not alter the arc's capability,
sequencing, or composition rows. Recorded in `arc-plan.md` Version History (v2.2)
for traceability rather than as a structural change.

## Arc-close readiness (this is arc1's last slice)

Both slices of `arc1-rename` are now CC-closed. The arc is **not yet closed** —
per the framework it closes only when its last slice is **CDC-closed**. Pending,
in order:
1. `cdc-verification.md` for slices 1 and 2.
2. The arc-level `arc1-rename/closing-report.md`: composition check (A1-3: no
   `r3lfe`; `lfmt_fezzik*` + app `lfmt`; full-corpus ct green with **no** ASCII
   carve-out; compile/xref/dialyzer clean; `pe_*`/v0.5.0 untouched-except-the-
   one-app-name-line; A1-4: v0.1.0 finding closed), reproduced at arc scale / CI.
3. **The `0.3.0` tag** (created at arc close, marking namespace + honest harness).
4. The v0.3.0 project close (`project-plan.md` P-rows).
CC did **not** create the tag or close the arc — that is the arc-close step.

## Open items for CDC / operator

- **`cdc-verification.md` pending** (this slice) — reproduce `grep is_seven_bit_ascii`
  (empty), the 84-input count, the 2 multibyte files passing, and (CI) the toolchain.
- **No `CLAUDE.md`** still records the layout/close-set convention (carried since
  v0.1.0) — raised, not created unilaterally.
- **Base/merge reminder:** still on `feature/v0.3.0-namespace` off
  `feature/fezzik-import`; the v0.1.0/v0.2.0 → `main` merge remains outstanding.
