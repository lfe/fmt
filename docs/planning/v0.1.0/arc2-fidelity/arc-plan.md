# arc2-fidelity — plan

> The arc that turns the proven Πₑ engine into a **correct LFE formatter**:
> faithful input, meaning-preserving + idempotent + comment-preserving output,
> verified against the real LFE corpus. Successor to `arc1-poc`. Same version
> line (`v0.1.0`). Release-hardening is explicitly *out of scope* → future
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
| 1 | **faithful-reader** | lossless `form()` (+ float/char/binary/map, faithful strings) + a faithful LFE-reader bridge (reuse `lfe_io`); top-level positions; **no comments yet** | AST round-trip `read∘format ≡ read` (structural) + **0 unmodeled constructs** across the corpus |
| 2 | **comment-fidelity** | separate comment lexer + attach-by-position; thread comments through `pe_lfe` lowering so they render in place ("the clever comment slice") | every comment in input present in output on the corpus |
| 3 | **acceptance** | idempotence + semantic round-trip harness, run as the formal acceptance suite over examples + tests + cl/clj | `format∘format == format` and `read∘format ≡ read` corpus-wide |
| 4 | **width-model** (A1-R008) | decide + encode display-width policy (ASCII bytes vs Unicode grapheme/display width) | width semantics specced + tested |
| 5 | **conventions** (A1-R020) | the forms slice9 deferred for needing *new* palette styles; broaden the registry | deferred forms styled with named rules |

Reader is **two slices** (1 + 2): slice1 alone unlocks idempotence + semantic
round-trip (which don't need comments), so we get real fidelity signal before
the fiddly comment work. LFE's reader does the AST faithfully; the only thing it
loses is comments — exactly the slice2 boundary ("pull from LFE, get clever with
comments").

## Carried forward from arc1 running-recommendations

- **A1-R008** (renderer width model) → **slice4**.
- **A1-R020** (deferred LFE forms / new conventions) → **slice5**.
- **A1-R018** (newline-cost divergence from mjl, kept ours) → watch; revisit if
  acceptance output looks wrong.

## Out of scope → future arc3-release

OTP 22–29 backport (A1-R005), coverage gate, CAP strength audit, packaging /
JSR-npm-Hex publish, and **wiring the reader into the user-facing CLI /
`rebar3_lfe` provider**. These are release-hardening, not fidelity.

## The dependency-posture decision (surfaced, not silent)

A faithful reader reuses LFE's reader (`lfe_io`), today a **test-profile** dep.
The engine (`pe_doc`/`pe_cost`/`pe_mset`/`pe_resolve`/`pe_render`/`pe_measure`)
is and stays **zero runtime deps** — the reusable Πₑ library. Recommended
posture: the **LFE adapter** (`pe_lfe`, `pe_lfe_read`) is explicitly the
LFE-coupled layer and *may* depend on LFE's reader at runtime; the README's
"zero deps" claim becomes precise ("engine: zero deps; LFE front-end: uses LFE").

To avoid entangling this with the fidelity proof, **slices 1–3 stay in the test
profile** (reader in `test/`, `lfe` test-dep) — they prove fidelity via tests.
Graduating the reader to `src/` + flipping `lfe` to a runtime dep + CLI wiring
is a deliberate later step (late arc2 or arc3-release), gated on operator
confirmation per CLAUDE.md (a dependency-posture change is a methodology
decision, never a silent wrapper patch).

## How we work (unchanged)

Peer frame; CC implements walking a ledger; CDC verifies independently
(re-runs/reads diffs, not summaries); implementer never marks its own work
verified; iteration cap 5/slice. Sandbox cannot mutate git — hand Duncan any
`git`/`rm`. Load erlang-guidelines (`11-anti-patterns` first).
