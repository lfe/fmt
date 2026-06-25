# Slice 9 — declarative LFE rule registry (data-driven knowledge layer)

> Design + scope. Companion: `cc-prompt.md`, `ledger.md`. Arc: arc1-poc.
> Prior: slice3 (the knowledge layer this slice refactors). Independent of
> slice8 (engine alignment). CDC-authored for CC.

## Why this slice exists

slice3 gave us a working LFE knowledge layer (`pe_lfe`), and it works by a
**hardcoded head dispatch** — `call_form/4` is a literal
`case Head of <<"defun">> -> def_form(...); <<"let">> -> let_form(...); …` over
the ~10 special forms in the 20-sample corpus (pe_lfe.erl ~106–120). Every new
form means a new code clause; the rules and the layout logic are fused; and the
table that *is* LFE's formatting convention lives as Erlang source, where it is
"supremely awkward and really hard to maintain" (operator, 2026-06-24).

This is the same shape raco fmt has — its 183-form `standard-formatter-map` is a
giant hand-written `case` — and the same shape LFE has carried for decades in
`lfe-indent.el`'s `define-lfe-indent` table. The difference is that the Emacs
table is **data** (`(form N)`), and ours is **code**.

slice9 inverts that: make the per-form rules **data**, dispatched at runtime
over a small **fixed palette** of layout styles. The operator's exact ask:
*store data, generate the dispatch as needed; never hand-maintain a file of
functions.*

## The key structural fact (why this is tractable, not a rewrite)

The dispatch looks like ~10 rules but bottoms out in a **small, closed palette**
of bespoke layout functions — today: `def_form`, `lambda_form`, `clauses_block`,
`let_form`, `flet_form`, `subject_block`, `receive_form`, `body_block`, plus the
generic fallback. Many forms already share one (`let`+`let*`→`let_form`;
`flet`+`fletrec`→`flet_form`; `match-lambda`+`cond`→`clauses_block`;
`progn`+`eval-when-compile`→`body_block`). So the per-form mapping genuinely
*is* data over a finite style set; only the styles are irreducibly code (they
encode break/choice/indent in pe combinators — data-driving *those* would mean
reinventing the engine in config, which is the over-engineering trap we
explicitly avoid).

**The honest boundary:** after this slice, adding a form that fits an existing
style is a **data row, no code**. Adding a genuinely new *layout shape* is still
a new palette function (code) plus one `apply_style` clause. That is the right
line — it matches raco's ~6–8 styles and LFE's ~5.

## Design shape

Three pieces:

1. **A data source of truth** — `priv/lfe-format-rules.lfe`, an s-expr data
   file mapping form-name → style-tag → params. Read once at lowering entry.
2. **A fixed style palette** — the existing `pe_lfe` layout functions, given
   stable **tags** and reached through a single closed
   `apply_style(Tag, Params, Head, Args, Ctx, B)` dispatch.
3. **A registry loader** — reads the data file into a
   `#{FormBin => {Tag, Params}}` map, threaded through `ctx()` (no global
   state), with the generic S-expression rule as the `error`/fallback.

`call_form/4` changes from `case Head of …` (open, grows per form) to
`registry_lookup(Head, Ctx)` → `apply_style/6` (data in, closed code dispatch
out).

### The data format — and why s-expr, not JSON/TOML

The rule vocabulary needs only: a form name, a style tag, and a small params
payload. The value types involved are **strings, atoms (a closed tag set),
small integers, and booleans** — nothing rich. An s-expr term file preserves
exactly those natively, with **zero coercion and zero parser dependency beyond
`lfe` (already a dep)**, and it reads like the `lfe-indent.el` ancestor it
descends from. JSON would force atom↔string coercion and add a dep; TOML the
same. So the source of truth is s-expr; any other representation (a derived
JSON for a future non-BEAM consumer; a codegen module if ever wanted) is a
**derived build artifact**, never hand-maintained.

Sketch (illustrative; CC finalizes):

```lisp
;; priv/lfe-format-rules.lfe  — DATA, not code
(rules
  (version 1)
  ;;     form-name        style       params
  (rule  "defun"          define      ())
  (rule  "defmacro"       define      ())
  (rule  "lambda"         lambda      ())
  (rule  "match-lambda"   clauses     ())
  (rule  "let"            let-binds   ())
  (rule  "let*"           let-binds   ())
  (rule  "flet"           flet-binds  ())
  (rule  "fletrec"        flet-binds  ())
  (rule  "case"           subject     ())
  (rule  "receive"        receive     ())
  (rule  "cond"           clauses     ())
  (rule  "progn"          block       ())
  (rule  "eval-when-compile" block    ()))
  ;; unlisted heads → application (the generic S-expression fallback)
```

- **Form names as strings** → map directly to the binary `{sym, binary()}`
  heads with no atom interning, honoring slice3's no-mint-from-input rule
  (A1S3-2). The rules file is trusted in-repo config, a distinct category from
  formatted input, but strings sidestep the question entirely.
- **Style tags as atoms** — a closed, developer-authored set; these are code
  identifiers, so atoms are correct and safe.
- **Params an open list/map**, empty today, so the schema does not calcify when
  a style later needs a knob (e.g. body-indent step, a `distinguished`/`heads`
  count, or per-keyword indents à la raco's `syntax-parse` directive maps).

### Layering (mirrors raco's `compose-formatter-map`)

The base `priv/lfe-format-rules.lfe` is the LFE standard. The loader accepts an
optional **user overlay** merged over the base (overlay wins per form), so users
extend or override without forking the standard. Threaded through `ctx()`, this
also makes tests trivially injectable (pass a custom registry).

## Behavior preservation is the gate

This slice is a **refactor + extensibility feature, not a conventions change.**
The seed data file encodes *exactly today's dispatch set*, so every slice3
golden must pass **byte-identically** — Ackermann's exact 4-line shape,
`let_vertical`, `case/receive/cond` verticals, the `eval-when-compile` block,
the `lfe_07_bq_expand` indent fix. The load-bearing invariant (slice7-style):
the data-driven path produces the **same DAG / same output** as the pre-slice
hardcoded path for all 20 samples and across the width sweep. New conventions
are out of scope.

## The payoff, demonstrated (bounded)

To prove the mechanism actually delivers "new form = data only," the slice adds
**one** demonstrator: a form from `lfe-indent.el` not currently special-cased
but which fits an existing style with **no new palette code** (candidate:
`when`/`progn`-like → `block`, or `catch` → `block`), added as a **data row
plus one golden test**. This is a demonstration, not a sweep — a full
convention-coverage expansion (e.g. `if`, comprehensions, `try`/`maybe`,
`do`, `prog1/2`) is a separate future knowledge slice, because each is a real
convention decision needing its own golden.

## Provenance: seed from `lfe-indent.el`

The base rules file is cross-referenced against
`lfe/lfe/emacs/lfe-indent.el`'s `define-lfe-indent` table — the canonical,
decades-old LFE indentation source. Every form in that table is either (a) given
a rule row, or (b) consciously left to `application`/deferred **with a noted
reason**. This makes the Emacs table the documented provenance and surfaces the
forms LFE has conventions for that slice3 didn't cover (captured as deferred
rows, not silently dropped).

## The Rust transformer (operator's "maybe") — designed-for, not built

A derive step could emit a neutral `lfe-format-rules.json`
(`[{form, style, params}]`) from the s-expr source for a future Rust LFE
formatter to consume. But **there is no Rust LFE formatter today** — slice8's
oracle checks the *engine*, which has no rules — so there is nothing to feed.
The slice therefore *designs the format to be derivable* (flat, simple, typed)
and includes the transformer only as an **optional** row (a ~20-line escript +
a round-trip check), explicitly no-op-able with rationale "no consumer yet."
Building it for real waits on the artifact that would consume it.

## Scope / non-goals

- **In:** `priv/lfe-format-rules.lfe` (seeded = today's dispatch, provenance
  from `lfe-indent.el`); the registry loader + `ctx()` threading + optional
  overlay; the style palette given stable tags + a single `apply_style/6`
  dispatch; `call_form/4` rewired to registry-lookup→apply-style→generic; the
  behavior-preservation invariant + tests; one data-only demonstrator form;
  optional JSON derive.
- **Out:** new layout *conventions* beyond the one demonstrator (separate
  slice); parsing `.lfe` source / comments (still slice-N later); collapsing the
  palette into fewer parameterized styles (optional, only if goldens hold);
  the actual Rust LFE formatter + a real transformer consumer; OTP 22–29
  backport; coverage gate + CAP audit (carried arc deferrals).

## Open question for the operator (non-blocking; CC may default)

- **Data-file syntax.** Recommended: s-expr read via `lfe_io` (on-brand, native
  types, `lfe` already a dep, lineage from the Emacs table). Zero-dependency
  alternative: Erlang terms via `file:consult` (`{rule, "defun", define, []}`).
  Recommendation stands unless you prefer to keep the loader pure-Erlang.
