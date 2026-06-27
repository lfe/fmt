# Slice 1: split — closing report

> CC closing report (implementer self-assessment). Independent verification is
> CDC's, in `cdc-verification.md` (not yet written). Every `done` is
> **proposed-done** until CDC reproduces it (toolchain rows via CI).
> Project `v0.4.0` · arc `arc1-release` · slice `slice1-split`.
> Base `main` `4bf3af0`; commit 1 (split) `f4790e1`; commit 2 (hygiene) `46240a5`;
> branch `feature/v0.4.0-release` (worktree `../fmt-v0.4.0-release`).

## Per-row walk

10 rows at open; **10 walked** (no silent drops; matches `ledger.md`). Summary
disposition per row; full evidence in `ledger.md`.

| ID | Status | Evidence (summary) |
|----|--------|--------------------|
| A1S1-1 | done | `lfmt_fezzik.erl` 1869→57; + `lfmt_fezzik_render` (1087), `lfmt_fezzik_util` (809), `lfmt_fezzik.hrl`. All compile. |
| A1S1-2 | done | 32-file corpus output byte-identical pre/post (sha256 `2a7e56b6…` both). |
| A1S1-3 | done | xref clean; layering `lexer→cst→util→render→fezzik`, one-way (edges stated). |
| A1S1-4 | done | render/clause/data = one 23-fn SCC → kept whole; disclosed (below). |
| A1S1-5 | done | `rebar3 ct` All 274 passed. |
| A1S1-6 | done | compile zero-warning; dialyzer clean (22 files); types/specs distributed. |
| A1S1-7 | done | `lfmt_fezzik:format/1` unchanged; suite resolves; ct green. |
| A1S1-8 | done | commit 1 = 4 src files; commit 2 = test only. |
| A1S1-9 | done | `conf_wide_sweep` → `fmt_output_bin`; "32 checked, 0 skipped" (was 30/2). |
| A1S1-10 | done | pe/v0.5.0 diff empty; no `0.4.0` tag. |

**Totals: 10 done · 0 deferred · 0 no-op.** All rows **reproduced** locally
(toolchain also "CI reconciles"). No amendments.

## Bubble-up to the arc (arc1-release)

### 1. Did slice 1 deliver the piece of the arc's capability the arc-plan assigned it?

Yes. The arc-plan slice-1 row: *decompose `lfmt_fezzik.erl` into focused modules
— pure refactor; byte-identical behaviour; xref clean acyclic layering;
zero-warning compile; dialyzer clean; any seam mutual recursion forbids is
disclosed + merged, not forced.* Delivered: a 3-module + shared-`.hrl`
decomposition, byte-identical corpus output, clean one-way layering, all
toolchain green. Also the carried v0.3.0 `conf_wide_sweep` hygiene (arc row A1-5),
as a separate test-only commit.

### (a) Final module set + dependency graph

```
lfmt_fezzik        (57)  — public format/1 + render_document/render_toplevel
                          + TEST-only regime/2 re-export.       [top]
lfmt_fezzik_render (1087)— the 23-function mutually-recursive rendering core.
lfmt_fezzik_util   (809) — 51 pure leaf helpers (regime, classify_head/
                          specform_table, predicates, sorting, cons-dot,
                          flat_render/flat_width, emit_* trivia, column math).
lfmt_fezzik.hrl    — shared ?WIDTH + width()/head_class() types.

dependency edges (one-way):
   lexer → cst → util → render → fezzik
   util   calls: lexer, cst (+ self)            — never up
   render calls: lexer, cst, util (+ self)      — never fezzik
   fezzik calls: lexer, cst, render, util
```

### (b) The merged seam, and why

The arc-plan's proposed `render` / `clause` / `data` split is **infeasible**.
The local call graph has **one strongly-connected component of 23 functions** —
`print_node`, `print_broken[_container]`, `print_bp_container`, `bp_rest_loop`,
`bp_clause_rest_loop`, `print_map_pairs[_list,_rest]`, `render_clause`,
`print_classified`, `print_distinguished`, the clause/flet/local-fn/import/try/
receive loops — spanning all three proposed seams. They are mutually recursive
(the renderer descends into children via `print_node`, and clause/map/data
rendering call back into it), so separating them would create circular module
dependencies. Per the plan's explicit sanction, the SCC is kept whole as
`lfmt_fezzik_render`; only the 51 genuinely-acyclic leaf helpers were extracted
to `lfmt_fezzik_util`. No indirection was introduced to fake a finer split.

### (c) The v0.3.0 `conf_wide_sweep` hygiene is closed

Arc row **A1-5** (carried from v0.3.0): `conf_wide_sweep` flattened formatter
output with `iolist_to_binary` inside a try/catch, so the 2 multibyte files threw
and were silently counted as *skipped*. Swapped to `fmt_output_bin` (v0.3.0/slice2's
unicode-safe helper) in a separate test-only commit — now **32 checked, 0
skipped**. Closed.

### 3. The silent-drop diff at slice scale

- **Specified → delivered:** decomposition ✓; byte-identical ✓; acyclic layering
  ✓; ct/compile/xref/dialyzer green ✓; public API unchanged ✓; src-only split +
  separate hygiene commit ✓; pe/v0.5.0 untouched ✓; no `0.4.0` tag ✓.
- **Reshaped-not-dropped:** the 4-module proposal → 3 modules (disclosed merged
  SCC) — sanctioned by the gate ("not exactly four modules").
- **Silent drops: none.**

## Slice-close arc-plan update

Part-IV question — *did slice 1 uncover anything that should change
`arc-plan.md`?* The arc's slice breakdown (split → publish → integrate) stands.
One finding to record: the split's realized shape (3 modules, not the proposed 4,
due to the irreducible SCC) — slice 2's hex tarball now ships `lfmt_fezzik`,
`lfmt_fezzik_render`, `lfmt_fezzik_util`, `lfmt_fezzik_lexer`, `lfmt_fezzik_cst`
+ the `.hrl`. Recorded in `arc-plan.md` Version History so slice 2 packages the
right module set. No re-sequencing.

## Open items for CDC / operator

- **`cdc-verification.md` pending** — reproduce the byte-identical golden
  (capture on `4bf3af0`, diff vs `46240a5`), the layering edges, and (CI)
  compile/ct/xref/dialyzer.
- **Cosmetic:** 31 over-100-col lines in `lfmt_fezzik_render.erl` from
  call-qualification; `rebar3 fmt` not run (would touch un-erlfmt'd `pe_*`). A
  targeted erlfmt pass is an optional follow-up.
- **No `CLAUDE.md`** still records the layout/close-set convention (carried since
  v0.1.0) — raised, not created unilaterally.
- Next: `slice2-hex-release` (vsn → `0.4.0`, hex metadata, `rebar3 hex publish`,
  tag `0.4.0`) — note publish/tag are reserved for that slice + arc close.
