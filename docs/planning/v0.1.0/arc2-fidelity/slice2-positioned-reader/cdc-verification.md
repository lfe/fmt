# CDC verification — arc2-fidelity / slice2-positioned-reader

Verifier: Claude (Cowork chat seat, acting as CDC — independent of the
implementer, CC)
Date: 2026-06-25

## slice2a (scanner) — ACCEPT

Reviewed: working tree (slice2a uncommitted; 2b open). Static, evidence-based —
source + tests read directly; build floor relied on CC's run (no OTP 28
toolchain here). The token differential is the load-bearing gate and I verified
*how it compares*, not just that it's green.

### Evidence

```text
Scope — GIT_OPTIONAL_LOCKS=0 git diff --name-only HEAD
  Confined to NOTICE, src/pe_lfe_scan.erl, test/pe_lfe_scan_tests.erl, ledger.
  Engine (pe_resolve/doc/mset/cost/render/measure), pe_lfe lowering, and
  rebar.config are NOT in the diff. {deps,[]} intact → src/ stays zero-dep. ✓

Provenance (A2S2-1)
  pe_lfe_scan.erl module-doc states derivation from lfe_scan (Apache-2.0, ©
  R. Virding) + documents the 3 surgical changes; repo-root NOTICE names the
  file, author, licence. ✓  (Duncan McGreggor + contributors as the fmt
  copyright holder — correct.)

Binary-based (A2S2-2)
  scan(<<$;, Rest/binary>>, …) etc. — binary pattern-matching throughout; no
  whole-source binary_to_list. Streaming {more,_} machinery dropped (full source
  up front) — sound simplification, documented; malformed → {scan_error,_}. ✓

Positions + trivia (A2S2-3/4)
  Every token is {Type, Val, {Line, Col}}; comments are {comment,{line|block,
  Text},Pos} trivia; #; is a {'#;',none,Pos} token. Tests assert exact positions
  ({1,3} etc.) and multi-line block handling. ✓

Token differential (A2S2-5) — the oracle, verified for soundness
  corpus_token_differential_test_: compares
    [mine_core(T) || T <- pe_lfe_scan:scan(Bin), element(1,T) =/= comment]
  against
    [lfe_core(T) || T <- lfe_scan:string(characters_to_list(Bin))]
  i.e. comments stripped AND positions reduced to type+value on both sides
  before =:=. This is the correct comparison (excludes our additions), so
  33/33 corpus files genuinely proves token-level faithfulness. ✓

String/char awareness (A2S2-13)
  semicolon_in_string_test, hashpipe_in_string_test,
  semicolon_char_is_not_comment_test present. ✓

Engineering floor (A2S2-14/15/16, 2a share) — clean-tree, CC-run
  eunit 362/0; xref clean; dialyzer rc=0; erlfmt-clean. (Not re-run here.)

Throughput (A2S2-17, directional, CC-reported, not a gate)
  binary ≈ 12.5 MB/s vs lfe_scan list ≈ 12.1; plus it skips the upfront
  whole-source characters_to_list. Not independently reproduced.
```

### Findings

- **F1 (positive).** The split was the right call: a token-differential-gated
  scanner is an independently-verifiable unit, and the differential is correctly
  constructed (strips trivia + positions before comparing). Banking it now is low
  risk.
- **F2 (positive).** Dropping `lfe_scan`'s continuation/streaming machinery is
  justified (whole source is always available) and the differential proves
  token equivalence on complete inputs, so no fidelity is lost.

### Closure (2a)

CDC accepts slice2a (scanner). Scope clean, attribution correct, token oracle
green and soundly compared, zero-dep preserved, engine/lowering untouched.
Engineering floor relied on CC's clean-tree run (noted). Recommend committing
2a as its own unit and proceeding to 2b as a separate diff + commit + CDC.

## slice2b (parser + CST) — PENDING

Rows A2S2-6..12 (CST, Roslyn trivia attachment, `cst_to_form/1`, the 739 AST
differential vs slice1's `lfe_io` reader, comment-capture gate) land in 2b and
will be verified when 2b closes. The scanner already emits every comment as a
trivia token (no token-level loss); 2b owns *attachment* + the capture count.
