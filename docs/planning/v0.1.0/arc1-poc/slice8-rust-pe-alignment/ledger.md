# Slice 8: alignment with Rust `pretty-expressive` (mjl)

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.
>
> Reference of record: **mjl** (`rust/mjl/pretty-expressive/src/`). Scope:
> **full** (oracle + constructors + `limit` default). `full` is the designated
> deferral valve (A1S8-9) if it exceeds budget. The slice may land as two diffs
> (8a = everything but `full`; 8b = `full`); that is expected, not a drop.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S8-1 | `pe_mset` gains a `failed`/empty variant; `merge/3` treats it as identity on both sides (`merge(failed,X)=X`, `merge(X,failed)=X`), mirroring mjl `measure.rs` `(Failed,o)=>o` | code review vs `measure.rs`; eunit on merge identity | correctness | mjl `measure.rs` | planned | | keystone for `fail` |
| A1S8-2 | `pe_doc:fail/1` added; `flatten(fail)=fail`; concat `(fail,_)\|(_,fail)=>fail`; choice `(fail,_)=>rhs`,`(_,fail)=>self` | code review vs `lib.rs`; eunit (`choice(fail,d)=d`, `concat(fail,d)` fails) | correctness | mjl `lib.rs` | planned | | |
| A1S8-3 | `fail` node resolves to the `failed` mset; a doc with no valid layout yields it | code review; eunit `pe:format` of `fail()` | correctness | seam | planned | | |
| A1S8-4 | Newline carries a flatten target; `nl/1`→`" "`, `brk/1`→`""`, `hard_nl/1`→`fail`; `flatten(hard_nl)=fail` | code review vs mjl `newline`; eunit flat-vs-broken doctest | correctness | mjl `lib.rs` | planned | | |
| A1S8-5 | `pe_doc:reset/1` + smart-ctor short-circuits; `resolve_reset` sets `I=0`; `adjust_reset` mirrors `adjust_align` | code review; eunit reproducing mjl `reset` doctest | correctness | mjl `lib.rs`/`print.rs` | planned | | |
| A1S8-6 | `pe_doc:cost/2` carrying a `pe_cost`-rep value; `cost(c,fail)=fail`; push-out arms; `resolve_cost` `combine`s `c` into each measure | code review; eunit reproducing mjl `cost` doctest (`DefaultCost(0,2)` forces taller) | correctness | mjl `lib.rs` | planned | | |
| A1S8-7 | Smart-ctor parity sweep: concat `(Text 0,_)=>rhs`,`(_,Text 0)=>self`,`(Text,Text)` merge, cost push-out; choice `fail` arms; nest/align/reset `fail\|align\|reset\|text` short-circuit + cost push-out | code review row-by-row vs mjl `BitAnd`/`BitOr`/`nest`/`align`/`reset` | serious | mjl `lib.rs` | planned | | transparent arms; oracle is the gate |
| A1S8-8 | Transparent peepholes proven output/cost-preserving (not just asserted) | PropEr: doc-with vs doc-without-peephole render-equal over random inputs | correctness | non-perturbation | planned | | guards A1S8-7 against a peephole that silently changes output |
| A1S8-9 | `pe_doc:full/1` (idempotent; `full(fail)=fail`); concat `(full,text)=>fail` ordered after `(_,text0)=>self`; general "no non-empty text after `full` on a line" enforced as in `print.rs` | code review vs `print.rs`; eunit reproducing all three mjl `full` doctests | correctness | mjl `print.rs` | planned | | **deferral valve**: if over budget → `deferred`, re-entry "port `Full` + measure-lock from `print.rs`" |
| A1S8-10 | `limit` default changed to `trunc(1.2 * Width)` in `pe.erl` `with_defaults`; explicit callers unaffected | `grep` `with_defaults`; eunit default-opts | serious | mjl `cost.rs`; operator decision 2026-06-24 | planned | | ledgered (not silent) per `CLAUDE.md` |
| A1S8-11 | `limit`-default change recorded in `running-recommendations.md` + changelog; corpus latency movement measured (slice6 path) and reported | doc diff; bench run | serious | spec | planned | | watch guard_SUITE tail under larger `W` |
| A1S8-12 | `pe_gen` extended to emit the new node types; in-BEAM `oracle_optimal` understands them | code review; `prop_resolver_optimal` covers new nodes | correctness | slice1 oracle | planned | | keeps the brute-force reference valid |
| A1S8-13 | In-BEAM oracle property green with the full algebra: resolver cost `=:=` `pe_gen:oracle_optimal` | `rebar3 proper -m prop_pe_resolve` | serious | correctness | planned | | |
| A1S8-14 | Wire format defined; one parser each side; ASCII-only; round-trips a doc over the full algebra | code review; eunit round-trip | serious | spec | planned | | |
| A1S8-15 | Rust oracle crate under `test/oracle/`, pinned mjl version, builds; CLI takes `(width, limit)`, renders via `DefaultCostFactory::new(width, Some(limit))` | `cargo build`; run on a sample | serious | spec | planned | | pin recorded (open-q 2) |
| A1S8-16 | Differential property: equal `{badness,height}` (recomputed from output strings) across width sweep over N random docs; identical output on unique-optimum docs | run `make oracle` / rebar3 alias | correctness | the alignment claim | planned | | cost canonical; text only where optimum unique |
| A1S8-17 | Oracle reachable via `make oracle` (or rebar3 alias); kept out of default `rebar3 ct` unless operator opts in | run target; inspect CI config | serious | spec | planned | | per slice-doc open-q 1 |
| A1S8-18 | `pe_cost_squared` / cost factory unchanged; mjl memo internals NOT copied | diff review | serious | non-goal guard | planned | | over-matching guard |
| A1S8-19 | No LFE knowledge-layer / `formatter-map` change | `git show --name-only`; diff confined to engine + test | serious | scope guard | planned | | engine-only slice |
| A1S8-20 | Zero-warning compile + xref + dialyzer clean (Erlang); `cargo clippy` clean (oracle crate) | compile/xref/dialyzer; clippy | serious | engineering bar | planned | | |
| A1S8-21 | eunit + PropEr + ct floor green | `rebar3 eunit`; `rebar3 proper`; `rebar3 ct` | serious | engineering bar | planned | | |
| A1S8-22 | Closing report: constructors landed; mjl-oracle result; `limit` latency movement; `full` disposition | report review | serious | methodology | planned | | |
| A1S8-23 | OTP 22–29 backport; coverage gate + CAP audit remain explicitly deferred | ledger review | serious | deferred from arc | planned | | carried arc deferrals |

## Notes on verification independence (for CDC)

- **A1S8-16 is the headline.** CDC should re-run `make oracle` (or, lacking a
  Rust toolchain, re-derive `{badness,height}` from the committed sample outputs
  with an independent recompute and confirm equality), not take CC's pass on
  trust — mirroring the slice7 CDC pass that re-parsed `frontier.csv`.
- **A1S8-9 (`full`).** If `deferred`, CDC confirms the re-entry condition is
  concrete and that rows 1–8, 10–22 stand without it (the slice is honestly
  scoped to "full algebra minus `full`").
- **A1S8-10/11 (`limit`).** Confirm the change is *recorded* (changelog +
  running-recommendations), since it alters output — a silent landing here would
  be the exact failure mode `CLAUDE.md` warns against.
