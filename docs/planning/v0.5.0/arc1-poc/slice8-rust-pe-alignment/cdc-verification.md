# CDC verification — arc1-poc / slice8-rust-pe-alignment

Verifier: Claude (Cowork chat seat, acting as CDC — independent of the
implementer, CC, which authored slice8).
Date: 2026-06-24
Reviewed: committed `5b0eb2f` (**= 8a**) **plus** the uncommitted working-tree
changes that apply **iteration 1** (reported-cost comparator) and reconcile the
ledger/slice-doc.

> **Correction notice.** An earlier draft of this report conflated *committed*
> and *working-tree* state and wrongly said iteration 1 was "in the committed
> code." It is not. `git show 5b0eb2f` is 8a (the comparator there is
> `recompute(OurBin, W)`, `rand_doc` is `rand:uniform(12)` with no `cost`).
> Iteration 1 lives in the **working tree, uncommitted** (`git diff` converts the
> gate to reported cost, re-admits `cost`, regenerates the CSV). This version
> distinguishes the two throughout. The slip was mine — `git grep`/`sed` read the
> working tree while `git show` read the commit, and I crossed them.

## Verification boundary

Static, evidence-based CDC: committed diffs, source at both the commit and the
working tree, and the committed-vs-working `oracle_samples.csv` read directly.
**No OTP/Rust toolchain here** (`erl`/`rebar3`/`cargo` absent), so the green-floor
claims (eunit/proper/ct, dialyzer/xref/clippy) were **not re-run** at either
state; CC's clean-tree run is the execution evidence, structure confirmed in
source. The differential result was re-derived **independently** from the CSV at
both states with my own recompute.

## State of the tree

- **Committed `5b0eb2f` = 8a, internally self-consistent.** Gate =
  string-recompute; `cost` excluded; ledger A1S8-16 and A1-R018 describe exactly
  that. No internal mismatch. (My earlier "serious doc/code mismatch" finding was
  an artifact of crossing committed/working state — **withdrawn**.)
- **Working tree = 8a + iteration 1 + reconciliation, uncommitted.** `git status`
  shows `M` on `test/pe_oracle_mjl.erl`, `test/oracle/src/main.rs`,
  `bench/results/oracle_samples.csv`, `ledger.md`, `slice-doc.md`; `CHANGELOG.md`
  untracked. `git diff` confirms this is iteration 1 (gate → reported cost; `cost`
  re-admitted to `rand_doc`; CSV regenerated to 36 rows incl. cost) plus the
  ledger/slice-doc spec-keeping pass.

## Independent re-derivation

**Working-tree CSV (36 rows, the iteration-1 artifact)** — recomputed
`{badness,height}` from each render with my own implementation, and checked the
reported-cost columns:

```text
rows = 36  (8 cost-bearing)
our_cost == mjl_cost (both engines agree)          = 36/36   ✓
cost-free rows: my string-recompute == reported col = 23/23   ✓
byte-identical renders                              = 36/36
cost-bearing rows demonstrate the iteration-1 payoff:
  (cost 3 1 (cost 0 1 (t "cwv")))  ⇒ render "cwv"  string=(0,0)  reported=(3,2)==(3,2) ✓
  (cost 2 1 (reset (cat (nl)(t "mfr")))) ⇒ "\nmfr" string=(0,1)  reported=(2,2)==(2,2) ✓
  … 8/8 cost rows: reported costs agree, string-recompute cannot see the injected cost
no discrepancies
```

This is the proof string-recompute could not give: on cost-bearing documents the
rendered string undercounts the cost, yet both engines' **reported** costs agree.

**Committed 8a CSV (24 rows, cost-free)** — re-derived earlier: 24/24 cost-equal,
my recompute matches the columns 22/22, one genuine equal-cost tie, two agreed
`failed` rows. Consistent with the 8a gate.

## Mechanism confirmed by source (working tree)

- Rust `test/oracle/src/main.rs`:
  `validate_with_cost(DefaultCostFactory::new(width, Some(limit)))` →
  `result.cost()` → `OK <badness> <height>\n<layout>`; `Err ⇒ FAIL`.
- Erlang `test/pe_oracle_mjl.erl`: `our_render/2` → `{ok, Bin,
  pe_measure:cost(Measure)}`; `mjl_render/2` parses `OK b h`; `compare/5` gates on
  `OurCost =:= MjlCost`, byte identity only picking the `identical`/`tie` tag.
- `rand_doc/1` is `rand:uniform(13)` with `cost` at case 8; `serialize/1` emits
  `(cost B H D)`.

## Scope + structural evidence (committed 8a)

```text
git show --stat 5b0eb2f — engine + tests + docs only; no pe_lfe / formatter-map /
  pe_cost* / pe_memo* touched (A1S8-18/19). ✓
A1S8-1  pe_mset:failed/0 + merge identity (pe_mset.erl:55,82,86)        ✓
A1S8-3  pe_resolve fail -> pe_mset:failed() (pe_resolve.erl:179)        ✓
A1S8-9  no `full` in src/pe_doc.erl ⇒ deferral honest; re-entry in CHANGELOG ✓
A1S8-10 pe.erl:49 limit => trunc(1.2 * Width)                          ✓
A1S8-11 running-recommendations A1-R017 (limit + latency) + A1-R018 (LineM) ✓
```

## Findings (severity-graded, with disposition)

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| — | — | (withdrawn) "ledger/code mismatch in the commit" | **Not a defect.** Artifact of crossing committed/working state; 8a commit is self-consistent. |
| 1 | serious | A1-R018 "scope note" said `cost` is *excluded* from the differential corpus — contradicts iteration 1 (now in-corpus under reported cost). | **Fixed (CDC, this turn)** in `running-recommendations.md`: scope note revised to "in corpus, reported-cost comparator," re-entry trigger updated off "recompute". |
| 2 | minor | `pe.erl:9` moduledoc still said `limit => width` (code is `trunc(1.2*Width)`). | **Fixed (CDC, this turn).** |
| 3 | serious | (working tree) Ledger A1S8-16 corrected to reported-cost; rows A1S8-24…28 added/closed; numbers re-run (6000/6000 incl. cost; 5956/44; 36-row CSV). | **Resolved** by the iteration-1 reconciliation already in the working tree; independently corroborated by my 36-row re-derivation above. |
| 4 | minor | (working tree) slice-doc "why a string is enough" superseded. | **Resolved** — §"two-implementation cost model" rewritten to reported-cost-canonical with an iter1 correction note. |
| 5 | minor | (working tree) CSV predated cost re-admission. | **Resolved** — regenerated to 36 rows incl. 8 cost-bearing; verified above. |

## Open process items (not code defects)

- **Iteration 1 + the reconciliation are uncommitted.** They should land as a
  clearly-labelled `slice8 iteration1` commit (and `CHANGELOG.md` is untracked —
  add it). Until then the *committed* slice is 8a; the *working tree* is 8a+iter1.
- **Green floor not re-verified at the iter1 working tree** (no toolchain here).
  CC should confirm eunit/proper/ct + clippy still pass on the working tree before
  committing — the comparator and generator changed.

## Disposition

- **Code (8a + iteration 1):** accept. The algebra constructors, the reported-cost
  comparator (the stronger design), the `full` deferral, the `limit` change, and
  the disclosed LineM divergence are all correct and faithfully implemented; the
  36-row re-derivation independently corroborates the cost-bearing differential.
- **Docs/ledger:** the spec-keeping gap is closed — items 1–2 fixed this turn,
  3–5 already reconciled in the working tree. Remaining before slice close is
  purely procedural: commit the working-tree iteration 1 (+ CHANGELOG) and have CC
  confirm the green floor at that state.
