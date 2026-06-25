# Slice 8 · Iteration 1 — reported-cost comparator (re-admit `cost`)

> For CC (implementation seat). Iteration within slice8 (not a new slice).
> Builds on the landed 8a. CDC-authored. Iteration budget: this is iteration 1.

## Why this iteration

8a's differential oracle compares **cost recomputed from the rendered string**.
CC correctly found that breaks on `cost` nodes: an injected cost is part of the
engine's internal cost but *invisible in the string*, so two layouts that tie on
true cost ({0,2}) string-recompute to different values ({0,1} vs {0,2}), and the
two engines break that tie toward different layouts (legitimately — Πₑ
guarantees the same optimal *cost*, never the same *string*). CC's response —
exclude `cost` from the corpus, with documented compensating coverage — was
honest and correct *within the string-recompute method*.

But the method itself is the weaker choice, and it was **my spec's call**, not a
law: slice-doc §"two-implementation cost model" and ledger A1S8-16 told you to
recompute cost from the string and treat that as canonical. The property the two
engines are actually specified to share is the **reported optimal cost**, and
both expose it:

- mjl: `Doc::validate_with_cost(factory)` → `PrintResult`, and
  `PrintResult::cost()` (`print.rs:240`; `validate`/`validate_with_cost` at
  `print.rs:301/336`). The cost-node mechanism is right there at `print.rs:149`
  (`Cost(co, d) => m.cost = co + m.cost`).
- us: the `Measure` returned by `pe:format/2`, via `pe_measure:cost/1`.

Compare those two **reported** costs and the `cost` case passes correctly
({0,2} == {0,2}); the string comparison drops to a *secondary* check valid only
on unique-optimum docs. This re-admits `cost` to the differential corpus and
removes the blind spot for any future invisible-cost feature — strictly more
faithful, for ~10 lines, because mjl already exposes the accessor.

Within 8a's bounded corpus this changes **nothing** for the existing 6000
cost-free cases (there, reported cost == string-recomputed cost): they still
pass. The only gain is `cost` rejoining.

## One constraint to preserve (don't trip the known divergence)

8a documented a real newline-cost divergence (A1-R018): we charge the paper's
`LineM` indentation overflow; mjl does not. 8a bounded the corpus (nests 0..2,
depth-capped, `align` stays under width) so this is **never exercised** — within
those bounds our reported cost and mjl's agree. Reported-cost comparison would
*expose* that divergence if the corpus grew to exercise indentation past width.
So: **keep the indentation bounds**, and record at the comparator why (the
reported-cost equality is valid only where `LineM` charges nothing — i.e. inside
the existing bounds). Widening the corpus to indentation-overflow cases is a
separate decision gated on resolving the divergence (see the note to the
operator below — it is theirs to make, not this iteration's).

## Steps

1. **Rust oracle binary** (`test/oracle/`): in addition to the rendered layout,
   compute and print the chosen layout's cost via
   `validate_with_cost(DefaultCostFactory::new(width, Some(limit)))` →
   `PrintResult::cost()` (a `(badness height)` pair). On the `Err` /
   unprintable path (a wholly-`fail` doc), emit an explicit sentinel line, not a
   panic — the driver must distinguish "no valid layout" from a parse error.

2. **Erlang driver** (`pe_oracle_mjl` / `bench/pe_oracle`): obtain our reported
   optimal cost from the resolve/format result (`pe_measure:cost/1`). Make
   **reported-cost equality the canonical comparator**. Demote the
   string/byte-identity check to a secondary assertion, applied only when the
   optimum is unique (cost-free docs already satisfy this in practice; keep the
   existing 5945/55 byte-identity reporting as a *secondary* statistic, not the
   gate). Handle the unprintable sentinel on both sides (both must agree the doc
   is unprintable).

3. **Re-admit `cost`** to `rand_doc/1` (revert the 8a exclusion; restore the
   case and renumber). The wire format already carries `(cost B H ..)` (A1S8-14)
   and both sides already parse it — this is generator-only. Run the corpus over
   widths {40,80,120}; every case must be **reported-cost-equal**, including the
   cost-bearing ones (ties included).

4. **Spec-keeping** (do not leave the correction implicit in a generator
   comment):
   - slice-doc §"two-implementation cost model": replace "the oracle does not
     need mjl to expose its cost / a string is enough" with the corrected model
     — reported cost is canonical; string-recompute is the cost-free /
     unique-optimum secondary; note this was found in iteration 1.
   - ledger A1S8-16: refine the criterion to reported-cost equality (string a
     secondary check), and add the iteration rows below. Keep CC's original 8a
     evidence visible; mark it refined, not deleted.

5. **Re-run the green floor** (eunit/proper/ct, clippy) and the oracle corpus;
   record the new counts.

## Iteration ledger (append to `ledger.md`)

| ID | Criterion | Verify | Significance | Origin | Status |
|----|-----------|--------|--------------|--------|--------|
| A1S8-24 | Rust oracle emits chosen-layout reported cost via `validate_with_cost`→`PrintResult::cost()`; unprintable → sentinel, not panic | `cargo build`; run on a cost-bearing + a `fail` sample | serious | iter1 | planned |
| A1S8-25 | Driver uses **reported-cost equality** as the canonical comparator (`pe_measure:cost/1` vs mjl `cost()`); byte-identity demoted to a unique-optimum secondary | code review; the prior `cost` tie case now passes on cost | correctness | iter1 | planned |
| A1S8-26 | `cost` re-admitted to `rand_doc/1`; corpus widens over `cost` again; full corpus reported-cost-equal over {40,80,120} | run `bench/pe_oracle`; cost-bearing cases pass | correctness | iter1 | planned |
| A1S8-27 | Indentation bounds preserved (A1-R018 divergence stays unexercised); reason recorded at the comparator | code review of bounds + comment | serious | iter1 / A1-R018 | planned |
| A1S8-28 | Spec-keeping: slice-doc cost-model section + A1S8-16 corrected to reported-cost-canonical; 8a string-recompute evidence kept, marked refined | doc diff | serious | iter1 / spec-keeping | planned |

## Note to the operator (separate decision, not this iteration)

The newline-cost divergence (we keep paper `LineM`; mjl drops it) is a genuine
exception to "align to mjl specifically." 8a kept ours and bounded around it,
which is defensible — `LineM` is arguably the more correct charge — but it is a
deviation you should ratify, because it caps how far the differential oracle can
ever reach (it can never validate indentation-overflow layouts until the
divergence is resolved one way or the other). Two clean options when you want to
revisit: (a) keep `LineM`, accept the oracle ceiling; (b) add an
mjl-compatibility cost factory (no `LineM` charge) used *only* by the oracle, so
the differential corpus can grow to indentation-overflow cases while production
keeps `LineM`. Flagging, not deciding.
