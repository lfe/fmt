# CC prompt — fmt v0.3.0 · arc1-rename / slice2-harness-unicode

You are CC. Close the carried v0.1.0 finding: make `lfmt_fezzik_SUITE`'s inline
oracle helpers Unicode-safe so the two multibyte corpus files no longer need
excluding, and remove the ASCII stopgap. **Test-harness only — no engine
change.** You run `git` + the toolchain directly.

Target OTP 28. Load **collaboration-framework** (ledger discipline) and
**erlang-guidelines**.

## Read first

- `docs/planning/v0.3.0/arc1-rename/arc-plan.md` (slice 2 row + arc-ledger).
- This slice's `slice-doc.md` (the background + scope) and `ledger.md`.
- For context on the original finding: `docs/planning/v0.1.0/arc7-import/`
  `slice1-history-transfer/` ledger Amendment 2 + closing-report.

## Base

Continue `feature/v0.3.0-namespace` on top of slice 1 (`e469d0f`) — you edit the
already-renamed `test/lfmt_fezzik_SUITE.erl`.

## The fix

In `test/lfmt_fezzik_SUITE.erl`:

1. In the three inline oracle helpers (`assert_idempotent`,
   `assert_token_preservation`, `assert_ast_equiv`), replace the
   `iolist_to_binary(...)` flatten of **formatter output** with
   `unicode:characters_to_binary(...)`. Mind the return contract:
   `unicode:characters_to_binary/1` yields `binary()` on success but
   `{error,_}`/`{incomplete,_}` on malformed input — match/assert the binary so a
   bad result fails the test loudly (don't let an error tuple flow into a
   comparison). (`iolist_to_binary` on genuinely-binary, non-codepoint inputs
   elsewhere may stay — only the formatter-output flatten is the bug.)
2. Remove the `is_seven_bit_ascii/1` filter from `full_corpus/0` so **all** corpus
   files feed the inline oracles; delete the helper if now unused.

## Why

`lfmt_fezzik`'s formatter emits codepoints > 127 for multibyte-UTF-8 sources;
`iolist_to_binary` mangles them (re-read → `invalid_encoding`), which is why
v0.1.0 excluded `core-macros.lfe` and `clj-tests.lfe` from the inline-oracle
path. `unicode:characters_to_binary` round-trips them correctly, so the exclusion
is no longer needed.

## Engineering bar

- `grep iolist_to_binary` in the oracle flatten path → gone (or justified for
  genuinely-binary inputs); `grep -rn is_seven_bit_ascii test` → empty.
- The 2 multibyte files pass the inline oracles; `ct:log` the inline-oracle input
  count (now = full corpus) and state it.
- `rebar3 ct` green; `rebar3 compile` zero-warning; `rebar3 xref` + `rebar3
  dialyzer` clean. (CI reconciles.)
- `git diff --name-only <base>..HEAD` → **only** `test/lfmt_fezzik_SUITE.erl`;
  engine `lfmt_fezzik.erl`, `pe_*`, and `docs/planning/v0.5.0/` untouched.

## Working ledger + close

Update `ledger.md` per-row (toolchain rows note "CI reconciles"). At close write
`closing-report.md`: per-row walk + **bubble-up to the arc**, explicitly stating
the carried v0.1.0 Unicode-harness finding is now **closed**. Don't mark your own
rows CDC-verified.

## When done

Hand back: the harness fix committed; the inline-oracle input count showing the 2
files now included; green ct/compile/xref/dialyzer; the per-row ledger walk +
closing-report. **This is arc1's last slice** — flag that the arc is ready for
its close (composition check + `0.3.0` tag + v0.3.0 project close), but do **not**
create the `0.3.0` tag or close the arc yourself (that's the arc-close step).
