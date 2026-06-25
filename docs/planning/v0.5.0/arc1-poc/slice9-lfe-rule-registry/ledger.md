# Slice 9: declarative LFE rule registry

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently against commit state. Iteration cap: 5. Final status for every
> row is one of `done` / `deferred` / `no-op`; `planned` is not final.
>
> Load-bearing invariant: **behavior preservation.** The seed data encodes
> today's dispatch exactly; all slice3 goldens pass byte-identically. This is a
> refactor + extensibility slice, not a conventions change. Knowledge-layer only
> (`pe_lfe` + `priv/`); the engine (`pe_*`) is untouched.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S9-1 | Rules data file exists, seeded with exactly today's 13 form→style mappings (+ the A1S9-10 demonstrator) | code review; read the file | serious | slice9 spec | done (format adapted) | `priv/lfe-format-rules.eterm`: `{rules_version,1}` + 13 behaviour-preserving `{rule,Name,Tag,Params}` rows + `catch` demonstrator. **Format adapted s-expr→Erlang-terms** (operator 2026-06-24): `lfe` is test-only, so an s-expr/`lfe_io` loader in `src/` would break the dependency-free invariant; content (form→tag→params, string names, atom tags) unchanged | form names as strings |
| A1S9-2 | Loader reads the file from `code:priv_dir(fmt)` into `#{FormBin => {Tag, Params}}`; form-name strings → binary keys with no atom minting from formatted input | code review; eunit load test; grep for `binary_to_atom`/`list_to_atom` on input path | serious | slice3 A1S3-2 | done | `pe_lfe:read_rules/1` (`file:consult` + `parse_rules`), `load_rules/0` (cached); `base_registry_loads_with_binary_keys_test` asserts all keys `is_binary`; no `*_to_atom` on a form name (names via `list_to_binary`) | rules file = trusted config (distinct from input) |
| A1S9-3 | Loader rejects an unknown style tag at load (error, not silent skip) | eunit: malformed-row load raises | correctness | fail-fast | done | `parse_rules` validates `Tag` ∈ closed `?STYLE_TAGS`; `unknown_style_tag_is_load_error_test` (`error({unknown_style_tag,…})`) + `malformed_rule_is_load_error_test` | |
| A1S9-4 | Optional user overlay merges over the base (overlay wins per form); base unchanged when no overlay | eunit overlay test | serious | raco compose parity | done | `load_rules/1` = `maps:merge(base, Overlay)`; `overlay_wins_and_base_preserved_test` (override + add + base preserved) | |
| A1S9-5 | Registry threaded through `ctx()` at `to_doc/2` entry; caller may supply a custom registry; no global mutable source of truth | code review; eunit inject-registry test | serious | testability / no global state | done | `to_doc/2` builds `ctx() = #{indent, registry => maps:get(registry, Opts, load_rules())}`; `custom_registry_changes_dispatch_test` (empty registry → `catch` generic). `persistent_term` is a read-only cache of the base only, never the source of truth | |
| A1S9-6 | Each palette layout fn has a stable tag reached through one closed `apply_style/6`; `define lambda clauses let-binds flet-binds subject receive block` all routed | code review | serious | slice9 spec | done | `pe_lfe:apply_style/6` — 8 clauses, one per tag, each routing to its existing palette fn; `-spec apply_style(style_tag(),…)` | |
| A1S9-7 | `call_form/4` rewired: registry-lookup → `apply_style` → `generic_call` fallback; the `case Head of` table is gone | code review; diff | serious | the refactor | done | `call_form/4` = `maps:find(Head, Registry)` → `{ok,{Tag,Params}}`→`apply_style` / `error`→`generic_call`; the 13-arm `case Head of` is deleted | |
| A1S9-8 | **Behavior preservation:** all 20 `pe_lfe_samples` render byte-identically vs the pre-slice path, across the width sweep | PropEr/eunit equivalence vs committed baseline outputs | correctness | the gate | done | `test/fixtures/lfe_format_baseline.eterm` (80 rows = 20 samples × {40,60,80,100}, captured from the pre-refactor tree); `pe_lfe_registry_tests:behaviour_preserved_vs_baseline_test_` asserts each byte-identical — **80/80** | slice7-style invariance |
| A1S9-9 | Every slice3 golden passes unchanged (Ackermann exact, `let_vertical`, `case/receive/cond_vertical`, `eval_when_compile_block`, `lfe_07` indent fix) | `rebar3 eunit` (slice3 suites) | correctness | regression | done | `rebar3 eunit` 332/0 (slice3 suites incl.); no golden edited | goldens not edited |
| A1S9-10 | Adding a form that fits an existing style is **data-only**: the demonstrator form is added via a rules row + golden, with **no new palette code** | diff (priv only + one test); golden green | serious | the payoff | done | `catch` → `block`: one `{rule,"catch",block,[]}` row + `catch_demonstrator_golden_test`; **zero `pe_lfe` layout-code change** (the diff for the rule is `priv/` only). Flat `(catch (foo x) (bar y))` @80; 2-indent block @10 | |
| A1S9-11 | Provenance: every `lfe-indent.el` `define-lfe-indent` form is a rule row or a documented `application`/deferred entry | cross-reference table in report | serious | provenance / no silent drop | done | Full cross-reference table in slice-doc closing report (LFE 2.1.2): 9 covered, `:`/`call`/`after` application, the rest named-deferred (need new styles); none silently dropped | deferred forms = needing new styles, named |
| A1S9-12 | Data file schema is open (params a list/map, not fixed positional) so a future per-style knob does not require a format break | code review | serious | maintainability hedge | done | `{rule, Name, Tag, Params}` carries `Params` as an open list (empty today); `apply_style/6` takes `Params` through; `style_tag()`/`registry()` types exported | |
| A1S9-13 | (Optional) JSON derive escript emits `[{form,style,params}]` from the source + round-trips | run escript; round-trip eunit | polish | operator "maybe" | no-op | not built — no Rust/non-BEAM consumer exists (slice8's oracle checks the rules-free engine). Format kept flat/typed so a ~20-line derive is cheap when a consumer appears; re-entry recorded in closing report | no-op-able: "no consumer yet" |
| A1S9-14 | `pe_lfe` public surface unchanged (`to_doc/1,2`, `format/2`, `format_binary/2`); specs intact | code review; `rebar3 dialyzer` | serious | API stability | done | the 4 public fns unchanged (only `load_rules/0,1`+`read_rules/1` added — expansion); `rebar3 dialyzer` clean | |
| A1S9-15 | Engine (`pe_doc`/`pe_resolve`/`pe_*`) untouched | `git show --name-only`; diff confined to `pe_lfe` + `priv/` + tests | serious | scope guard | done | `git status` ⇒ only `src/pe_lfe.erl` changed in `src/`; new files `priv/lfe-format-rules.eterm`, `test/fixtures/`, `test/pe_lfe_registry_tests.erl`; no `pe_*` engine change | knowledge-layer-only slice |
| A1S9-16 | Zero-warning compile + xref + dialyzer clean | `rebar3 compile`; `rebar3 xref`; `rebar3 dialyzer` | serious | engineering bar | done | `rebar3 compile` (warnings-as-errors) clean; `rebar3 xref` clean; `rebar3 dialyzer` rc=0, no warnings | |
| A1S9-17 | eunit + PropEr + ct floor green | `rebar3 eunit`; `rebar3 proper`; `rebar3 ct` | serious | engineering bar | done | eunit 332/0; proper 8/8; ct 2/2 | |
| A1S9-18 | Closing report: registry wired; behavior-identical evidence; Emacs provenance (covered vs deferred); demonstrator; derive disposition | report review | serious | methodology | done | slice-doc closing-report section (above) | |
| A1S9-19 | OTP 22–29 backport; coverage gate + CAP audit remain explicitly deferred | ledger review | serious | deferred from arc | deferred | carried arc deferrals — untouched by slice9 | carried arc deferrals |

## Notes for CDC

- **A1S9-8/9 are the gate.** Verify behavior preservation *independently* — re-run
  the slice3 suites against the slice9 commit and diff rendered bytes for the 20
  samples, rather than trusting CC's pass. A registry that changes any golden is
  a slice failure, not a convention improvement (conventions are a separate
  slice).
- **A1S9-10 is the payoff claim.** Confirm the demonstrator's diff is genuinely
  `priv/` + one test only — *zero* `pe_lfe` layout-code change. If a palette
  function was touched to make the demonstrator work, the "data-only" claim is
  not met.
- **A1S9-11 provenance.** Check the deferred forms are *named with reasons*
  (need a new style), not quietly absent — this is the silent-drop failure mode.
- **A1S9-2 atom discipline.** Confirm no atom is minted from *formatted input*;
  the rules file reading atoms for tags (closed config set) is acceptable and
  should be documented as a distinct category.
