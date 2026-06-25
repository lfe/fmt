# arc2 / slice1 — faithful reader (lossless AST + positions, no comments)

> Design + scope. Companion: `cc-prompt.md`, `ledger.md`. Arc: arc2-fidelity.
> Prior: slice6 (the lossy benchmark bridge this slice makes faithful).

## Why this slice exists

It is the keystone of arc2: the formatter can only be acceptance-tested if it
reads real source *faithfully*. slice6's bridge was lossy by design (comments
dropped, strings collapsed, `comma-at` loses `@`, floats/binaries/maps →
printed-text leaves, call-vs-list guessed). This slice removes the lossiness for
everything **except comments** (slice2's job): a lossless `form()` model and a
faithful LFE-reader bridge that produces exact ASTs, proven by an AST
round-trip over the real corpus.

## What "faithful" means here (and what it doesn't)

- **In:** every non-comment construct in `examples/*.lfe` + `test/*.lfe` +
  cl/clj.lfe converts to an exact `form()` and survives `read → format → read`
  unchanged (structurally). No genericisation, no printed-text fallback — an
  unmodeled construct must *crash with a clear error*, not silently degrade.
- **Out (→ slice2):** comments and intra-form source spans. LFE's reader
  (`lfe_io`) drops comments and gives line-only positions; that is exactly the
  boundary where slice2's separate comment lexer takes over. slice1 captures
  **top-level form line** (from `lfe_io:parse_file/1`'s `{Sexpr, Line}`) and no
  deeper.

## `form()` extensions (evidence-based)

Census of the corpus shows `form()` is missing constructors for: **float**
(~222), **binary literal** `#"…"` / `#B(…)` (~114), **map literal** `#M(…)` (1),
**char** `#\x` (3); and **strings** must be handled faithfully (not collapsed to
a printed leaf). Add to `pe_lfe:form()` and give each a lowering rule:

- `{float, float()}` — render via a canonical float printer (decide: shortest
  round-trippable form; `~p`/`io_lib` is acceptable for slice1).
- `{char, char()}` — render as `#\x`.
- `{binary, binary()}` (literal `#"…"`) and the `#B(…)` bitstring form — note
  `(binary …)` call-syntax (~55) is already a `{call}` and needs nothing.
- `{map, [{form(), form()}]}` — render as `#M(k v …)`.
- strings: keep `{str, binary()}` but ensure the reader emits `{str,_}` for
  `"…"` and does **not** collapse char-lists into one printed leaf.

These are `src/pe_lfe.erl` changes (the model + lowering). Adding a constructor
must not break existing lowering or the slice9 registry dispatch.

## The faithful reader

`test/pe_lfe_read.erl` (evolve slice6's module; stays test-profile per the
arc-plan dep-posture note). Use `lfe_io:parse_file/1 → {ok,[{Sexpr,Line}]}` for
top-level line info; convert each `Sexpr` to an exact `form()`:

- atoms→`{sym, atom_to_binary}`; integers→`{int}`; floats→`{float}`;
  chars→`{char}`; binaries→`{binary}`; maps→`{map}`; tuples→`{tuple}`;
  strings→`{str}`; proper/improper lists→`{call|list}`/`{dotted_list}`;
  quote-family heads→`{quote|bquote|unquote}` (confirmed against `lfe_parse`).
- **No fallback clause.** An unrecognised term raises `{unmodeled_construct, T}`.
  The corpus round-trip (below) proves the set is complete for real LFE.

## The gate: AST round-trip

For every top-level form `F` parsed from a corpus file: `format` it to text,
re-read that text with the faithful reader, and assert the re-read form is
**structurally equal** to `F`. This proves `read∘format ≡ read` at the form
level — the formatter does not change meaning — *and* that we emit valid,
re-readable LFE. Plus: **0 `unmodeled_construct` errors** across the whole
corpus (the real-input completeness gate).

(Idempotence `format∘format == format` is slice3's formal harness, but a cheap
spot-check here is welcome.)

## Non-goals

Comments + intra-form spans (slice2); idempotence/round-trip *acceptance suite*
(slice3); width model (slice4); new conventions (slice5); reader→`src/`
graduation, runtime-dep flip, CLI wiring (later/arc3). No resolver/engine
changes.
