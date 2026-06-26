# CC prompt — arc1-poc bookkeeping cleanup (slice4 + slice5 closure hygiene)

> For CC (the implementation seat). This is a **bookkeeping chore**, not a
> feature slice: no code changes, no behaviour changes. Walk the ledger;
> CDC (Codex Desktop or chat-seat Claude) will verify the result. Do not fold
> any unrelated work into these commits.

## Context

Slices 1–3 each recorded their closing SHA in a dedicated follow-up commit
(`7c69f1e`, `1e5b0ab`, `00865f9`). Slices 4 and 5 landed their implementations
(`96dcdfd` and `a2226e0` respectively) but **never got that follow-up**: both
ledgers still read `Closed at commit: pending (… + working tree)`, which is now
stale because the working tree is committed. Independent CDC review of both
slices is already written to disk (see `cdc-verification.md` in each slice
dir) and is currently **untracked**.

This chore: record the real closing SHAs, point each ledger at its CDC doc, and
commit the (already-authored, do-not-edit) CDC verification files.

## Safety / discipline

- **No `git` safety-bypass flags.** No `--allow-dirty`, `--no-verify`, `--force`.
  If a gate fires, satisfy it; do not bypass it (see CLAUDE.md "Lykn CLI safety
  gates" — the same principle applies to this repo's git usage).
- **Do not edit the two `cdc-verification.md` files.** They are CDC-authored
  artifacts; you are only staging/committing them. Editing them would collapse
  the independence between implementer and verifier.
- **Scope:** only the four files named below may change. Anything else in
  `git status` is out of scope — stop and report.

## Ledger

| ID | Criterion | Verify | Status |
|----|-----------|--------|--------|
| CLN-1 | slice4 ledger Closure line records closing SHA `96dcdfd` and date 2026-06-22/23, replacing the "pending (… working tree)" text | `git show HEAD:docs/planning/v0.5.0/arc1-poc/slice4-pathological-stress-corpus/ledger.md \| tail -6` | planned |
| CLN-2 | slice4 ledger "CDC verification:" line points at `cdc-verification.md` and states the operator-run command gate is still outstanding | ledger review | planned |
| CLN-3 | slice5 ledger Closure line records closing SHA `a2226e0` and date, replacing "pending (… working tree)" | `git show HEAD:…/slice5-lfe-layout-refinements/ledger.md \| tail -6` | planned |
| CLN-4 | slice5 ledger "CDC verification:" line points at `cdc-verification.md` + operator-run gate note | ledger review | planned |
| CLN-5 | both `cdc-verification.md` files are committed unmodified | `git log --oneline -- …/cdc-verification.md`; `git diff` shows no content change vs working tree | planned |
| CLN-6 | each change is a focused commit; no unrelated files staged | `git show --stat` per commit; `git status` clean at end | planned |
| CLN-7 | (optional, see below) engineering-gate commands re-run on clean tree; raw output appended to each CDC doc's deferred section | command output | planned |

## Steps

1. **slice4 ledger** — in
   `docs/planning/v0.5.0/arc1-poc/slice4-pathological-stress-corpus/ledger.md`,
   change the Closure block to:

   ```
   Closed at commit `96dcdfd` on 2026-06-22 (implementation);
   bookkeeping SHA recorded 2026-06-23. Total rows: 28. Done: 26.
   Deferred: 2 (A1S4-27 OTP 22–29 backport; A1S4-28 coverage gate + CAP audit).
   No-op: 0.

   CDC verification: static review complete — see `cdc-verification.md`
   (no blockers; all reproducible counters matched). Engineering-gate command
   re-run (A1S4-25/26: compile/eunit/ct/proper/dialyzer/xref) remains
   operator-run pending.
   ```

   (Keep the existing "Key rendered evidence" / Caveat Checklist content intact.)

2. **slice5 ledger** — same treatment in
   `…/slice5-lfe-layout-refinements/ledger.md`:

   ```
   Closed at commit `a2226e0` on 2026-06-23. Total rows: 26. Done: 24.
   Deferred: 2 (A1S5-25 OTP 22–29 backport; A1S5-26 coverage gate + CAP audit).
   No-op: 0.

   CDC verification: static review complete — see `cdc-verification.md`
   (no blockers; both A1-R013/R014 caveats resolved with exact-assertion golden
   tests; scope-control rows confirmed). Engineering-gate command re-run
   (A1S5-23/24) remains operator-run pending.
   ```

3. **Commit** in three focused commits (or two ledger commits + one CDC-docs
   commit — your call, but keep them scoped):

   ```sh
   git add docs/planning/v0.5.0/arc1-poc/slice4-pathological-stress-corpus/ledger.md
   git commit -m "ledger: record slice4 closing SHA (96dcdfd)"

   git add docs/planning/v0.5.0/arc1-poc/slice5-lfe-layout-refinements/ledger.md
   git commit -m "ledger: record slice5 closing SHA (a2226e0)"

   git add docs/planning/v0.5.0/arc1-poc/slice4-pathological-stress-corpus/cdc-verification.md \
           docs/planning/v0.5.0/arc1-poc/slice5-lfe-layout-refinements/cdc-verification.md
   git commit -m "arc1-poc: add CDC verification for slice4 + slice5 (static review)"
   ```

4. **CLN-7 (optional but recommended).** On the now-clean tree, re-run the
   engineering-gate commands and paste the raw tails into the "DEFERRED to
   operator-run CDC" section of each `cdc-verification.md`, then commit as
   `arc1-poc: record operator-run verify output for slice4/slice5`:

   ```sh
   rebar3 compile && rebar3 eunit && rebar3 ct && rebar3 proper && rebar3 dialyzer && rebar3 xref
   ```

   Note: you running these is a useful clean-tree re-run, but it is **not**
   independent CDC (you also ran them while implementing). Flag in the commit
   body that final independent sign-off is Duncan's / a separate CDC seat's.

## Done when

`git status` is clean, both ledgers cite their closing SHA and CDC doc, both
CDC docs are committed unmodified, and (if CLN-7 done) the verify output is
recorded. Report the three (or four) commit SHAs back for the running log.
