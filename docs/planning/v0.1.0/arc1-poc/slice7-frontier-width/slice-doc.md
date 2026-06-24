# Slice 7 — frontier-width instrumentation (the niceness bet)

> Design + scope. Companion: `cc-prompt.md`, `ledger.md`. Arc: arc1-poc.
> Slug proposed; rename freely. Queued **behind slice6** (uses its reader bridge).

## Why this slice exists

Πₑ's cost is `O(n·W⁴)`. The `W⁴` comes from the per-subproblem **Pareto
frontier** — the resolver memoizes a measure set (`mset`) per `{Id, C, I}` key,
and that set can in principle hold up to `W` non-dominated measures; frontier
operations (merge/dedup/compose) scale with its width. The research **bet**
(`docs/research/symbolic-pwl-frontier.md`, paper §8) is that on real Lisp these
frontiers stay **small and convex** — a handful of classes, nowhere near `W` —
so the *effective* cost is far below the worst case.

This slice measures that directly: instrument the resolver to record the
distribution of frontier widths (`|mset|`) per memo entry, and dump it over the
real corpus.

## What slice6 changed about this slice's purpose

Slice6 gave us whole-file latency on real files: **cl.lfe ~26 ms, clj.lfe
~26 ms, most test suites < 30 ms, guard_SUITE the outlier at ~51 ms / 33k
nodes**, with **0 genericised forms** (the knowledge layer engaged on 100% of
real forms, so these are the *real* formatter's numbers). Viability is, in
practice, answered — format-on-save (<100–200 ms whole-file) clears
comfortably.

So slice7 is no longer a go/no-go probe. Its job is now:

1. **Confirm the mechanism.** If frontier widths are tame (single-digit `|mset|`,
   `<< W`), that *explains* why slice6 is fast and tells us there is no hidden
   `W⁴` tail waiting on a larger or nastier file.
2. **Diagnose the tail.** guard_SUITE costs ~2× the others. This slice answers
   whether that is benign **node count** (33k nodes → linear, fine) or
   **fat frontiers** (the `W`-factor genuinely biting → the trigger to promote
   arc2 / pretty-canny). That is a sharp, decisive question only this
   instrumentation can answer.

A fat-frontier finding would be the strongest evidence for the symbolic-PWL
work; a tame finding closes the niceness bet in plain Πₑ's favour and demotes
the optimisation ideas to optional.

## Why `tainted` is not the metric (the gap slice4 left)

`tainted` counts *pruned over-wide sub-layouts / delayed-beyond-W promises*.
Frontier width is the *surviving* set per memo entry — a different quantity, and
the one the `W⁴` bound is about. slice4 explicitly used `badness`/`tainted` as a
proxy (its amendment 3); this slice replaces the proxy with the real
measurement.

## The seam (grounded in current code)

`pe_resolve:resolve_node/4` memoizes a freshly computed `Set` per
`Key = {Id, C, I}` (pe_resolve.erl, the `error ->` branch ~lines 105–112).
`pe_mset:mset()` is `{set, [measure()]}` | `{tainted, thunk}`; frontier width is
`length(Ms)` for a `{set, Ms}`. **One instrumentation point** — record
`length(Ms)` at that memo-put site — captures the per-subproblem frontier
distribution. Tainted sets have no frontier (already counted by `tainted`).

## Design constraints

- **Opt-gated, zero overhead when off.** A new optional `frontier_stats` flag in
  the resolver opts (default `false`). When off, the hot path does no extra
  work and timing is unchanged — this matters because slice6/future latency runs
  must not be perturbed.
- **Result invariance.** With the flag on or off, the resolver must return the
  *identical* optimal measure and the *identical* `memo_size`/`calls`/`tainted`
  counters. Instrumentation observes; it must never alter the answer. Property-
  tested against the existing oracle-backed resolver tests.
- **Deliberate resolver change.** Unlike slice5 (which forbade resolver edits),
  this slice intentionally edits `pe_resolve` — narrowly, behind the flag.

## Scope / non-goals

- In: `pe_resolve` instrumentation + `opts()`/`stats()` type extension; a bench
  mode dumping frontier distributions over the **real corpus** (reuse slice6's
  `pe_lfe_read` bridge for cl.lfe/clj.lfe/test/*.lfe) plus the knowledge and
  stress corpora; the decisive analysis.
- Out: any change to resolver *semantics* or the cost model; the symbolic-PWL
  engine itself (that is arc2, promoted only if this slice shows fat frontiers);
  pinning the numeric latency bar (separate, near-formality given slice6);
  OTP backport; coverage + CAP audit (carried arc deferrals).
