# arc2 / slice2 — positioned reader (adapt `lfe_scan`)

> Design + scope. Companion: `cc-prompt.md`, `ledger.md`. Arc: arc2-fidelity.
> Prior: slice1 (the `lfe_io`-based faithful reader — now the differential
> oracle). Next: slice3 (render the captured comments).

## Why this slice exists

"Full intra-form" comment fidelity (operator decision 2026-06-25) needs a
**position on every subform**. `lfe_io` gives only top-level form lines, and
`lfe_scan` computes line+col but discards them and *skips comments entirely*. So
we build our own positioned, comment-preserving reader. We **adapt `lfe_scan`**
(Apache-2.0, Robert Virding) rather than write from scratch: it already encodes
every LFE surface form + all three comment kinds correctly and already computes
the columns we need. Re-deriving that would throw away 20 years of edge-case
correctness for no gain.

## What we build

1. **`pe_lfe_scan`** — an adapted scanner, with three surgical changes vs
   `lfe_scan`: (a) **binary-based** (operate on the source binary with binary
   pattern-matching, not a char list — the modern BEAM idiom, a real perf win);
   (b) **keep line+col** on every token (it already computes them); (c) **emit
   comments** (`;` line, `#|…|#` block; `#;` datum is already a token) as
   **trivia tokens** instead of skipping. Apache-2.0 attribution in the header +
   a NOTICE entry.
2. **`pe_lfe_cst`** — a thin positioned recursive-descent parser over the token
   stream producing a **`cst()`**: the existing `form()` shape, but every node
   carries `{pos, leading_trivia, trailing_trivia}`. Trivia is bound by the
   **Roslyn following-token model**: a token's *trailing* trivia is what follows
   it through end-of-line; its *leading* trivia is everything else, bound to the
   *next* token. A node's leading/trailing trivia come from its boundary tokens.
   Plus `cst_to_form/1` — strip positions+trivia back to a plain `form()`.

This is **additive**: `pe_lfe` lowering and the engine are untouched. slice3
makes lowering trivia-aware.

## Two differential oracles (the correctness story)

Same move as slice8 (Rust oracle) — we don't trust the new reader, we prove it:

- **Token level:** `pe_lfe_scan`'s non-trivia tokens (values) `=:=` `lfe_scan`'s
  tokens over the corpus.
- **AST level:** `cst_to_form(read(src))` `=:=` slice1's `lfe_io`-based reader
  `form()` over the corpus — the **739/739** gate, now against our own reader.

If both hold, the adapted reader is faithful at token *and* AST level; the only
additions are positions + comment trivia (which the oracles don't have).

## The new power: comment capture

Independent gate: scan the corpus for comments (an independent counter), and
assert **every comment is captured** as a trivia token, attached to a node per
the Roslyn rule, with correct position and leading/trailing classification. No
comment may be lost from the token stream — losing one is destroying source.
(Rendering them in formatted output is slice3; this slice proves *capture +
attachment*, not yet *output placement*.)

## Dependency posture (resolved)

The adapted scanner needs **no `lfe` at runtime** → `src/` stays zero-dep
permanently; `lfe` is test-only, as the oracle. This is the clean resolution of
the posture question the arc-plan flagged.

## Scope / non-goals

- In: `src/pe_lfe_scan.erl`, `src/pe_lfe_cst.erl`, their tests, the two
  differential corpus tests, the comment-capture gate.
- Out: rendering comments in output + idempotence-with-comments (slice3);
  changing `pe_lfe` lowering or the engine (untouched); width model (slice5);
  CLI wiring (arc3). Full byte-exact whitespace preservation is **not** a goal —
  we reformat whitespace; only *comments* are preserved trivia.
- Upstream: the adapted scanner is a candidate contribution to LFE, built to
  that bar, but the offer is decided later and never gates this slice.
