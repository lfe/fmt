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

## slice2b (parser + CST) — ACCEPT

Reviewed commit `1d156b6`. Static, evidence-based; build floor relied on CC's
run.

### Evidence

```text
Scope — git show --stat 1d156b6
  Touched ONLY src/pe_lfe_cst.erl + test/pe_lfe_cst_tests.erl. Engine, pe_lfe
  lowering, rebar.config NOT touched; {deps,[]}; src/ adds only scan+cst. ✓

cst() structure (A2S2-6/12)
  -record(cst,{sexpr,pos,lead,trail}); exports read/1, read_forms/1,
  cst_to_sexpr/1, comments/1, positions/1, pos/lead/trail/children. Every node
  built with a pos; every_node_has_position_test. ✓

Roslyn trivia (A2S2-7/11)
  attach_trivia/1 (trailing = same end-of-line; else leading→next); hand-checked
  leading_and_trailing_test, inner_comment_leads_next_element_test,
  comment_trailing_open_paren_leads_first_test. ✓

AST differential (A2S2-9) — the 739 gate, verified for soundness
  corpus_ast_differential_test_: [cst_to_sexpr(C) || C <- read(Bin)] =:=
  lfe_io:parse_file(File) over the corpus → 739/739 forms, 33/33 files.
  #(/#M/#B/#' reader-constructors built to match lfe_io's read-evaluation;
  #'=:=/2 → [function,'=:=',2] special case tested. ✓

Comment capture (A2S2-10) — the no-loss gate
  corpus_comment_capture_test_: scanner comment count =:= length(comments(read))
  → 1826 = 1826, 0 lost; every captured comment carries a position. ✓

Floor (CC-run, clean tree): eunit 371/0, proper 8/8, ct 2/2, xref+dialyzer clean.
```

### Findings

- **F1 — `cst_to_sexpr` (not `cst_to_form`): interpretation is logically
  sound.** CC strips to the bare `lfe_io`-equivalent s-expression (keeping `src/`
  zero-dep) rather than to `pe_lfe:form()`. The claim "739 raw-AST equality ⇒
  form-level equality" is **valid by referential transparency**: slice1's
  `convert/1` is pure, so `cst_to_sexpr(read(F)) =:= lfe_io(F)` implies
  `convert(cst_to_sexpr(read(F))) =:= convert(lfe_io(F))` = slice1's `form()`.
  Accepted. **Hand-off to slice3 (named, not a gap):** 2b proves the cst's
  *structure* is faithful; slice3 must lower the cst → `form()` **with trivia**,
  applying convert-style code-vs-data shaping per node while threading each
  node's lead/trail comments — and must preserve the proven structure (that is
  slice3's own correctness obligation + gate, not inherited for free).
- **F2 — `#B` constructor is corpus-scoped (named pre-release gap).** It
  evaluates the segment kinds the corpus uses (int byte, string bytes, `(V
  float)` 64-bit) and raises `{unsupported_bitseg,_}` on richer specs (`(size
  N)`, `(unit N)`, signed, endianness) — honest let-it-crash, and the 739
  differential confirms the corpus needs no more. **But** a real user file with
  `#B((X (size 16)))` would crash the reader, so this is a genuine gap for a
  *shipping* formatter (not an arc2 blocker). Recommend tracking it on the
  arc3-release must-fix list: the production reader must handle all valid LFE,
  not only corpus LFE. Re-entry is recorded in the ledger.

### Closure (2b)

CDC accepts slice2b. Both oracles green and soundly constructed; scope clean;
zero-dep preserved; engine/lowering untouched. The `cst_to_sexpr` interpretation
is valid; the `#B` corpus-scoping is an honestly-named gap for arc3. slice2 is
complete — slice3 gets a positioned, comment-bearing `cst()` to render.
