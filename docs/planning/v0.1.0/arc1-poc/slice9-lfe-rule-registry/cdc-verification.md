# CDC verification — arc1-poc / slice9-lfe-rule-registry

Verifier: Claude (Cowork chat seat, acting as CDC — independent of the
implementer, CC).
Date: 2026-06-24
Reviewed: **working tree (slice9 uncommitted).** `git status` ⇒ `M src/pe_lfe.erl`,
`M` slice9 docs + `running-recommendations.md`; new `priv/lfe-format-rules.eterm`,
`test/fixtures/lfe_format_baseline.eterm`, `test/pe_lfe_registry_tests.erl`.
`CHANGELOG.md` still untracked (carried from slice8).

## Verification boundary

Static CDC + a **construction proof** of the load-bearing invariant. No
OTP/Rust toolchain here, so the empirical runs (80/80 baseline, eunit 332/0,
proper 8/8, ct 2/2, xref/dialyzer) were **not re-run**; CC's clean-tree run is
the execution evidence, structure confirmed in source.

## Summary

Accept. This is a clean, behavior-preserving refactor, and behavior preservation
is verifiable **by construction** (stronger than the sampling baseline). The
hardcoded `case Head of` dispatch is now data (`priv/lfe-format-rules.eterm`) +
one closed `apply_style/6` over the existing palette; the engine is untouched;
the `catch` demonstrator proves data-only form-addition. One minor spec-keeping
finding (a stale recommendation in *my* slice-doc), fixed this turn.

## Behavior preservation — proved by construction (the gate, A1S9-8/9)

The new path is `call_form` → `maps:find(Head, Registry)` →
`apply_style(Tag, Params, Head, Args, Ctx, B)` → (miss) `generic_call`. I checked
the two tables compose to the identity on the old dispatch:

```text
rules file (form → tag)        apply_style (tag → fn)         old case Head of
  defun/defmacro → define        define     → def_form          defun → def_form ✓
  lambda         → lambda         lambda     → lambda_form       lambda → lambda_form ✓
  match-lambda/cond → clauses     clauses    → clauses_block([{sym,Head}],…)   ✓ (arg form preserved)
  let/let*       → let-binds      let-binds  → let_form          let → let_form ✓
  flet/fletrec   → flet-binds     flet-binds → flet_form         flet → flet_form ✓
  case           → subject        subject    → subject_block     case → subject_block ✓
  receive        → receive        receive    → receive_form      receive → receive_form ✓
  progn/eval-when-compile → block block      → body_block([{sym,Head}],…)      ✓ (arg form preserved)
```

Every original form reaches the **same palette function with the same
arguments**; `_Params` is ignored (`[]` today), so it cannot perturb output; the
`git diff` modifies **no** old layout-function body (only the dispatch `case` is
deleted); the `generic_call` fallback is unchanged. Therefore output is identical
for all 13 original forms, `catch` is purely additive, and everything else still
falls through to `generic_call`. Behavior preservation is structural, not
sampled.

The empirical corroboration is consistent: `test/fixtures/lfe_format_baseline.eterm`
(80 rows = 20 samples × {40,60,80,100}) is headed "captured from the **PRE-slice9**
hardcoded `call_form` dispatch" — i.e. a genuine pre-refactor baseline, not a
tautological post-refactor capture — and `behaviour_preserved_vs_baseline_test_`
asserts each row byte-identical (`?assertEqual(Expected, Bin)`). CC reports
80/80. (Provenance "pre-refactor" is a process claim I can't re-derive without
the toolchain; the construction proof carries the invariant regardless.)

## Static checks

```text
A1S9-15 scope     — only src/pe_lfe.erl changed in src/; engine pe_* untouched   ✓ (git status)
A1S9-1  rules     — priv/lfe-format-rules.eterm = exactly the 13-form dispatch + catch  ✓
A1S9-6/7 wiring   — apply_style/6 (8 closed clauses); call_form = find→apply→generic   ✓
A1S9-10 payoff    — `catch`→block is one data row; zero `catch` code in the diff        ✓
A1S9-2  atoms     — form names are strings → binary keys; tags a closed atom set
                    validated at load; no atom minted from *formatted input*            ✓
A1S9-3  fail-fast — unknown tag ⇒ load error (validated ∈ closed set)                    ✓ (test)
A1-R019/R020      — format-deviation + deferred-forms recorded in running-recommendations ✓
```

## On the format deviation (A1S9-1 / A1-R019) — CC corrected my error

My slice-doc recommended an s-expr `.lfe` file via `lfe_io` on the premise
"`lfe` is already a dep." **That premise was wrong** — `rebar.config:14` shows
`lfe` is a *test-only* dep and `src/` is deliberately dependency-free, so an
`lfe_io` loader in production `pe_lfe` would have promoted `lfe` to a prod
dependency and broken default-profile xref/dialyzer. CC correctly adapted to
`priv/lfe-format-rules.eterm` (Erlang terms via `file:consult`, pure OTP),
preserving the data content (form→tag→params, string names, atom tags) and
recording it as format-adapted (A1S9-1) + A1-R019. This is a good catch on CC's
part; the design intent ("typed term data, not functions, not JSON") is intact.
I have corrected the slice-doc's data-format section to own the bad premise
(this turn).

## Findings

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| 1 | minor | slice-doc §"The data format" still recommended s-expr/`lfe_io` (my wrong-premise recommendation) while the implementation correctly uses Erlang terms (A1-R019). | **Fixed (CDC, this turn):** added an "Adapted in implementation (A1-R019)" callout owning the premise error; the data-not-JSON reasoning retained. |

No other findings. No silent drops (the Emacs-table cross-reference names every
deferred form; A1S9-11). No engine change. No golden edited.

## Disposition

- **Code:** accept. Behavior preservation is structural (construction proof) and
  empirically corroborated (80/80, pre-refactor baseline); scope is confined to
  the knowledge layer; the `catch` demonstrator substantiates the data-only
  claim; the format deviation is sound and recorded.
- **Docs:** reconciled — the one stale section fixed this turn.
- **Not re-run here** (no toolchain): the 80/80 baseline, eunit 332/0, proper,
  ct, dialyzer. Structure confirmed in source; counts rest on CC's clean-tree run.
- **Procedural (as for slice8):** slice9 is uncommitted; `CHANGELOG.md` and both
  `cdc-verification.md` files remain untracked and need committing
  (`git commit -a` will miss the untracked ones).
