# arc8-docs-and-tag — plan

> **Arc numbering:** this is the project's **arc8** because v0.2.0's one imported
> dev arc is `arc7-rules-v2` (kept at number 7 — we don't renumber history), so
> the fmt-side migration work increments after it. v0.2.0 is intentionally a
> thin project: the refined-brute *code* state already arrives inside the single
> import done by v0.1.0/arc7-import; this arc only lands v0.2.0's **own docs and
> tag**. One arc, **one nested slice** (`slice1-place-and-tag`). Project:
> **v0.2.0**. Master reference: `workbench/fezzik-migration-plan.md`.
>
> **v2.1 / nesting note (Version History v1.1):** updated from the original
> "single-slice arc, docs at arc level" to a **nested slice** so the slice → arc
> → project close ladder is genuine and arc-close is real practice (a bare
> single-slice would collapse the arc away, leaving nothing to arc-close). The
> three ledgers stay scale-distinct: the slice ledger holds the *steps*; the arc
> and project ledgers below hold *composition*.

## Why this arc (and why it's thin)

The 0.2.0 milestone is the **refined brute-force formatter** — the A7 rules-v2
work, the 7th and last arc of Fezzik's development in `rebar3_lfe`. That code
and its full history are already brought into `fmt` by the *single*
`filter-repo` + merge in `v0.1.0/arc7-import/slice1` (one continuous history
can't be imported in pieces). So nothing is left for v0.2.0 to *import* or
*build*. What remains, and what keeps the work honestly **per-project**, is:

1. placing v0.2.0's design record — the imported `arc7-rules-v2` docs — into
   `docs/planning/v0.2.0/`, and
2. tagging `0.2.0` on the refined-brute tip.

Thin is fine. Per the operator decision (2026-06-25), each version is its own
project regardless of size; v0.2.0 gets its own arc, docs, and tag rather than
being folded into v0.1.0.

**`0.2.0` is a source-history marker, not a buildable release** — same as
`0.1.0`. The imported commit it tags carries only engine files (filter-repo
strips `app.src`/`rebar.config`). First buildable, publishable tag is `0.4.0`.

## Slice breakdown

| # | Slice | Scope | Gate |
|---|-------|-------|------|
| 1 | `slice1-place-and-tag` | `git mv` `arc7-rules-v2/` into `docs/planning/v0.2.0/`; remove the emptied `docs/design/022-lfe-format/`; tag `0.2.0` on the refined-brute tip (full-message anchor) | docs placed w/ history; staging dir gone; `0.2.0` annotated, unique, descendant of `0.1.0`; v0.1.0/v0.5.0 untouched; diff is docs-move + tag only |

One slice — but run as a nested slice (not a collapsed bare slice) so the arc
has something to compose and close (see the v2.1 note above).

## Arc Ledger (composition rows — LEDGER-DISCIPLINE Section B)

> Opens here; closes (per-row walk) in `closing-report.md`. Class-(b) is
> *reproduced at arc scale*, not inherited from the slice.

Capability: *land v0.2.0's refined-brute design record (`arc7-rules-v2` docs) and
the `0.2.0` tag, completing the doc-split staging from v0.1.0, with v0.1.0/v0.5.0
untouched.*

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A8-1 | slice 1 (place-and-tag) closed | ptr: `slice1-place-and-tag/cdc-verification.md` | correctness | arc-plan | open | | class-(a) |
| A8-2 | **composes**: `docs/planning/v0.2.0/arc7-rules-v2/` present (history intact) **and** `0.2.0` resolves to the refined-brute tip (descendant of `0.1.0`) **and** the staging dir `docs/design/022-lfe-format/` is gone — together, end-to-end | arc-scale demo: `ls` tree + `git show 0.2.0` + `git merge-base --is-ancestor 0.1.0 0.2.0` + absence check | serious | arc-plan | open | | class-(b) — reproduce at arc scale |
| A8-3 | v0.1.0 bubble-up rules honored (full-message tag anchor; no `RESEARCH-BOOTSTRAP`) dispositioned | ptr: project-plan v1.0 + slice ledger | correctness | bubble-up | open | | class-(c) |

## Scope detail (executed by `slice1-place-and-tag`)

**Dependency:** runs only after `v0.1.0/arc7-import` (the import + slice2
doc-split) has landed, so `arc7-rules-v2` and the refined-brute tip both exist in
`fmt`. Sequencing also required the `rebar3_lfe` "better brute" 0.2.0 work to be
landed *before* that import, so the tip was captured (it was — see the tag
anchor below).

**Doc placement** (`git mv`, history follows):

| from (imported tree) | to |
|---|---|
| `docs/design/022-lfe-format/arc7-rules-v2/` | `docs/planning/v0.2.0/arc7-rules-v2/` |

(The arc1–6 dirs + loose spec/gallery/bootstrap/smoke files are v0.1.0's, placed
by `v0.1.0/arc7-import/slice2`. After both placements, the imported
`docs/design/022-lfe-format/` source dir is empty and removed.)

**Tag:**

- `0.2.0` on the **refined-brute tip** — the imported tip
  `5334ff8` *"A7·S6 — gallery regen + full sweep"* (the rewritten `rebar3_lfe`
  `4a509c1`), the last commit of Fezzik's imported history. Anchor on the **full
  message** (`git log --all --fixed-strings --grep='A7·S6 — gallery regen + full
  sweep'`) — short tokens are not unique (v0.1.0 slice-2 finding). Tag annotated.
- **Operator decision flagged:** A7·S6 touches only docs (gallery/rules regen);
  the formatter *code* froze one commit earlier at `5086e4e` *"A7·S5c·fix1 —
  suppress export/import sort on any entry comment"*. Recommended target is the
  **tip `5334ff8`** ("the complete refined-brute milestone, code + final
  gallery"), paralleling how `0.1.0` marked the A6·S0 milestone. If Duncan
  prefers "the newest commit touching the formatter," use `5086e4e` instead —
  the formatter code is identical between the two. Confirm before tagging.
- Verify `0.2.0` is a **descendant of `0.1.0`** (`git merge-base --is-ancestor
  0.1.0 0.2.0`) so the tags are DAG-ordered.

## Success criteria (gate)

- `docs/planning/v0.2.0/arc7-rules-v2/` present with history intact
  (`git log --follow` works on its files).
- `0.2.0` tag resolves to the correct imported refined-brute commit.
- `docs/planning/v0.5.0/` (pe) and `docs/planning/v0.1.0/` (the 0.1.0 docs)
  are untouched by this arc.
- The imported `docs/design/022-lfe-format/` source dir is empty after this arc
  (its last contents, `arc7-rules-v2`, have moved here).

## Out of scope → later projects

- The history import itself (v0.1.0/arc7-import).
- Namespace rename (v0.3.0), split / publish / integrate (v0.4.0).

## How we work (unchanged)

Peer frame; CC implements walking a ledger; CDC verifies independently (reads
the moved tree + tag, re-derives the tagged commit by message); implementer
never marks its own work verified; iteration cap 5. Sandbox cannot mutate git —
hand the operator any `git`/`rm`. Load **collaboration-framework**. Ledger IDs:
arc-ledger `A8-<row>`; slice ledger `A8S1-<row>`.

## Version History

- **v1.1 — 2026-06-26** (CDC, planning v0.2.0 forward). Brought the arc-plan to
  collaboration-framework v2.1: added the **Arc Ledger** composition section and
  a **slice breakdown** (one nested `slice1-place-and-tag`, changed from the
  original "single-slice arc, docs at arc level" so arc-close is genuine
  practice); pinned the `0.2.0` tag anchor to the imported tip `5334ff8` (A7·S6,
  full-message anchor) with the formatter-froze-at-`5086e4e` alternative flagged
  for the operator; added the descendant-of-`0.1.0` check. No change to the
  substantive work (place `arc7-rules-v2` docs + tag `0.2.0`).
- **v1.0 — 2026-06-25** (initial). Single-arc/single-slice plan: place the
  refined-brute design record + tag `0.2.0`; scope boundaries vs
  v0.1.0/v0.3.0/v0.4.0.
