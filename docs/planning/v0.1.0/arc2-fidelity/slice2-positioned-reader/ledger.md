# arc2 / slice2: positioned reader (adapt `lfe_scan`)

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

> **Split (operator decision 2026-06-25): slice2a = scanner (this diff); slice2b
> = parser.** The CST half needs a full LFE binary-segment constructor to match
> `lfe_io`'s `#b(…)` read-evaluation (the corpus has `#b("…")`, `#b((5.0 float)…)`,
> `#b((1 (size 16)))`) plus the recursive-descent parser, Roslyn trivia, and the
> 739/capture gates — a substantial second module. Per the cc-prompt's anti-
> overrun guidance, the scanner lands first as an independently-oracle'd unit.

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A2S2-1 | `pe_lfe_scan` derived from `lfe_scan` with Apache-2.0 attribution + repo `NOTICE` | code review | serious | licensing | done | `pe_lfe_scan.erl` module-doc cites `lfe_scan` (Apache-2.0, R. Virding) + per-clause attributions; repo-root `NOTICE` | 2a |
| A2S2-2 | scanner is binary-based (no whole-source `binary_to_list`) | code review | serious | perf/modern idiom | done | `scan(binary())` with binary patterns + sub-binary length-then-slice (`take_symbol`/`take_digits`/`scan_line_comment`); no whole-source list conversion | 2a |
| A2S2-3 | every token carries line + column | eunit | correctness | positions | done | every token is `{Type, Val, {Line, Col}}`; `pe_lfe_scan_tests:positions_test` (hand-checked multi-line) | 2a |
| A2S2-4 | `;` + `#|…|#` emitted as trivia tokens; `#;` datum handled | eunit per kind | serious | comment capture | done | `{comment, {line\|block, Text}, Pos}` trivia; `#;` is a `{'#;', none, Pos}` token; `line_comment_test`/`block_comment_test`/`block_comment_multiline_test`/`datum_comment_is_token_test` | 2a |
| A2S2-5 | token differential: scanner tokens `=:=` `lfe_scan` over corpus | eunit | correctness | scanner oracle | done | `corpus_token_differential_test_`: non-trivia token values `=:=` `lfe_scan` over **33/33** corpus files | 2a |
| A2S2-6 | `pe_lfe_cst` → `cst()` (`form()` shape + `{pos,lead,trail}`) | code review; eunit | serious | reader | deferred | slice2b | |
| A2S2-7 | trivia bound by Roslyn following-token rule | eunit hand-checked | correctness | attachment model | deferred | slice2b | |
| A2S2-8 | `cst_to_form/1` strips to plain `form()` | eunit | serious | bridge to lowering | deferred | slice2b | |
| A2S2-9 | AST differential: `cst_to_form(read(F))` `=:=` slice1 `lfe_io` form over corpus (739) | eunit over `code:lib_dir(lfe)` | correctness | the gate | deferred | slice2b — needs the `#b/#M/#(` constructor | reuses slice1 oracle |
| A2S2-10 | comment capture: independent count `=:=` captured; 0 lost | eunit corpus audit | serious | no-loss invariant | deferred | slice2b (scanner already emits all comments as trivia; the capture+attachment gate is the parser's) | |
| A2S2-11 | every comment has position + correct leading/trailing class | eunit | serious | attachment | deferred | slice2b | |
| A2S2-12 | a position on every `cst()` node | eunit | serious | positions | deferred | slice2b | |
| A2S2-13 | `;`/`#|` inside `"…"`/`#\;` not treated as comment | eunit adversarial | serious | scanner correctness | done | `semicolon_in_string_test`, `hashpipe_in_string_test`, `semicolon_char_is_not_comment_test` | 2a |
| A2S2-14 | `src/` zero-dep; `lfe` test-only; engine + `pe_lfe` lowering untouched | rebar.config + diff | serious | scope / dep posture | done (2a) | `{deps,[]}` unchanged; `pe_lfe_scan` uses only OTP; diff confined to `src/pe_lfe_scan.erl` + `NOTICE` + tests; engine/`pe_lfe` untouched | re-confirmed in 2b |
| A2S2-15 | zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | engineering bar | done (2a) | `compile` (warnings-as-errors)/`xref`/`dialyzer` clean | re-confirmed in 2b |
| A2S2-16 | eunit floor green | `rebar3 eunit` | serious | engineering bar | done (2a) | `rebar3 eunit` 362/0 | re-confirmed in 2b |
| A2S2-17 | (optional) scan-throughput probe vs list path — directional | bench note | polish | perf | done | directional probe over the corpus (×20): `pe_lfe_scan` ≈ 12.5 MB/s vs `lfe_scan` ≈ 12.1 MB/s (and the binary path avoids the upfront whole-source `characters_to_list` `lfe_scan` needs). Not a gate | 2a |
| A2S2-18 | comment rendering + idempotence-with-comments deferred to slice3 | ledger review | correctness | deferred | deferred | re-entry: slice3 | |

## Amendments

- **Split into 2a (scanner) + 2b (parser)** — operator decision 2026-06-25; see
  the banner above. Rows A2S2-1..5,13,17 and the 2a share of 14/15/16 land in
  2a; rows A2S2-6..12 and the comment-capture/attachment gate land in 2b. A2S2-18
  stays deferred to slice3. The scanner already *emits* every comment as a trivia
  token (no comment is dropped at the token level); 2b's job is to *attach* them
  to CST nodes by the Roslyn rule and prove the capture count.

## Caveat Checklist (2a closure)

- **Attribution/NOTICE + ported clauses:** module-doc + per-clause cites of
  `lfe_scan`'s `scan1`, `scan_line_comment`, `scan_block_comment`,
  `scan_hash1/2`, `scan_fun`, `scan_symbol`/`make_symbol_token`, `scan_qsymbol`,
  `scan_bnumber`/`base_collect`, `scan_string`/`scan_sq_string`/`scan_tq_string`,
  and the `{start_,}symbol_char` classes; repo-root `NOTICE` names the file +
  Apache-2.0 + R. Virding.
- **Token differential vs `lfe_scan`:** 33/33 corpus files, 0 divergences.
- **AST differential vs slice1:** slice2b.
- **Comments captured vs count:** scanner emits all `;`/`#|` as trivia; the
  count gate is slice2b.
- **Roslyn trivia rule:** slice2b.
- **Throughput probe:** binary ≈ 12.5 MB/s vs list ≈ 12.1 MB/s (directional).
- **Deferred to slice3:** comment rendering + idempotence-with-comments.

## Closure

slice2a closed at commit: _pending_. slice2b: _open_.
CDC verification: _pending_.
