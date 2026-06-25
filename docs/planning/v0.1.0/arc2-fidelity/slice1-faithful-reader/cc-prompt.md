# CC prompt — arc2 / slice1 — faithful reader

> For CC (implementation seat). Read `../arc-plan.md` and `slice-doc.md` first.
> Load **erlang-guidelines** (`11-anti-patterns` first, then `01-core-idioms`,
> `02-api-design`, `04-data-and-types`, `03-error-handling`, `15-testing`).
> Walk the ledger; CDC verifies independently. Iteration cap: 5.

## Goal

Make the LFE reader **faithful**: a lossless `form()` model and a reader that
turns real `.lfe` source into exact ASTs, proven by an AST round-trip over the
real corpus, with **no genericisation and no printed-text fallback**. Comments
are slice2 — out of scope here.

## Scope fence

- `src/pe_lfe.erl` — extend `form()` (+ `float`/`char`/`binary`/`map`) and add a
  lowering rule for each; faithful strings. No resolver/engine changes; no
  change to slice9 registry *semantics* (new leaf styles may need a palette
  entry — if so, record it, don't fold it silently).
- `test/pe_lfe_read.erl` — evolve slice6's bridge into the faithful reader
  (stays test-profile; `lfe` stays a test dep — do **not** flip it to a runtime
  dep, that's a later operator-gated decision per arc-plan).
- Tests in `test/`. No git safety-bypass flags. Sandbox can't mutate git — hand
  Duncan any `git`/`rm`.

## Safety / idiom notes

- **No fallback clause in the reader.** Unmodeled term → `error({unmodeled_construct, T})`.
  Let it crash; the corpus round-trip proves completeness. (Contrast slice6's
  deliberate `safe_*`/`genericize` net — that was for latency, not fidelity.)
- The reader calls LFE's reader, which interns atoms; note it in the module doc;
  add no `list_to_atom/1` of your own (use `atom_to_binary/2`).
- Spec every export; keep `warnings_as_errors`, dialyzer, xref clean.
- Float printing: pick a canonical, round-trippable rendering and state the
  choice; verify re-reading yields an equal float.

## Ledger

| ID | Criterion | Verify | Significance | Status |
|----|-----------|--------|--------------|--------|
| A2S1-1 | `form()` gains `{float,_}`, `{char,_}`, `{binary,_}` (literal), `{map,_}`; strings stay `{str,_}` and are not collapsed | code review; compile | serious | planned |
| A2S1-2 | each new constructor has a lowering rule rendering it correctly (`#\x`, `#"…"`, `#M(…)`, canonical float) | eunit golden per kind | correctness | planned |
| A2S1-3 | adding constructors breaks neither existing lowering nor slice9 registry dispatch | full eunit; registry tests green | serious | planned |
| A2S1-4 | `pe_lfe_read:read_file/1` converts atoms/ints/floats/chars/binaries/maps/tuples/strings/lists/dotted/quote-family to exact `form()` | eunit snippets via `lfe_io:read_string/1` | correctness | planned |
| A2S1-5 | **no fallback / no genericisation** — unmodeled term raises `{unmodeled_construct,_}` | eunit (feed a synthetic unmodeled term → expect error) | serious | planned |
| A2S1-6 | top-level form line captured from `lfe_io:parse_file/1` `{Sexpr,Line}` | eunit | polish | planned |
| A2S1-7 | quote-family head atoms confirmed against `lfe_parse`/`lfe_scan`, cited in a comment | code review | serious | planned |
| A2S1-8 | **AST round-trip:** every top-level form of `examples/*.lfe` + `test/*.lfe` + cl/clj.lfe survives `read → format → read` structurally equal | eunit over `code:lib_dir(lfe)` corpus | correctness | planned |
| A2S1-9 | **0 `unmodeled_construct`** across the whole corpus (completeness gate) | the round-trip run reports the count | serious | planned |
| A2S1-10 | formatted output is valid re-readable LFE (implied by A2S1-8 re-read succeeding) | round-trip run | serious | planned |
| A2S1-11 | cheap idempotence spot-check on a few forms (`format∘format == format`) — full suite is slice3 | eunit | polish | planned |
| A2S1-12 | `lfe` remains test-profile; engine stays zero-runtime-dep; no runtime-dep flip | `rebar.config` review | serious | planned |
| A2S1-13 | zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | planned |
| A2S1-14 | eunit floor green | `rebar3 eunit` | serious | planned |
| A2S1-15 | comments + intra-form spans remain explicitly deferred to slice2 | ledger review | correctness | planned |

## Steps

1. **Extend the model** (`src/pe_lfe.erl`): add the four constructors to
   `form()` + a lowering clause each; ensure faithful strings. Run the existing
   suite + slice9 registry tests to confirm no regression (A2S1-1/2/3).
2. **Faithful reader** (`test/pe_lfe_read.erl`): convert via `lfe_io:parse_file/1`
   (top-level line) and a total `convert/1` with **no fallback** — unmodeled →
   `error({unmodeled_construct,T})`. Confirm quote/comma head atoms against
   `lfe_parse` (A2S1-4..7).
3. **Round-trip gate** (new test): over the corpus via `code:lib_dir(lfe)`,
   for each top-level form assert `read(format(F)) =:= F` (structural) and count
   `unmodeled_construct` (must be 0). Add a small idempotence spot-check
   (A2S1-8..11).
4. **Gates**: compile/xref/dialyzer/eunit green; `lfe` still test-profile
   (A2S1-12..14).

## Done when

Ledger row-complete; the corpus round-trips with **0 unmodeled constructs**;
engine stays zero-dep; comments explicitly deferred. Report the corpus round-trip
pass count + any forms that needed a new palette style. This unlocks slice3's
idempotence + semantic-round-trip acceptance suite (slice2 adds comments first).
