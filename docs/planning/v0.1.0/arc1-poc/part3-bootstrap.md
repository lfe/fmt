# Bootstrap — "fmt / LFE formatter — part 3" (PoC continuation)

> For future-Claude (and Duncan) resuming this work in a fresh conversation.
> Part 1 = the original rebar3_lfe formatter work. Part 2 = the research
> conversation that produced the Πₑ port plan **and** an original
> width-independent formatting-algebra result (see below). **Part 3 (this
> bootstrap) continues the proof-of-concept (PoC):** CC and others have been
> implementing the engine while we did the research; the numbers are landing in
> the files listed in §4, and our job now is to read them, decide whether the
> approach clears the bar, and plan next steps.

## 0. How we work (read first)

- **Peer frame.** Equal contributors, honest engagement over agreeable hedging,
  name the pulls, calibrate confidence (verified vs reasoned vs conjecture).
  Load the **collaboration-framework** skill at session start.
- **Roles.** *We* (Duncan + Claude-in-chat) do research, architecture, planning,
  brainstorming, and analysis. We write **cc-prompt** files with a **ledger**;
  **CC** (Claude Code) implements, walking the ledger; **CDC** independently
  verifies (re-runs Verify commands, reads diffs, not summaries). The implementer
  never marks its own work verified. Load **ledger discipline** for any slice.
- **Erlang/LFE.** Load **erlang-guidelines** (`11-anti-patterns` first). For LFE,
  the prototype skill is `lfe/lfe/workbench/lfe-proto-skill.md`. Target **OTP 28**
  now; OTP 22–29 backport is a deferred slice (markers in place).
- **Sandbox hazard.** The workspace sandbox can create but **cannot unlink** files
  in mounted repos, and must not mutate git. Hand Duncan any `rm`/`git` commands.
- **This is a standalone library.** `fmt` (GH org `lfe`, repo `fmt`) is a
  BEAM-native pretty-printer library; `rebar3_lfe`'s `format` provider will
  consume it as a dependency (the `raco fmt` ↔ Racket `fmt` split).

## 1. What we're building

A formatter for LFE built on a BEAM port of **Πₑ (PrettyExpressive)** — the only
published pretty printer that is expressive, provably cost-optimal, and reasonably
efficient. Two layers: a generic **engine** (Πₑ port — the reusable, novel-on-BEAM
piece) and an **LFE knowledge layer** (a composable `formatter-map` over a palette
of layout combinators — the answer to the Lisp-macro problem: form-knowledge as an
extensible registry, not a hardcoded switch).

## 2. The PoC question (arc1-poc)

The honest open question Πₑ leaves us: **is an expressive-and-optimal printer
viable / fast enough on the BEAM for LFE?** Πₑ is `O(n·W⁴)` and its own benchmarks
show it is *slowest exactly on S-expression workloads* — which is all of Lisp. So
arc1 is literally a viability verdict, not just a first feature. What we're testing:

1. **Correctness** — resolver optimum `=:=` brute-force oracle (cost level).
2. **Latency on real LFE** — especially S-expr-heavy files; against a go/no-go
   bar *(set this bar explicitly if not already in `running-recommendations.md`)*.
3. **Memo backend** — threaded-map vs ETS vs process-dictionary bake-off
   (one resolver, three backends; pick by measurement).
4. **The "niceness" bet** — instrument the resolver to dump per-node `(λ, cost)`
   frontiers on real LFE and measure whether class counts / convexity are as tame
   as the research predicts (cheap, decisive — see §5).

## 3. The slices (arc1-poc)

- **slice1-resolver** — engine core: `pe_doc` (lean hash-consed term DAG, frozen
  tuple + `element/2`), `pe_cost` (behaviour + squared default + linear test
  factory), `pe_measure`, `pe_mset` (Pareto frontier), `pe_resolve` (memo-
  parameterised), `pe_memo` (map/ets/pd) + the oracle + the memo experiment.
- **slice2-render-real-lfe** — `pe_render` + `pe:format/2` façade + real-LFE
  inputs (deferred out of slice1, which is cost-level only).
- **slice3-lfe-knowledge-layer** — the `formatter-map` + conventions palette.
  **CC is implementing this now** (reading its `cc-prompt.md`).

## 4. Current state — READ THESE FIRST (they have the numbers we don't)

The implementation has moved since the research conversation. Before reasoning
about next steps, read the live status:

```
docs/planning/v0.1.0/arc1-poc/running-recommendations.md          # rolling decisions/findings
docs/planning/v0.1.0/arc1-poc/slice1-resolver/cc-prompt.md
docs/planning/v0.1.0/arc1-poc/slice1-resolver/ledger.md           # slice1 closure + evidence
docs/planning/v0.1.0/arc1-poc/slice1-resolver/cdc-verification.md # independent verification
docs/planning/v0.1.0/arc1-poc/slice2-render-real-lfe/slice-doc.md
docs/planning/v0.1.0/arc1-poc/slice2-render-real-lfe/cc-prompt.md
docs/planning/v0.1.0/arc1-poc/slice2-render-real-lfe/ledger.md
docs/planning/v0.1.0/arc1-poc/slice3-lfe-knowledge-layer/slice-doc.md
docs/planning/v0.1.0/arc1-poc/slice3-lfe-knowledge-layer/cc-prompt.md   # CC implementing now
docs/planning/v0.1.0/arc1-poc/slice3-lfe-knowledge-layer/ledger.md
```

Also check the experiment output (memo bake-off table, linearity series) under
`bench/results/`. **Do not trust this bootstrap's expectations over those files** —
they reflect what was actually measured.

## 5. If the numbers hold up — where we're thinking of going

Decision tree once slice1/2 latency + memo numbers are in:

- **If plain Πₑ clears the latency bar:** ship it as the engine. The optimisation
  ideas become *optional* future work, pursued only if profiling later shows the
  `W`-factor is the bottleneck.
- **If Πₑ does NOT clear the bar:** we have a worked-out, genuinely novel
  alternative ready to promote to its own arc (provisionally **arc2**):

  > **The optimised formatter — `pretty-canny` / `Πₗ` (name TBD, see §6).**
  > Full write-up: **`docs/research/symbolic-pwl-frontier.md`**.
  > Carry Πₑ's per-node Pareto frontier *symbolically* (piecewise-linear
  > "hockey-stick" cost-to-column functions) instead of sampling `W` columns →
  > **width-independent** (`O(n·D²)`, `D` = right-spine nesting depth) for the
  > `group + nest + align` fragment that covers canonical LFE (verified by hand
  > on `gps1.lfe`; NOT proved; `fill` unhandled; a bet on real-Lisp tameness with
  > a Πₑ fallback to make it safe). Before promoting: reproduce the paper's §8
  > results in code and property-test the algebra against the same oracle the PoC
  > already builds.

- **Either way**, the other levers are catalogued in
  **`docs/planning/v0.1.0/arc1-poc/optimisation-ideas.md`**: Lever 1 (aligned-only
  → free `W³`), Lever 2 (per-form/file parallelism → free cores), Lever 3
  (greedy-first optimal-repair hybrid), the format-server/incremental cache, and
  the per-subproblem-actor *trap* to avoid. Suggested ordering is in that doc.

## 6. Open items / decisions waiting

- **Name the optimised approach.** Shortlist (Duncan to pick): **`pretty-canny`**
  (recommended — shrewd/thrifty, Scots ring, "too clever to sample W"),
  `pretty-frugal`, `pretty-spry`, `pretty-thrifty`; `Πₗ` as the algorithm glyph.
  Apply the chosen name to the paper byline and headings.
- **The latency go/no-go bar** for arc1-poc (if not yet pinned in
  `running-recommendations.md`).
- **Set the formal paper byline/affiliation** in `symbolic-pwl-frontier.md`.
- **Measure the niceness bet** (§2.4 / §5) — the cheapest high-value next probe.

## 7. Key references

- Research paper (the optimised engine): `docs/research/symbolic-pwl-frontier.md`
  (+ section sources in `docs/research/symbolic-pwl-frontier/`).
- Optimisation menu: `docs/planning/v0.1.0/arc1-poc/optimisation-ideas.md`.
- Πₑ port plan: `docs/planning/v0.1.0/pretty-expressive-port-plan.md`.
- Original paper: `docs/research/[2023] Porncharoenwase - A Pretty Expressive Printer.pdf`.
- Term-DAG store design (for the engine + a possible graffeo derived view):
  `erlsci/graffeo/workbench/term-dag-tier-from-fmt.md`.
- Racket reference implementation: the `racket/fmt` clone (`core.rkt`,
  `conventions.rkt`, `main.rkt`).
