# CDC verification — arc1-poc / slice7-frontier-width

Verifier: Claude (Cowork chat seat, acting as CDC — independent of the
implementer, CC, which authored slice7)
Date: 2026-06-24
Reviewed commit: `4e379ff` (slice7), `53f5d11` (ledger SHA).

## Verification boundary

Static, evidence-based CDC: diffs, committed source, and the committed
`frontier.csv` read directly. The **decisive result (the niceness-bet verdict)
was independently re-derived** from `frontier.csv` with an RFC-4180 parser — not
taken from CC's summary. Build/PropEr commands were not re-run here (no OTP 28
toolchain); CC's clean-tree run (216 eunit + 7 PropEr + 2 CT green) is the
pass-evidence for the property tests, whose **existence and structure** I
confirmed in source.

## Summary

No blockers. 15 rows done, 1 deferred, 0 no-op, 0 silent drops. The slice's
headline claim — the niceness bet holds — is **independently confirmed** from
the committed data. The instrumentation is correctly scoped (resolver-only,
behind a flag) and structurally non-perturbing.

## Independent reproduction of the verdict (frontier.csv, 1665 rows)

```text
CORPUS max |mset|            = 7           (CC: 7 ✓)
per-resolve max distribution = {0:4, 1:449, 2:634, 3:362, 4:153, 5:38, 6:20, 7:7→5}
                               (CC table reproduced; 4 negligible max=0 degenerate forms)
rows with max >= 5           = 63 / 1665 = 3.8%   (CC: 3.8% ✓)
max (max/W)                  = 0.10        (CC: 0.10 ✓)
all status                   = ok          (0 timeout/error rows)

guard_SUITE: max frontier across its forms = 5  (CC: 5 ✓ — tame)
             max memo-entry count in a guard form = 4921
             (CC said 3859; committed CSV max is 4921 — node-count story is
              if anything STRONGER. Minor reporting nit, conclusion identical.)
width-7 frontiers: clj.lfe idx {6,19,110} + ltest-macros.lfe idx 3  (CC ✓)
```

**Verdict reproduced:** frontier width is a small single-digit constant `<< W`
everywhere measured; guard_SUITE's latency is node-count, not the `W`-factor.
The niceness bet holds; arc2/symbolic-PWL is optional, not triggered.

## Scope + structural evidence (static)

```text
Scope (git show --name-only 4e379ff)
  PASS — src change confined to src/pe_resolve.erl (resolver-only, as designed).
  Plus bench harness/tests + new frontier.csv + ledger. No pe_mset/pe_cost/
  pe_doc/pe_measure/pe_lfe changes.

Opt-gated, present-iff-on (src/pe_resolve.erl)
  PASS — opts() += frontier_stats => boolean() (default via maps:get(_,_,false));
  stats() += frontier => map(); with_frontier/2 omits the key when off.

The seam + zero-overhead-off
  PASS — sample_frontier/3 called once at the memo-put site (the `error ->`
  branch, line 138). Off clause:
    sample_frontier(_Key, _Set, #rs{frontier_stats=false}=RS) -> RS.
  A single field-match returning RS — no length/1, no map update when off.
  {set,Ms} clause samples length(Ms); {tainted,_} clause contributes nothing.

Invariance + oracle properties (existence + structure)
  PASS — prop_frontier_invariant (MeasureOff =:= MeasureOn and
  StatsOff =:= maps:remove(frontier, StatsOn)); prop_frontier_oracle
  (resolver cost =:= pe_gen oracle with flag on); pe_frontier_tests
  (frontier_choice/choiceless, present/absent-by-flag). Pass-evidence: CC
  clean-tree run (7 PropEr properties green).
```

## Ledger walk

| ID | CDC status | Basis |
|----|------------|-------|
| A1S7-1..2 | verified done | `frontier_stats` opt + `frontier` stat key, present-iff-on, in source |
| A1S7-3 | verified done | seam sample is `length(Ms)` for `{set,_}` at memo-put; tainted contributes nothing |
| A1S7-4 | verified done | `frontier_choice_test`/`choiceless_test` present with hand-computed expectations |
| A1S7-5..6 | verified (structure) + clean-tree green | `prop_frontier_invariant` present; CC PropEr run green (not re-run here) |
| A1S7-7 | verified done | off clause is a no-op field read (read source) |
| A1S7-8 | verified (structure) + clean-tree green | `prop_frontier_oracle` present; CC PropEr run green |
| A1S7-9..12 | verified done | `frontier` bench mode + `main(["frontier"])`; `frontier.csv` 1665 rows reproduced; per-form `index`/`head` present |
| A1S7-13 | verified done | verdict independently reproduced (above) |
| A1S7-14..15 | clean-tree green (CC-run) | compile/xref/dialyzer/eunit 216/proper 7/ct 2 — not re-run here |
| A1S7-16 | valid deferred | OTP backport + coverage/CAP carried |

## Findings

- **F1 (minor / reporting).** Ledger/closing report cite guard_SUITE's max
  memo count as **3859**; the committed CSV maximum for a guard_SUITE form is
  **4921**. The conclusion (node-count-bound, not frontier-bound) is unchanged
  and slightly strengthened. Suggest correcting the figure on a future touch;
  not worth a commit on its own.
- **F2 (positive).** The invariance property is the right safety guarantee and
  is present and correctly stated — instrumentation observes, never alters the
  optimum or the base counters. This is what makes the `frontier_stats` flag
  safe to leave in the resolver permanently.

## Closure

CDC accepts slice7. The niceness-bet verdict is independently confirmed from
committed data; the instrumentation is resolver-scoped, opt-gated, and
structurally non-perturbing. Engineering gates rely on CC's clean-tree run
(noted). This is the decisive arc1 result: **plain Πₑ is viable; arc2 optional.**
