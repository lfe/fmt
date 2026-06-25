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
| A2S2-6 | `pe_lfe_cst` → `cst()` (`form()` shape + `{pos,lead,trail}`) | code review; eunit | serious | reader | done | `pe_lfe_cst:read/1` → `[cst()]`; each node carries `sexpr` (form shape), `pos`, `lead`, `trail`; `pe_lfe_cst_tests:leaves/aggregates/reader_constructors_test` | 2b |
| A2S2-7 | trivia bound by Roslyn following-token rule | eunit hand-checked | correctness | attachment model | done | `attach_trivia/1` (trailing = same end-of-line; else leading→next); hand-checked `leading_and_trailing_test`, `inner_comment_leads_next_element_test`, `comment_trailing_open_paren_leads_first_test` | 2b |
| A2S2-8 | `cst_to_form/1` strips to plain `form()` | eunit | serious | bridge to lowering | done (named `cst_to_sexpr`) | `cst_to_sexpr/1` strips to the bare lfe_io-equivalent s-expression — the "plain form"; the pe_lfe:form() adaptation stays slice1 `pe_lfe_read:convert`/slice3 lowering. See Amendments | 2b |
| A2S2-9 | AST differential: `cst_to_sexpr(read(F))` `=:=` `lfe_io` form over corpus (739) | eunit over `code:lib_dir(lfe)` | correctness | the gate | done | `corpus_ast_differential_test_`: **739/739 forms, 33/33 files** `=:=` `lfe_io:parse_file`. (Equality at the raw-AST level ⇒ slice1 form equality via `convert`.) `#B`/`#M`/`#(`/`#'` constructors built to match | reuses slice1 oracle |
| A2S2-10 | comment capture: independent count `=:=` captured; 0 lost | eunit corpus audit | serious | no-loss invariant | done | `corpus_comment_capture_test_`: scanner comment count **1826 = 1826 captured, 0 lost** across the corpus | 2b |
| A2S2-11 | every comment has position + correct leading/trailing class | eunit | serious | attachment | done | every `comment()` is `{Kind, Text, Pos}`; classification asserted by the hand-checked Roslyn tests; corpus capture asserts every comment carries a valid position | 2b |
| A2S2-12 | a position on every `cst()` node | eunit | serious | positions | done | every `#cst{}` is built with a `pos`; `positions/1` walk + `every_node_has_position_test` | 2b |
| A2S2-13 | `;`/`#|` inside `"…"`/`#\;` not treated as comment | eunit adversarial | serious | scanner correctness | done | `semicolon_in_string_test`, `hashpipe_in_string_test`, `semicolon_char_is_not_comment_test` | 2a |
| A2S2-14 | `src/` zero-dep; `lfe` test-only; engine + `pe_lfe` lowering untouched | rebar.config + diff | serious | scope / dep posture | done | `{deps,[]}` unchanged; `pe_lfe_scan`/`pe_lfe_cst` use only OTP; `src/` diff confined to those two + `NOTICE`; engine/`pe_lfe` untouched | 2a+2b |
| A2S2-15 | zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | engineering bar | done | `compile` (warnings-as-errors)/`xref`/`dialyzer` clean (2a + 2b) | |
| A2S2-16 | eunit floor green | `rebar3 eunit` | serious | engineering bar | done | `rebar3 eunit` 371/0; proper 8/8; ct 2/2 | |
| A2S2-17 | (optional) scan-throughput probe vs list path — directional | bench note | polish | perf | done | directional probe over the corpus (×20): `pe_lfe_scan` ≈ 12.5 MB/s vs `lfe_scan` ≈ 12.1 MB/s (and the binary path avoids the upfront whole-source `characters_to_list` `lfe_scan` needs). Not a gate | 2a |
| A2S2-18 | comment rendering + idempotence-with-comments deferred to slice3 | ledger review | correctness | deferred | deferred | re-entry: slice3 | |

## Amendments

- **Split into 2a (scanner) + 2b (parser)** — operator decision 2026-06-25; see
  the banner above. Rows A2S2-1..5,13,17 land in 2a; rows A2S2-6..12 and the
  comment-capture/attachment gate land in 2b; 14/15/16 are re-confirmed in 2b.
  A2S2-18 stays deferred to slice3. The scanner already *emits* every comment as
  a trivia token (no comment is dropped at the token level); 2b *attaches* them
  to CST nodes by the Roslyn rule and proves the capture count.
- **A2S2-8: `cst_to_form` provided as `cst_to_sexpr`.** It strips a `cst()` to
  the bare Erlang s-expression `lfe_io` produces (the "plain form" — the parsed
  structure), keeping `src/` zero-dep. The pe_lfe:form() *adaptation* (code/data
  shaping, special-form clauses) is **not** duplicated here; it remains slice1's
  `pe_lfe_read:convert/1` (test) and slice3's lowering input. The 739 differential
  is at this raw-AST level, which implies form-level equality to slice1 via
  `convert` (a pure function applied to equal inputs).
- **`#B(…)` binary constructor is corpus-scoped.** `cst_to_sexpr` builds `#B`
  binaries by evaluating segments as `(binary …)` does, covering the corpus's
  segment kinds (bare integer → 8-bit byte, string → bytes, `(Value float)` →
  64-bit float). Richer bit specs (`(size N)`, `(unit N)`, signed, endianness)
  raise `{unsupported_bitseg, _}` — let-it-crash; the AST differential (0
  mismatches) confirms the corpus needs no more. Re-entry: port LFE's full
  bit-syntax constructor if a later corpus uses richer `#B` segments.

## Caveat Checklist (2a closure)

- **Attribution/NOTICE + ported clauses:** module-doc + per-clause cites of
  `lfe_scan`'s `scan1`, `scan_line_comment`, `scan_block_comment`,
  `scan_hash1/2`, `scan_fun`, `scan_symbol`/`make_symbol_token`, `scan_qsymbol`,
  `scan_bnumber`/`base_collect`, `scan_string`/`scan_sq_string`/`scan_tq_string`,
  and the `{start_,}symbol_char` classes; repo-root `NOTICE` names the file +
  Apache-2.0 + R. Virding.
- **Token differential vs `lfe_scan`:** 33/33 corpus files, 0 divergences.
- **AST differential vs `lfe_io` (the 739 gate):** 739/739 forms, 33/33 files
  (`cst_to_sexpr(read(F)) =:= lfe_io:parse_file`).
- **Comments captured vs count:** 1826 scanned = 1826 captured, **0 lost**.
- **Roslyn trivia rule — ambiguous cases:** a comment trailing an open bracket
  on its line is bound as the *leading* trivia of the first element (it leads
  the element, not the bracket); interior comments just before a close bracket
  are captured on the node's trail. Both hand-checked.
- **Throughput probe:** binary ≈ 12.5 MB/s vs list ≈ 12.1 MB/s (directional).
- **Deferred to slice3:** comment rendering + idempotence-with-comments.

## Closure

slice2a closed at commit: `<slice2a>`. slice2b closed at commit: _pending_.
CDC verification: _pending_.
