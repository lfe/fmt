# arc2 / slice2: positioned reader (adapt `lfe_scan`)

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A2S2-1 | `pe_lfe_scan` derived from `lfe_scan` with Apache-2.0 attribution + repo `NOTICE` | code review | serious | licensing | planned | | |
| A2S2-2 | scanner is binary-based (no whole-source `binary_to_list`) | code review | serious | perf/modern idiom | planned | | |
| A2S2-3 | every token carries line + column | eunit | correctness | positions | planned | | |
| A2S2-4 | `;` + `#|…|#` emitted as trivia tokens; `#;` datum handled | eunit per kind | serious | comment capture | planned | | |
| A2S2-5 | token differential: scanner tokens `=:=` `lfe_scan` over corpus | eunit | correctness | scanner oracle | planned | | |
| A2S2-6 | `pe_lfe_cst` → `cst()` (`form()` shape + `{pos,lead,trail}`) | code review; eunit | serious | reader | planned | | |
| A2S2-7 | trivia bound by Roslyn following-token rule | eunit hand-checked | correctness | attachment model | planned | | |
| A2S2-8 | `cst_to_form/1` strips to plain `form()` | eunit | serious | bridge to lowering | planned | | |
| A2S2-9 | AST differential: `cst_to_form(read(F))` `=:=` slice1 `lfe_io` form over corpus (739) | eunit over `code:lib_dir(lfe)` | correctness | the gate | planned | | reuses slice1 oracle |
| A2S2-10 | comment capture: independent count `=:=` captured; 0 lost | eunit corpus audit | serious | no-loss invariant | planned | | |
| A2S2-11 | every comment has position + correct leading/trailing class | eunit | serious | attachment | planned | | |
| A2S2-12 | a position on every `cst()` node | eunit | serious | positions | planned | | |
| A2S2-13 | `;`/`#|` inside `"…"`/`#\;` not treated as comment | eunit adversarial | serious | scanner correctness | planned | | |
| A2S2-14 | `src/` zero-dep; `lfe` test-only; engine + `pe_lfe` lowering untouched | rebar.config + diff | serious | scope / dep posture | planned | | |
| A2S2-15 | zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | engineering bar | planned | | |
| A2S2-16 | eunit floor green | `rebar3 eunit` | serious | engineering bar | planned | | |
| A2S2-17 | (optional) scan-throughput probe vs list path — directional | bench note | polish | perf | planned | | not a gate |
| A2S2-18 | comment rendering + idempotence-with-comments deferred to slice3 | ledger review | correctness | deferred | planned | | re-entry: slice3 |

## Amendments

_Record scope amendments here before closure._

## Caveat Checklist (fill at closure)

- Attribution/NOTICE wording + which `lfe_scan` clauses were ported:
- Token differential vs `lfe_scan`: pass count / any divergences:
- AST differential vs slice1 reader: forms passed / total (target 739/739):
- Comments captured vs independent count (0 lost?):
- Roslyn trivia rule — any ambiguous leading/trailing cases + how resolved:
- Binary-scan throughput probe (if run; directional only):
- Deferred to slice3 (render + idempotence-with-comments):

## Closure

Closed at commit: _pending_.
CDC verification: _pending_.
