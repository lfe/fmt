# Slice 6 — whole-file latency (minimal reader bridge)

> Design + scope. Companion: `cc-prompt.md` (implementation), `ledger.md`
> (verification). Arc: arc1-poc. Numbering per Duncan's convention
> (arc/slice/slug). Slug proposed; rename freely.

## Why this slice exists

arc1-poc's central question is a **viability verdict**: is an optimal printer
(Πₑ, `O(n·W⁴)`, slowest on S-expr workloads) fast enough on the BEAM for real
LFE? Slices 2–5 produced encouraging *per-form* timings on hand-built
`pe_lfe:form()` terms — but two things were still missing to turn those into a
verdict:

1. **No whole-file numbers.** All timing to date is per hand-built form.
2. **No reader.** `fmt` has no source front end at all; forms only enter as
   hand-built `form()` terms. So we literally cannot format `cl.lfe` — the very
   file we want to measure.

These collapse into one prerequisite: to time a whole file, we must read a
whole file. This slice builds the **minimum reader bridge** needed to get real
whole-file latency numbers, and measures them. It does **not** attempt a
faithful or production-quality formatter front end — that is the real A1-R015,
deferred (see Non-goals).

## The decision taken (2026-06-23)

Duncan's call: **reuse LFE's own reader** (`lfe_io`) as a *test-profile*
dependency rather than write fmt's own comment/span-preserving reader now. The
sexpr→`form()` conversion layer written here is reusable when the production
reader lands later; only the front (scanner) gets replaced. Reference machine:
Duncan's older MacBook Pro (a newer Mac Pro joins as a secondary later).

## The realistic formatting model (load-bearing design choice)

A real formatter formats each **top-level form independently** and joins the
results with the blank-line structure between them. This is both how editors
behave and what enables per-form parallelism (optimisation-ideas Lever 2).

Consequence for viability: the `O(n·W⁴)` cost applies **per form** (each small),
not to the whole 800-line file as one document. Whole-file latency =
Σ(per-form format) + read/convert. We therefore measure per-form-summed as the
headline number, and need **no `src/` change** — we reuse `pe_lfe:format_binary/2`
per form.

## Reference inputs (confirmed present)

| File | Lines | Bytes |
|------|-------|-------|
| `cl.lfe` (LFE Common-Lisp compat layer) | 767 | 21,904 |
| `clj.lfe` (LFE Clojure compat layer) | 842 | 26,968 |
| `test/*.lfe` (12 suites) | 4,246 total | — |

Located at bench time via `code:lib_dir(lfe)` (the test-profile dep ships its
own `src/` and `test/`).

## The conversion (sexpr → form()), with a no-crash fallback

`lfe_io:read_file/1 -> {ok, [Sexpr]}`. Map each `Sexpr` to `pe_lfe:form()`:

- atom → `{sym, atom_to_binary(A, utf8)}` (atoms already interned by the reader)
- integer → `{int, N}`
- `(quote X)` / `(backquote X)` / `(comma X)` / `(comma-at X)` → the matching
  `{quote|bquote|unquote, …}` (confirm exact head atoms against `lfe_scan`/`lfe_parse`)
- proper list in **code** position → `{call, [...]}`; in **data** position
  (under quote, or inside a quoted list) → `{list, [...]}`; `()` → `{list, []}`
- improper list → `{dotted_list, Heads, Tail}`
- tuple → `{tuple, [...]}`
- **fallback** (float, binary `#"..."`, map, char, string ambiguity, anything
  unmodeled): `{sym, iolist_to_binary(lfe_io:print1(Term))}` — one leaf carrying
  its printed text. Guarantees no crash and a structurally representative node.

## What the numbers mean (and don't)

This slice measures **latency**, not output fidelity. The call/list
disambiguation, string handling, floats/binaries/maps, comments, and source
spans are approximate or dropped. Node count tracks source size, so timing is
representative to within a small factor — good enough for a first viability
read, **not** the final formatter's numbers. State this in the closing report;
do not let "we formatted cl.lfe in N ms" become "the formatter is correct."

## Non-goals (explicitly deferred)

- Faithful conversion / source fidelity / comment + span preservation — the
  real **A1-R015**; will need fmt's own lexer (LFE's reader drops comments).
- Single-document (whole-file-as-one-resolve) model — a curiosity row at most.
- Pinning a numeric go/no-go bar — Duncan wants the numbers *first*; the bar is
  set after this slice reports.
- The niceness-bet frontier-width instrumentation — separate resolver slice.
- OTP 22–29 backport; coverage gate + CAP audit — carried arc deferrals.
