# CC prompt — arc1-poc / slice9 — declarative LFE rule registry

> For CC (implementation seat). **Read `slice-doc.md` first.** Load
> **erlang-guidelines** (`11-anti-patterns` first, then `04-data-and-types`,
> `05-functions`, `15-testing`). Walk the ledger; CDC verifies independently.
> Iteration cap: 5. Independent of slice8 — touches only the knowledge layer
> (`pe_lfe`), never the engine (`pe_*`).

## Goal

Replace `pe_lfe`'s hardcoded head dispatch with a **data-driven rule registry**:
a `priv/lfe-format-rules.lfe` data file mapping form-name → style-tag → params,
loaded into a `ctx()`-threaded map and dispatched over a **fixed style palette**
(the existing layout functions, given stable tags). **Adding a form that fits an
existing style must become a data-only edit.** Behavior for the existing 20-form
corpus must be **byte-identical**.

## Ground truth — the seam

`src/pe_lfe.erl`:
- `call_form/4` (~104–120): `case Head of <<"defun">> -> def_form(...); … ;
  _ -> generic_call(...) end`. **This is the table-as-code.**
- Palette functions today: `def_form` (defun/defmacro), `lambda_form` (lambda),
  `clauses_block` (match-lambda/cond), `let_form` (let/let*),
  `flet_form` (flet/fletrec), `subject_block` (case), `receive_form` (receive),
  `body_block` (progn/eval-when-compile), generic fallback.
- `to_doc/1,2` thread `ctx() :: #{indent := pos_integer()}`; lowering is
  `lower/3`. Symbols are binaries (`{sym, binary()}`); **no atoms are minted
  from formatted input** (slice3 A1S3-2 — keep this true).

Provenance source: `lfe/lfe/emacs/lfe-indent.el` `define-lfe-indent` table.

## Design constraints (hold these)

- **Behavior-preserving refactor.** The seed `priv/lfe-format-rules.lfe` encodes
  *exactly* today's dispatch. All slice3 eunit/golden tests pass **unchanged and
  byte-identical** (Ackermann exact, `let_vertical`, `case/receive/cond`,
  `eval_when_compile_block`, the `lfe_07_bq_expand` indent fix). Prove
  DAG/output equivalence vs the pre-slice path over all 20 samples × width
  sweep.
- **Data, not functions.** The per-form rule is data; the palette is a small
  closed code set reached through one `apply_style/6`. Adding a *form* = data
  row. Adding a *style* = one `apply_style` clause + a palette fn (rare).
- **No global mutable state.** Load the registry into `ctx()` at `to_doc/2`
  entry; allow a caller-supplied registry (tests / overlay). `persistent_term`
  is acceptable only as a read-only cache, not as the source of truth.
- **No atom minting from formatted input.** Form names in the data file are
  **strings** → binary registry keys directly. Style tags / param keys are
  atoms (closed developer set; the rules file is trusted config). Document this
  distinction so CDC does not flag it.
- **Don't data-drive the styles.** The layout logic stays in code. Resist
  inventing a layout DSL in the data file.

## Steps

1. **Define the data file + schema.** `priv/lfe-format-rules.lfe` per the
   slice-doc sketch: `(rules (version 1) (rule "<form>" <tag> (<params>)) …)`.
   Seed it with **exactly today's 13 form→function mappings**. Form names as
   strings; tags as atoms; params an (initially empty) open list/map.

2. **Loader.** `load_rules/0,1`: read the file via `lfe_io` (recommended) or
   `file:consult` (Erlang-terms fallback — see slice-doc open question) from
   `code:priv_dir(fmt)`; build `#{FormBin => {Tag, Params}}`. Add an optional
   **overlay** arg merged over the base (overlay wins). Validate rows (unknown
   tag = load error, not silent skip). Specs + dialyzer-clean.

3. **Palette + `apply_style/6`.** Give each existing layout function a stable
   tag and route through a single closed
   `apply_style(Tag, Params, Head, Args, Ctx, B)`:
   `define | lambda | clauses | let-binds | flet-binds | subject | receive |
   block`. Keep each function's body as-is (behavior preservation); this step is
   wiring + naming, not relayout. (Optional, only if all goldens hold:
   consolidate obvious cousins, e.g. `let-binds`/`flet-binds`. Skip if risky.)

4. **Rewire `call_form/4`.** Replace the `case Head of …` with:
   registry-lookup `Head` in `ctx()` → `{ok,{Tag,Params}}` →
   `apply_style(Tag, Params, Head, Args, Ctx, B)`; `error` → `generic_call`
   (unchanged). Load the registry into `ctx()` at `to_doc/2` entry (default
   base; honor a caller override).

5. **Behavior-preservation tests.** A property/structural check that for all 20
   `pe_lfe_samples`, the new path yields the **same rendered bytes** (and ideally
   the same DAG) as the committed pre-slice path, across the width sweep. Keep
   every slice3 golden green and unchanged.

6. **Provenance cross-reference.** Walk `lfe-indent.el`'s `define-lfe-indent`
   table; for each form, confirm it is either a rule row or a documented
   `application`/deferred entry. Record the deferred forms (those needing new
   styles) as ledger notes, not silent omissions.

7. **One data-only demonstrator.** Add a single new form from the Emacs table
   that fits an existing style with **no new palette code** (e.g. `catch` →
   `block`, or `when` → `block`) as a **data row + one golden test** — proving
   form-addition is data-only. Do not sweep.

8. **(Optional) JSON derive.** A small escript emitting
   `lfe-format-rules.json` (`[{form,style,params}]`) from the s-expr source +
   a round-trip check, validating the format is transformable. Mark no-op-able
   ("no Rust consumer yet"); do not wire into default CI.

9. **Closing report.** State: registry wired; behavior-identical evidence (20
   samples × widths); the Emacs-table provenance result (covered vs deferred
   forms); the demonstrator; the optional derive disposition.

## Ledger

See `ledger.md`. Walk it row by row; every row reaches `done` / `deferred` /
`no-op` with reproducible evidence before close.
