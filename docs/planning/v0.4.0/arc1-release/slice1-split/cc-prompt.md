# CC prompt — fmt v0.4.0 · arc1-release / slice1-split

You are CC. Decompose the 1869-line `lfmt_fezzik.erl` renderer into focused
modules — a **pure, behaviour-identical refactor** — and, as a **separate
commit**, fold in the carried v0.3.0 `conf_wide_sweep` hygiene. You run `git` +
the toolchain directly.

Target OTP 28. Load **collaboration-framework** (ledger discipline) and
**erlang-guidelines** (`11-anti-patterns`, `02-api-design`, `10-performance`,
`15-testing`, `17-tooling`).

## Read first

- `docs/planning/v0.4.0/project-plan.md` and `arc1-release/arc-plan.md`
  (esp. §The split is a proposal + §Base branch).
- This slice's `slice-doc.md` (proposal + the behaviour-preservation gate) and
  `ledger.md`.

## Base

Branch `feature/v0.4.0-release` off the consolidated **`main`** (has v0.1.0–
v0.3.0; `lfmt_fezzik*`, app `lfmt` v0.3.0). Confirm with Duncan if unsure.

## Step 0 — capture the behaviour baseline FIRST

Before touching anything, on `main`: generate the formatted output of the full
corpus (the inline-oracle 84-file set + the sweep corpus) and save it as a
golden. This is your byte-identical proof for A1S1-2 — capture it *before* the
split so the comparison is real.

## Step 1 — split (commit 1, src-only, pure refactor)

Decompose `lfmt_fezzik.erl` per the proposal in `slice-doc.md`
(`lfmt_fezzik` = API + regime + doc-dispatch; `lfmt_fezzik_render`;
`lfmt_fezzik_clause`; `lfmt_fezzik_data`). **The seams are a proposal** — let
`xref` and the call graph settle them:

- Map the inter-function call graph first. The renderer and clause/data helpers
  are likely mutually recursive. Where recursion would cross a seam, **keep it
  in one module** or thread through `lfmt_fezzik` as orchestrator — do **not**
  add indirection just to hit four modules. **Disclose any merged seam.**
- Target layering `lexer → cst → {data, clause} → render → fezzik` — no module
  calls "up." Confirm with `xref` before finalizing.
- Distribute `-type`/`-spec`s; keep `lfmt_fezzik_cst:cst_node()` references
  correct; carry `-dialyzer({no_underspecs, format/1})` to wherever `format/1`
  lands. Public API `lfmt_fezzik:format/1` stays the entry point.

Commit 1 is **src/ only**.

## Step 2 — conf_wide_sweep hygiene (commit 2, test-only)

Separately: in `test/lfmt_fezzik_SUITE.erl`, swap `conf_wide_sweep`'s
formatter-output flatten from `iolist_to_binary` to `fmt_output_bin` (the helper
slice v0.3.0/slice2 added), so it stops silently *skipping* the 2 multibyte
files (`iolist_to_binary` throws on codepoints >255 → caught → skipped). Keep it
a **separate commit** so the split stays a pure src refactor.

## Engineering bar

- **Byte-identical corpus output** pre/post split (diff the golden → empty). The
  refactor proof.
- Full `rebar3 ct` green (274, oracles unchanged); `compile` zero-warning;
  `rebar3 xref` clean **and** the module dependency graph acyclic in the
  intended direction (state it); `rebar3 dialyzer` clean. (CI reconciles.)
- `conf_wide_sweep` no longer skips the 2 multibyte files (`ct:log` skipped-count
  drops); state it.
- `git diff -- 'src/pe_*.erl' docs/planning/v0.5.0` → empty; `git tag -l 0.4.0`
  → empty (tag is slice 2 / arc close).

## Working ledger + close

Update `ledger.md` per-row (toolchain rows note "CI reconciles"). At close write
`closing-report.md`: per-row walk + **bubble-up to the arc**, explicitly stating
(a) the final module set + dependency graph, (b) any seam you merged and why,
(c) that the v0.3.0 `conf_wide_sweep` hygiene is closed. Don't mark your own rows
CDC-verified. Do **not** publish or tag.

## When done

Hand back: the two commits (split; hygiene); the byte-identical-output evidence;
the module dependency graph; green ct/compile/xref/dialyzer; the per-row ledger
walk + closing-report. This sets up slice 2 (hex-release).
