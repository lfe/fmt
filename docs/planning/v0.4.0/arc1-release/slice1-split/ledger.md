# Slice 1: split — ledger

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently. Implementer never marks its own rows CDC-verified. Iteration
> cap: 5. Project `v0.4.0` · arc `arc1-release` · slice `slice1-split`.
> Toolchain rows reconcile via **CI** (no OTP in the CDC sandbox).

## Ledger

> CC self-assessment. Base `main` `4bf3af0`; commit 1 (split) `f4790e1`; commit 2
> (hygiene) `46240a5`; branch `feature/v0.4.0-release` (worktree
> `../fmt-v0.4.0-release`). Golden sha256 `2a7e56b6…`. Toolchain rows run locally
> (OTP 28) + "CI reconciles". Every `done` is **proposed-done** until CDC reproduces.

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S1-1 | `lfmt_fezzik.erl` decomposed into focused modules; each compiles; `-module`/`-export` correct | `git diff --stat`; `grep -l '^-module(lfmt_fezzik' src` | correctness | slice-doc | done | `lfmt_fezzik.erl` 1869→**57** (orchestrator); new `lfmt_fezzik_render.erl` (1087, the core SCC), `lfmt_fezzik_util.erl` (809, leaf helpers), `lfmt_fezzik.hrl` (shared `?WIDTH`/`width()`/`head_class()`). All 4 compile zero-warning. | seam set settled by the call graph (A1S1-4) |
| A1S1-2 | **behaviour-identical**: byte-identical formatted corpus output pre/post split | capture corpus output on `main`, diff vs post-split → empty | serious | slice-doc | done | 32-file corpus golden captured on `main` pre-split, regenerated post-split: `diff` **empty**, sha256 **identical** (`2a7e56b6…` both). The refactor proof. | stronger than ct |
| A1S1-3 | `xref` clean + **acyclic layering** in the intended direction (no module calls "up") | `rebar3 xref`; inspect module call graph; state it | serious | slice-doc | done | `rebar3 xref` exit 0. Inter-module edges: `util→{lexer,cst,util}` only; `render→{lexer,cst,util,render}` (never fezzik); `fezzik→{lexer,cst,render,util}`. Layering **`lexer → cst → util → render → fezzik`**, strictly one-way. | the load-bearing design check |
| A1S1-4 | any seam mutual recursion forbade is **disclosed + merged**, not forced with indirection | closing-report disclosure; diff review | serious | slice-doc | done | The proposed render/clause/data split is **infeasible**: `print_node` + the broken/bp/classified/clause/map/import/try/receive rendering form **one 23-function mutually-recursive SCC** (computed from the local call graph). Kept whole as `lfmt_fezzik_render`; only the 51 acyclic leaf helpers extracted. No indirection added. Disclosed in closing-report. | gate is "behaviour identical + layering clean", not "4 modules" |
| A1S1-5 | full `rebar3 ct` green (oracles unchanged, 274) | `rebar3 ct` | serious | engineering bar | done | `rebar3 ct` → **All 274 tests passed** (both pre-hygiene and post-hygiene runs). | also CI reconciles |
| A1S1-6 | `compile` zero-warning; `dialyzer` clean (types/specs distributed; `cst_node()` refs intact; `no_underspecs` with `format/1`) | `rebar3 compile`/`dialyzer` | serious | engineering bar | done | `compile` zero-warning; `dialyzer` exit 0 (22 files). `width()`/`head_class()` → hrl; `regime()`/`head_class()` carried; `-dialyzer({no_underspecs, format/1})` stays in `lfmt_fezzik`; `no_underspecs(specform_table/0)` carried to util; `lfmt_fezzik_cst:cst_node()` refs intact. | also CI reconciles |
| A1S1-7 | public API `lfmt_fezzik:format/1` unchanged; callers (suite) resolve | `grep` call sites; ct green | serious | scope control | done | `lfmt_fezzik:format/1` is the unchanged entry; suite calls `lfmt_fezzik:format(...)` + `lfmt_fezzik:regime/2` (TEST re-export) — both resolve; ct green. | internal-only split |
| A1S1-8 | the split is **src-only**; `conf_wide_sweep` hygiene is a **separate** test-only commit | per-commit `git show --stat` | serious | scope control | done | Commit 1 `f4790e1` = `src/lfmt_fezzik{,_render,_util}.erl` + `.hrl` only. Commit 2 `46240a5` = `test/lfmt_fezzik_SUITE.erl` only. Cleanly separated. | keeps the split a pure refactor |
| A1S1-9 | `conf_wide_sweep` flatten → `fmt_output_bin`; no longer skips the 2 multibyte files | inspect; `ct:log` skipped-count | polish | bubble-up (v0.3.0) | done | `conf_wide_sweep` flattens with `fmt_output_bin` (×2). `ct:log`: **"32 checked, 0 skipped"** (was 30 checked / 2 skipped — the 2 multibyte files threw on `iolist_to_binary` and were caught-as-skipped). Closes arc row A1-5. | closes the v0.3.0 carry-out |
| A1S1-10 | `pe_*` + `docs/planning/v0.5.0/` untouched; no `0.4.0` tag | `git diff -- 'src/pe_*.erl' docs/planning/v0.5.0` empty; `git tag -l 0.4.0` empty | serious | scope control | done | `git diff --stat 4bf3af0..HEAD -- 'src/pe_*.erl' docs/planning/v0.5.0` → **empty**. `git tag -l 0.4.0` → empty. | tag at slice 2 / arc close |

## Amendments (CC-raised refinements)

_(none — the "split is a proposal" caution pre-authorized the merged seam, so the
infeasible 4-way split is a disclosed design outcome (A1S1-4), not a scope
amendment.)_

## Caveats

- **The proposed 4-module render/clause/data split is infeasible** — those
  helpers are one 23-function mutually-recursive SCC. Delivered a 3-module
  decomposition (orchestrator / render core / util helpers) + shared `.hrl`,
  which the gate explicitly sanctions ("behaviour identical + layering clean,
  not exactly four modules").
- **31 lines in `lfmt_fezzik_render.erl` exceed 100 cols** — a cosmetic
  consequence of module-qualifying calls (`lfmt_fezzik_util:` prefix). `rebar3
  fmt` was **not** run: the codebase is not erlfmt-clean (many pre-existing
  `pe_*` + imported files are flagged), so a global format would touch `pe_*`
  (scope breach), and the plugin doesn't take per-file args cleanly. Left as-is;
  source bodies are otherwise verbatim from the original (formatting + comments
  preserved). A targeted erlfmt pass is a possible follow-up.
- Toolchain rows run locally on OTP 28; "CI reconciles" per the arc plan.

## What Worked

- **Computing the strongly-connected components of the local call graph before
  splitting.** It turned "the helpers are likely mutually recursive" into a
  precise, disclosable fact (one 23-fn SCC) and handed me the real seams —
  no guessing, no forced indirection.
- **The byte-identical golden as the refactor proof.** Capturing it on `main`
  *before* the split made "behaviour identical" a hard sha256 check, not a hope
  riding on ct.
- **Driving the relocation from authoritative form spans (`erl_scan`) +
  per-module call qualification**, then leaning on compile + golden + ct to
  catch the two real gaps (shared `head_class()` type; `fun NAME/Arity` refs).

## Closure

Self-assessed complete. Commit 1 (split) `f4790e1`; commit 2 (hygiene) `46240a5`;
base `4bf3af0`. Total rows: **10**. Done: **10**. Deferred: **0**. No-op: **0**.
CC self-assessment only — **CDC verification pending** (`cdc-verification.md`).
Sets up `slice2-hex-release` (vsn → 0.4.0, publish, tag). CC did **not** publish
or tag `0.4.0`.
