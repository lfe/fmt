# Slice 1: split

> Project: `v0.4.0`
> Arc: `arc1-release`
> Slice: `slice1-split`
> Status: planned for CC
> Next: `slice2-hex-release`, then `slice3-rebar3-integration`

## Purpose

Decompose the 1869-line `lfmt_fezzik.erl` renderer into focused modules with
**clean, acyclic layering** — a **pure, behaviour-identical refactor** — so the
engine published at 0.4.0 is maintainable, not a monolith. Also fold in the
carried v0.3.0 `conf_wide_sweep` hygiene as a **separate** test-only commit.

## Scope

In scope:

- **Split** `lfmt_fezzik.erl` into focused modules (proposal below; the actual
  seams are settled by `xref`, see §The split is a proposal). Distribute the
  `-type`/`-spec`s and the `-dialyzer({no_underspecs, format/1})` attribute to
  wherever `format/1` lands. `git mv`/new files as needed; history-preserving
  where a module is largely lifted.
- **Hygiene (separate commit):** swap `conf_wide_sweep`'s formatter-output
  flatten from `iolist_to_binary` to `fmt_output_bin` so it stops silently
  skipping the 2 multibyte files (v0.3.0 carry-out; slice-2 cdc F3).

Out of scope: any behaviour change to the formatter; `vsn`/publish (slice 2);
`rebar3_lfe` (slice 3); `pe_*`.

## Proposed decomposition (a proposal, not a settled boundary)

Following the section banners in `lfmt_fezzik.erl`:

| module | absorbs (current section banners) |
|---|---|
| `lfmt_fezzik` | public `format/1`, regime classification (~L39), document-level dispatch (~L83) — the entry + orchestrator |
| `lfmt_fezzik_render` | break-preserving renderer (~L224), classified-broken (~L1062), flat (~L1677) |
| `lfmt_fezzik_clause` | clause helpers (~L841), defform (~L914), head-classification (~L978) |
| `lfmt_fezzik_data` | cons-dot helpers (~L455), map k/v (~L476), data-container layout |
| `lfmt_fezzik_lexer` / `lfmt_fezzik_cst` | already separate |

**This is a starting proposal.** The renderer and the clause/data helpers are
**likely mutually recursive**. `xref` (and the call graph) settle the real seams
**before** the boundaries are committed. Where recursion crosses a proposed
seam, keep it inside one module or thread it through `lfmt_fezzik` as
orchestrator, and **disclose the merged boundary** — do **not** add indirection
purely to honour a guessed split. The intended layering is
`lexer → cst → {data, clause} → render → fezzik` (no module calls "up").

## Behaviour-preservation — the load-bearing gate

A split is only correct if output is unchanged. The strong proof:

1. **Byte-identical corpus output.** Before the split (on `main`), capture the
   formatted output of the full corpus (the 84-file inline-oracle set + the
   sweeps' corpus). After the split, regenerate and confirm **byte-for-byte
   identical** output. This is stronger than "tests pass."
2. **Full `ct` green** — the idempotence / token / AST / comment oracles
   unchanged, all 274 tests pass.
3. **`xref` clean + acyclic layering** — no undefined calls; the module
   dependency graph matches the intended direction (state the final graph).
4. `compile` zero-warning; `dialyzer` clean (types/specs distributed correctly;
   `lfmt_fezzik_cst:cst_node()` references intact across the new modules).

## Dependency / base

Branch `feature/v0.4.0-release` off the consolidated `main` (has v0.1.0–v0.3.0).

## Success criteria (gate)

- `lfmt_fezzik.erl` decomposed; each new module compiles; public API
  (`lfmt_fezzik:format/1`) unchanged (the suite + any caller still resolve).
- Byte-identical corpus output pre/post split (the refactor proof).
- Full `ct` green; `xref` clean with a disclosed acyclic layering; `compile`
  zero-warning; `dialyzer` clean.
- Any merged seam (mutual recursion) disclosed with rationale — gate is
  "behaviour identical + layering clean," **not** "exactly four modules."
- The `conf_wide_sweep` hygiene is a **separate commit**; it no longer skips the
  2 multibyte files (state the skipped-count drop).
- `pe_*` + `docs/planning/v0.5.0/` untouched; no `0.4.0` tag (slice 2 / arc).

## Handoff

CC provides: the split (history-preserving where possible) + the separate
hygiene commit; the byte-identical-output evidence; the final module dependency
graph (xref); green ct/compile/xref/dialyzer; a per-row ledger walk +
`closing-report.md` with the bubble-up (incl. which seams, if any, were merged).
