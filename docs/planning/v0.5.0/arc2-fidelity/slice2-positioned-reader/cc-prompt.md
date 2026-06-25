# CC prompt — arc2 / slice2 — positioned reader (adapt `lfe_scan`)

> For CC (implementation seat). Read `../arc-plan.md` and `slice-doc.md` first.
> Load **erlang-guidelines** (`11-anti-patterns` first, then `01-core-idioms`,
> `04-data-and-types`, `05-functions`, `10-performance` for the binary-scan
> reasoning, `15-testing`). Walk the ledger; CDC verifies independently.
> Iteration cap: 5. This is a substantial slice — if the scanner adaptation
> balloons past one mergeable diff, stop and propose a split rather than
> overrun.

## Goal

Build our own **positioned, comment-preserving LFE reader** by adapting
`lfe_scan` (Apache-2.0), validated by two differential oracles (`lfe_scan` for
tokens, slice1's `lfe_io` reader for the AST). Keep `src/` zero-dep. Do **not**
render comments yet (slice3) and do **not** touch `pe_lfe` lowering or the
engine.

## Provenance / licensing (do this first, explicitly)

`lfe_scan.erl` is Apache-2.0, © Robert Virding. Adapt it with: a header comment
in `pe_lfe_scan.erl` stating it is derived from LFE's `lfe_scan` (Apache-2.0,
attribution to Robert Virding), and a `NOTICE` entry at repo root. Do not copy
without attribution.

## Scope fence

- New: `src/pe_lfe_scan.erl`, `src/pe_lfe_cst.erl`, `test/pe_lfe_scan_tests.erl`,
  `test/pe_lfe_cst_tests.erl`, a corpus differential test, `NOTICE`.
- **No** change to `src/pe_lfe.erl` lowering, the engine (`pe_*`), or
  `rebar.config` `{deps,[]}`. `lfe` stays test-profile (the oracle).
- No git safety-bypass flags. Sandbox can't mutate git — hand Duncan any `git`.

## Safety / idiom notes

- **Binary-based scanning:** operate on the source `binary()` with binary
  pattern matching + sub-binaries (no `binary_to_list` of the whole source). Per
  the efficiency guide, keep the match context alive (avoid forcing copies).
- **Let it crash:** a malformed token raises a clear error (`{scan_error, …}` /
  `{parse_error, …}`); no silent recovery (this is a faithful reader).
- Spec every export; `warnings_as_errors`, dialyzer, xref clean.
- Don't reinvent the surface grammar — **port `lfe_scan`'s clauses**, changing
  representation (binary) and adding (col-keeping, comment-emitting). Cite the
  `lfe_scan` clause each non-obvious piece derives from.

## Ledger

| ID | Criterion | Verify | Significance | Status |
|----|-----------|--------|--------------|--------|
| A2S2-1 | `pe_lfe_scan` derived from `lfe_scan` with Apache-2.0 attribution header + repo `NOTICE` | code review | serious | planned |
| A2S2-2 | scanner is binary-based (consumes `binary()`, binary pattern-matching; no whole-source `binary_to_list`) | code review | serious | planned |
| A2S2-3 | every token carries line **and** column | eunit on snippets | correctness | planned |
| A2S2-4 | `;` line + `#|…|#` block comments emitted as **trivia tokens** (not skipped); `#;` datum handled | eunit per kind | serious | planned |
| A2S2-5 | **token differential:** `pe_lfe_scan` non-trivia tokens (values) `=:=` `lfe_scan` tokens over examples+test+cl/clj | eunit corpus diff vs `lfe_scan` | correctness | planned |
| A2S2-6 | `pe_lfe_cst` parses tokens → `cst()`: `form()` shape + `{pos, lead, trail}` per node | code review; eunit | serious | planned |
| A2S2-7 | trivia bound by the **Roslyn following-token rule** (trailing = through EOL; leading = bound to next token); node trivia = boundary-token trivia | eunit with hand-checked leading/trailing cases | correctness | planned |
| A2S2-8 | `pe_lfe_cst:cst_to_form/1` strips to a plain `form()` | eunit | serious | planned |
| A2S2-9 | **AST differential (the 739 gate):** `cst_to_form(read(F))` `=:=` slice1 `lfe_io` reader `form()` for every top-level form of the corpus | eunit over `code:lib_dir(lfe)` | correctness | planned |
| A2S2-10 | **comment capture:** an independent comment count over the corpus `=:=` the count of trivia comments captured; **0 comments lost** | eunit corpus audit | serious | planned |
| A2S2-11 | every captured comment has a position + a correct leading/trailing classification | eunit (re-derive expected from positions) | serious | planned |
| A2S2-12 | a position on every `cst()` node | eunit | serious | planned |
| A2S2-13 | string/char-literal awareness — a `;` or `#|` inside `"…"`/`#\;` is **not** a comment | eunit adversarial cases | serious | planned |
| A2S2-14 | `src/` stays zero-dep; `lfe` test-only; engine + `pe_lfe` lowering untouched | `rebar.config` + diff review | serious | planned |
| A2S2-15 | zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | planned |
| A2S2-16 | eunit floor green | `rebar3 eunit` | serious | planned |
| A2S2-17 | (optional) a quick scan-throughput probe vs the `lfe_io`/list path — directional only, not a gate | bench note | polish | planned |
| A2S2-18 | rendering comments + idempotence-with-comments remain deferred to slice3 | ledger review | correctness | planned |

## Steps

1. **Attribution + `pe_lfe_scan`:** port `lfe_scan`'s scanning clauses to a
   binary-based scanner that keeps `{line,col}` and emits comment trivia tokens.
   Header attribution + `NOTICE`. Token-differential test vs `lfe_scan` (A2S2-1..5).
2. **`pe_lfe_cst`:** recursive-descent over the tokens → `cst()` with per-node
   `{pos,lead,trail}` under the Roslyn rule; `cst_to_form/1` strip (A2S2-6..8).
3. **Differential + capture gates:** AST differential vs slice1's reader (739),
   comment-capture audit (0 lost), position-on-every-node, string/char awareness
   (A2S2-9..13).
4. **Gates:** zero-dep + untouched lowering/engine; compile/xref/dialyzer/eunit
   (A2S2-14..16). Optional throughput probe (A2S2-17).

## Done when

Ledger row-complete; both differentials green (tokens vs `lfe_scan`, AST 739 vs
slice1); **0 comments lost** with positions + Roslyn classification; `src/`
zero-dep; lowering/engine untouched. Report the corpus comment count captured +
the AST-differential pass count. This hands slice3 a positioned, comment-bearing
`cst()` to render.
