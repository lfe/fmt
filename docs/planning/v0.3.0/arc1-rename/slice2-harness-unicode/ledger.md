# Slice 2: harness-unicode — ledger

> Per-slice verification ledger. CC implements + self-assesses; CDC verifies
> independently. Implementer never marks its own rows CDC-verified. Iteration
> cap: 5. Project `v0.3.0` · arc `arc1-rename` · slice `slice2-harness-unicode`.
> Toolchain rows reconcile via **CI** (no OTP in the CDC sandbox).

## Ledger

> CC self-assessment. Base `e469d0f` (slice-1 tip); fix commit `d70d8b1`; branch
> `feature/v0.3.0-namespace` (worktree `../fmt-v0.3.0-namespace`). Toolchain rows
> run locally (OTP 28) and "CI reconciles". Every `done` is **proposed-done**
> until CDC reproduces.

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S2-1 | the inline oracle helpers flatten formatter output with `unicode:characters_to_binary` (not `iolist_to_binary`), handling its return contract | inspect the helpers; `grep iolist_to_binary` in the oracle path → gone/justified | serious | slice-doc | done | New `fmt_output_bin/1` = `unicode:characters_to_binary(IO, unicode, utf8)` guarded to a `binary()` (else `error({formatter_output_not_unicode,…})`). Used in **all four** corpus-fed inline oracles — `assert_idempotent` (×2), `assert_token_preservation`, `assert_ast_equiv`, `assert_comment_preservation` (Amendment 1). No `iolist_to_binary` on formatter output remains in the oracle path; the input-side `iolist_to_binary([Input])` stays (genuine source binary, justified + commented). | the root-cause fix |
| A1S2-2 | `is_seven_bit_ascii` restriction removed from `full_corpus/0`; helper deleted if unused | `grep -rn is_seven_bit_ascii test` → empty | serious | slice-doc | done | Filter removed from `full_corpus/0` (now `{ok,B} -> {true,B}`); `is_seven_bit_ascii/1` deleted. `grep -rn is_seven_bit_ascii test` → **empty**. | v0.1.0 stopgap gone |
| A1S2-3 | the 2 multibyte files (`core-macros.lfe`, `clj-tests.lfe`) pass the inline oracles; inline-oracle input count = full corpus | `ct:log` input count (now incl. the 2 files); ct green | correctness | slice-doc | done | `ct:log`: **"Oracle 1 (idempotency) over 84 inputs"**, token/comment/AST likewise **84** (was 82). The +2 are the multibyte files; all four oracles pass → ct green. | excluded → included |
| A1S2-4 | full `rebar3 ct` green | `rebar3 ct` | serious | engineering bar | done | `rebar3 ct` → **All 274 tests passed** (first run failed `oracle_comment_preservation` → surfaced Amendment 1; green after). | also CI reconciles |
| A1S2-5 | `rebar3 compile` zero-warning; `xref` + `dialyzer` clean | `rebar3 compile`/`xref`/`dialyzer` | serious | engineering bar | done | `compile` zero-warning; `xref` exit 0; `dialyzer` exit 0 (20 files). | also CI reconciles |
| A1S2-6 | diff confined to `test/lfmt_fezzik_SUITE.erl`; engine `lfmt_fezzik.erl` + other modules untouched | `git diff --name-only <base>..HEAD` → only the suite | serious | scope control | done | `git diff --name-only e469d0f..HEAD` → **`test/lfmt_fezzik_SUITE.erl`** only. | no engine change |
| A1S2-7 | `pe_*` + `docs/planning/v0.5.0/` untouched | `git diff <base>..HEAD -- 'src/pe_*.erl' docs/planning/v0.5.0` → empty | serious | scope control | done | `git diff --stat e469d0f..HEAD -- src/lfmt_fezzik.erl 'src/pe_*.erl' docs/planning/v0.5.0` → **empty**. | engine also untouched |
| A1S2-8 | closing report: inline-oracle count + the carried-finding-closed statement | closing-report check | serious | methodology | done | `closing-report.md`: input count 82→84; the carried v0.1.0 Unicode-harness finding stated **closed**. | closes the v0.1.0 carry-out |

## Amendments (CC-raised refinements)

1. **A fourth inline oracle helper needed the same fix.** The prompt's fix step
   named three helpers (`assert_idempotent`, `assert_token_preservation`,
   `assert_ast_equiv`), but `assert_comment_preservation` is also fed by
   `full_corpus/0` and flattened formatter output with `iolist_to_binary`
   (line ~1137: `OutBin = iolist_to_binary(OutIO)`, then re-lexed). With the ASCII
   restriction removed, it failed on the multibyte files (the first `ct` run:
   `oracle_comment_preservation FAILED`). The prompt's **purpose** ("make the
   inline oracle helpers Unicode-safe … no ASCII carve-out") and gate A1S2-4
   (ct green) both require fixing it; it is the identical test-harness fix
   (`iolist_to_binary` → `fmt_output_bin`). Applied; disclosed here rather than
   silently extending the named scope.

## Caveats

- Other `iolist_to_binary(OutIO)` calls remain in the suite (e.g. `assert_format`
  and specific `indent_*`/edge tests). Those are **not** corpus-fed inline
  oracles — their inputs are hardcoded ASCII literals — so `iolist_to_binary` is
  correct there. Only the four `full_corpus`-fed oracles needed the unicode flatten.
- `fmt_output_bin/1` uses the explicit `(IO, unicode, utf8)` arity, matching the
  already-proven sweep path (`corpus_sweep_all`/`conf_wide_sweep`), and asserts a
  `binary()` result so a malformed `{error,_}`/`{incomplete,_}` fails loudly.
- Toolchain rows run locally on OTP 28; "CI reconciles" per the arc plan.

## What Worked

- **Letting the removed restriction surface the hidden fourth helper.** Dropping
  `is_seven_bit_ascii` and running ct immediately exposed `oracle_comment_preservation`
  as a same-class bug the prompt's enumeration missed — caught by the gate, not by
  guesswork.

## Closure

Self-assessed complete at commit `d70d8b1` (base `e469d0f`). Total rows: **8**.
Done: **8**. Deferred: **0**. No-op: **0**. CC self-assessment only — **CDC
verification pending** (`cdc-verification.md`). **Last slice of `arc1-rename`** →
its close feeds the arc close (`arc1-rename/closing-report.md` + composition
check + the `0.3.0` tag) and the v0.3.0 project close. CC did **not** create the
`0.3.0` tag or close the arc (that is the arc-close step).
