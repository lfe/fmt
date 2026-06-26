# arc2-fidelity — plan

> The arc that turns the proven Πₑ engine into a **correct LFE formatter**:
> faithful input, meaning-preserving + idempotent + comment-preserving output,
> verified against the real LFE corpus. Successor to `arc1-poc`. Same version
> line (`v0.5.0`). Release-hardening is explicitly *out of scope* → future
> `arc3-release`.

## Why this arc (and why it's not arc1-poc anymore)

arc1-poc answered, six ways, "is an optimal pretty-printer viable on the BEAM
for LFE?" — yes: correct (oracle + property tests), fast (25–60 ms whole-file),
no `W⁴` tail (frontiers ≤ 7), cross-validated against an independent Rust
pretty-expressive (slice8), with a maintainable data-driven rule registry
(slice9). Slices 8–9 pushed us past proof-of-concept.

Everything arc1 proved is about the **engine** (optimal/fast layouts) and **rule
ergonomics** (easy to add forms). None of it touches the property that actually
defines a *correct formatter*: **fidelity** — does the formatter preserve the
program? Three sub-properties, all currently unbuilt and unverified:

1. **Idempotence** — `format(format(x)) == format(x)`.
2. **Semantic round-trip** — `read(format(x)) ≡ read(x)`; formatting never
   changes meaning.
3. **Comment preservation** — every comment survives, sanely attached.

All three are gated on one missing capability: a **faithful reader**. Every
real-file result so far (slice6/7) went through the slice6 *benchmark bridge*,
which is lossy by design (drops comments, collapses strings, loses `comma-at`'s
`@`, guesses call-vs-list). Fine for latency/frontier measurement; useless for
acceptance. You cannot acceptance-test a formatter through a reader that
discards comments.

## The acceptance corpus

`lfe/lfe/examples/*.lfe` (20 files, 3093 lines) — and pleasingly, the slice2/3
fixtures were hand-derived from these very files (gps1, ets-demo, ping-pong, …).
Plus `lfe/lfe/test/*.lfe` and `cl.lfe`/`clj.lfe`. Construct census across that
corpus (slice1 sizing): floats (~222), binary literals (~114), maps (1), chars
(3), strings (~569), comments throughout.

## Slice breakdown

| # | Slice | Delivers | Gate |
|---|-------|----------|------|
| 1 | **faithful-reader** (done) | lossless `form()` (+ float/binary/map/splice, faithful strings) + an `lfe_io`-based faithful reader; top-level positions; **no comments** | AST round-trip `read∘format ≡ read` + **0 unmodeled** across the corpus — **739/739, done** |
| 2 | **positioned reader** | **adapt `lfe_scan`** (Apache-2.0) → binary-based, column-keeping, comment-emitting scanner + a thin positioned recursive-descent parser → a positioned, comment-trivia-bearing tree (`cst()`); `cst→form()` strip | `cst→form()` `=:=` slice1/`lfe_io` AST (739/739 differential oracle) + every comment captured with position + a position on every node; zero-dep |
| 3 | **comment rendering** | thread the captured trivia through `pe_lfe` lowering (**Roslyn following-token model**) so comments render in place; intra-form + inter-form, exact | every input comment present + exactly placed on the corpus; idempotence-with-comments |
| 4 | **acceptance** | idempotence + semantic round-trip + comment-preservation harness as the formal acceptance suite over examples + tests + cl/clj | `format∘format == format`, `read∘format ≡ read`, comments preserved — corpus-wide |
| 5 | **width-model** (A1-R008) | decide + encode display-width policy (ASCII bytes vs Unicode grapheme/display width) | width semantics specced + tested |
| 6 | **conventions** (A1-R020) | the forms slice9 deferred for needing *new* palette styles; broaden the registry | deferred forms styled with named rules |

**Reader = two slices** (2 + 3). "Full intra-form" comment fidelity (operator
decision 2026-06-25) requires per-subform positions, which `lfe_io` does not
give — so we build our own positioned reader by **adapting `lfe_scan`** rather
than from scratch: it already computes line+col (discards them) and handles
every LFE surface form + all three comment kinds, so we make surgical edits
(keep columns, emit comments as trivia, binary-based for speed) and inherit 20
years of edge-case correctness. The slice1 `lfe_io` reader becomes the
**differential oracle** (same pattern as slice8's Rust oracle). Trivia uses the
**Roslyn following-token model** (rust-analyzer is migrating to it; cleaner for
formatters). The adapted scanner is also a candidate **upstream contribution** —
built to that quality bar, but the offer is decided *later*, never gating arc2.

## Carried forward from arc1 running-recommendations

- **A1-R008** (renderer width model) → **slice4**.
- **A1-R020** (deferred LFE forms / new conventions) → **slice5**.
- **A1-R018** (newline-cost divergence from mjl, kept ours) → watch; revisit if
  acceptance output looks wrong.

## Out of scope → future arc3-release

OTP 22–29 backport (A1-R005), coverage gate, CAP strength audit, packaging /
JSR-npm-Hex publish, and **wiring the reader into the user-facing CLI /
`rebar3_lfe` provider**. These are release-hardening, not fidelity.

## The dependency-posture decision (RESOLVED by the adapted reader)

The earlier worry was that a faithful reader leaning on `lfe_io` would
eventually force `lfe` to become a **runtime** dep. Adapting `lfe_scan` into our
own in-tree scanner **dissolves that worry**: our reader needs no `lfe` at
runtime, so:

- The engine (`pe_doc`/`pe_cost`/`pe_mset`/`pe_resolve`/`pe_render`/`pe_measure`)
  **and** the LFE front-end (`pe_lfe`, the new `pe_lfe_cst`/reader) all stay
  **zero runtime deps**. `{deps, []}` holds permanently.
- `lfe` stays a **test-only** dependency *forever* — purely as the differential
  oracle (`cst→form() =:= lfe_io` on the corpus). It never ships.

This is a strict improvement over the slice1 posture (slice1's `lfe_io`-based
reader stays as the test oracle; the slice2 adapted reader is the production
path). Licensing: `lfe_scan` is Apache-2.0 (Robert Virding) — adapt with a
source attribution + NOTICE entry. Wiring the production reader into the
user-facing CLI / `rebar3_lfe` provider remains an arc3-release step.

## How we work (unchanged)

Peer frame; CC implements walking a ledger; CDC verifies independently
(re-runs/reads diffs, not summaries); implementer never marks its own work
verified; iteration cap 5/slice. Sandbox cannot mutate git — hand Duncan any
`git`/`rm`. Load erlang-guidelines (`11-anti-patterns` first).
