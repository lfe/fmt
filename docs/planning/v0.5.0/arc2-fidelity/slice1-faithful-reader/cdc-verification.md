# CDC verification — arc2-fidelity / slice1-faithful-reader

Verifier: Claude (Cowork chat seat, acting as CDC — independent of the
implementer, CC, which wrote the code; I authored the slice spec, which is the
normal CDC-verifies-delivery-against-spec relationship)
Date: 2026-06-25
Reviewed: working-tree state (slice1 uncommitted; closing SHA pending).

## Verification boundary

Static, evidence-based CDC: working-tree source and tests read directly; scope
checked via `GIT_OPTIONAL_LOCKS=0 git diff --name-only HEAD` (read-only, no
index lock stranded); corpus size cross-checked with an independent counter.
The build floor (eunit 351 / proper 8 / ct 2 / dialyzer / xref) was **not
re-run** here (no OTP 28 toolchain); the round-trip pass count is relied upon
from CC's run plus structural verification that the gate is correctly built.

## Summary

**Accept.** 15 rows done (2 amended), 0 silent drops. Scope is clean — the
engine is genuinely untouched (verified by diff, not mtime). The amendments
(drop `{char}`, add `{splice}`, symbol-quoting, empty-body fix) are sound and
improve fidelity over the spec I wrote. The round-trip gate is real and proves
*semantic* fidelity over the whole corpus.

## Scope (the key invariant) — verified

```text
GIT_OPTIONAL_LOCKS=0 git diff --name-only HEAD  (uncommitted slice1 changes)
  src/pe_lfe.erl
  test/pe_lfe_read.erl
  test/pe_lfe_read_tests.erl
  docs/.../slice1-faithful-reader/ledger.md
untracked: test/pe_lfe_literal_tests.erl, test/pe_lfe_roundtrip_tests.erl

  → NO engine module (pe_resolve / pe_doc / pe_mset / pe_cost / pe_render /
    pe_measure) in the diff. CC's "engine pe_* untouched" is CONFIRMED.
    (Their 06-25 mtimes are slice8's committed alignment, not slice1.)
```

## Structural evidence

```text
form() extensions (src/pe_lfe.erl)
  PASS — {float,float()}, {binary,binary()}, {map,[{form(),form()}]},
  {splice,form()} present; {char} correctly ABSENT; {str,binary()} retained.
  lower/3 clauses for binary/map/splice present.

No-fallback reader (test/pe_lfe_read.erl)
  PASS — convert/2 `Other` clause raises error({unmodeled_construct, Other})
  (line ~123); the old fallback/1 is deleted. safe_format_binary retained but
  documented + exported as bench-only latency tooling, off the faithful path.

Symbol quoting (the major correctness piece)
  PASS — render_symbol/1 + needs_quote/1 replicate lfe_io_write:quote_symbol/2
  with lfe_scan start_symbol_char/symbol_char classes, cited, kept in-tree so
  src/ stays dependency-free.

Zero-dep posture
  PASS — rebar.config `{deps, []}` unchanged; lfe stays test-profile.

Round-trip gate (test/pe_lfe_roundtrip_tests.erl)
  PASS (structure) — corpus via code:lib_dir(lfe) over examples + test + cl/clj;
  per form: format_binary -> lfe_io:read_string -> convert -> assert
  `Form =:= convert(Sexpr)`; corpus test asserts unmodeled == [] AND Ok == Forms
  AND Forms > 0. Idempotence spot-check (church.lfe): format -> reread -> format,
  assert Bin1 == Bin2. These are the right assertions.

Corpus-size cross-check (independent)
  ~869 naive top-level paren-forms across the same 34 files vs CC's 739 — same
  order of magnitude (my counter over-counts parens inside strings/comments),
  confirming the gate covers the real corpus, not a token subset.
```

## Finding — the gate proves *semantic*, not *surface*, fidelity (correct scope)

The round-trip is `convert(parse(src)) =:= convert(reread(format(...)))`. It
proves the AST is preserved. It does **not** prove *surface syntax* is
preserved, and cannot, because `lfe_io` erases two distinctions at read time:
`#\A` reads as `65` and `"abc"` reads as a char-list. So a char renders as its
int and a string is recovered by a printable-list heuristic — both round-trip
*semantically* while losing the `#\`/`"` surface form. CC disclosed this exactly
and scoped it to slice2's token layer. **This is the right boundary**, and it is
the one thing to keep visible: "739/739 round-trip" means *meaning preserved*,
not *byte-for-byte source preserved* (comments + surface syntax are slice2).

## Findings

- **F1 (positive).** The amendments are net-better than my spec: `{char}` was
  genuinely unproducible via `lfe_io`, and `{splice}` fixes a real slice6 drop
  (`,@` lost its `@`, 21× in the corpus). The round-trip gate *surfaced* two
  real fidelity bugs (symbol quoting; empty-body `(case X)` crash that slice6's
  `safe_*` net had masked) and CC drove both to zero — exactly the gate's purpose.
- **F2 (note for slice2).** Strings rely on a printable-list heuristic; a
  printable list-of-ints that was *not* a source string will be re-emitted as a
  string. Semantically equal post-read, surface-different. Slice2's token layer
  is where this (and `#\`) get true surface fidelity, if desired.

## Closure

CDC accepts arc2/slice1 at the stated scope (semantic faithful reader, no
comments/surface-syntax). Engine untouched (verified); zero-dep intact;
round-trip gate genuine; amendments sound. Build floor relied on CC's run
(noted). Recommend recording the closing SHA and proceeding to slice2
(comment-fidelity), which also owns the deferred `#\`/`"` surface syntax.
