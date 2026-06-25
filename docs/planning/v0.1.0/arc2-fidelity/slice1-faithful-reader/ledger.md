# arc2 / slice1: faithful reader

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A2S1-1 | `form()` += `{float,_}`,`{char,_}`,`{binary,_}`,`{map,_}`; strings stay `{str,_}`, not collapsed | code review; compile | serious | slice1 spec | planned | | |
| A2S1-2 | each new constructor renders correctly (`#\x`, `#"…"`, `#M(…)`, canonical float) | eunit golden per kind | correctness | losslessness | planned | | |
| A2S1-3 | new constructors break neither existing lowering nor slice9 registry dispatch | full eunit; registry tests | serious | regression safety | planned | | |
| A2S1-4 | `pe_lfe_read:read_file/1` converts all leaf+compound kinds to exact `form()` | eunit via `read_string/1` | correctness | reader | planned | | |
| A2S1-5 | no fallback/genericisation — unmodeled term → `{unmodeled_construct,_}` | eunit | serious | fidelity boundary | planned | | contrast slice6 `safe_*` net |
| A2S1-6 | top-level line captured from `parse_file/1` `{Sexpr,Line}` | eunit | polish | positions | planned | | |
| A2S1-7 | quote-family head atoms confirmed vs `lfe_parse`/`lfe_scan`, cited | code review | serious | correctness over guessing | planned | | |
| A2S1-8 | AST round-trip `read(format(F)) =:= F` over examples/*.lfe + test/*.lfe + cl/clj | eunit over `code:lib_dir(lfe)` | correctness | the gate | planned | | |
| A2S1-9 | 0 `unmodeled_construct` across the corpus | round-trip run | serious | completeness | planned | | |
| A2S1-10 | formatted output is valid re-readable LFE | round-trip run (re-read succeeds) | serious | validity | planned | | |
| A2S1-11 | cheap idempotence spot-check (full suite = slice3) | eunit | polish | preview | planned | | |
| A2S1-12 | `lfe` stays test-profile; engine zero-runtime-dep; no runtime flip | `rebar.config` review | serious | dep posture | planned | | runtime flip is later/operator-gated |
| A2S1-13 | zero-warning compile + xref + dialyzer clean | compile/xref/dialyzer | serious | engineering bar | planned | | |
| A2S1-14 | eunit floor green | `rebar3 eunit` | serious | engineering bar | planned | | |
| A2S1-15 | comments + intra-form spans deferred to slice2 | ledger review | correctness | deferred | planned | | re-entry: slice2 comment-fidelity |

## Amendments

_Record scope amendments here before closure._

## Caveat Checklist (fill at closure)

- New `form()` constructors added + how each renders:
- Corpus round-trip: forms passed / total; `unmodeled_construct` count (target 0):
- Any construct that forced a new palette style (named, not silent):
- Float-printing choice (and round-trip proof):
- Idempotence spot-check result:
- Deferred to slice2 (comments/spans):

## Closure

Closed at commit: _pending_.
CDC verification: _pending_.
