# arc7-import — plan

> **Arc numbering:** this is the project's **arc7** because v0.1.0's brute dev
> arcs are the imported `arc1-lexer … arc6-release` (numbers 1–6); the fmt-side
> migration work increments after the highest existing arc in the project.
> (v0.3.0 and v0.4.0, having no prior arcs, start at arc1; v0.2.0's migration
> work is its arc8, after the imported `arc7-rules-v2`.)

> The arc that relocates the **proven brute-force LFE formatter** ("Fezzik")
> out of `rebar3_lfe` and into `lfe/fmt` **with full git history preserved**,
> and establishes the **0.1.0 brute baseline**: the first usable formatter state
> (`rebar3_lfe`'s `A6·S0`), its design docs, and the `0.1.0` tag. It is the
> foundation the rest of the line stands on — nothing in v0.2.0 (refined-brute
> docs + tag), v0.3.0 (namespace), or v0.4.0 (split / publish / integrate) can
> begin until Fezzik's code and history live in `fmt`. Project: **v0.1.0**.
> Master reference: `workbench/fezzik-migration-plan.md`.

## Why this arc

Fezzik is done. It went seven arcs (A1–A7) in `rebar3_lfe` and emerged as a
working, idempotent, comment-preserving LFE source formatter — lexer → CST →
renderer, three self-contained modules with no dependency on the rebar3
plumbing around them. That maturity is why this arc is *migration*, not
*construction*: the engineering risk is not "does the formatter work" but "does
its history survive the move intact, and do the suites stay honest in their new
home."

**The import is one physical operation that carries the engine's *entire*
history** (back to `0f74364`, through the A7 work). That's unavoidable and
correct — git history is continuous; you can't import "only the A6 state." So
this arc, as the first project, owns the single `filter-repo` + merge. What
makes it *v0.1.0* rather than the whole line is what it **claims**: the `0.1.0`
tag (on the imported `A6·S0` commit, was `41fcc55`) and the arc1–6 design docs.
The later 0.2.0 commit is already present in the imported DAG; **v0.2.0 the
project** simply adds its own tag and its arc7 docs on top (see
`docs/planning/v0.2.0/`).

**`0.1.0` is a source-history marker, not a buildable release.** After
`git filter-repo`, the imported commits contain only the engine files — no
`app.src`, no `rebar.config` — so you cannot `rebar3` them. That is intended.
The first buildable, publishable tag is `0.4.0` (see v0.4.0/arc1-release).

**Sequencing note:** to keep this a *single* clean import, the `rebar3_lfe`
"better brute" 0.2.0 work should be landed first, so the one import captures the
full history through the 0.2.0 tip. Then v0.1.0 tags `0.1.0` and the separate
v0.2.0 project tags `0.2.0` — both pointing into commits this arc already
brought over. Confirm the tip with Duncan before extracting.

## What moves (and what stays)

The Fezzik engine is three modules + three Common Test suites + the full design
record. The rebar3 provider stays behind.

| `rebar3_lfe` path | role | disposition |
|---|---|---|
| `src/r3lfe_format_lexer.erl` | scanner | **import** (renamed in v0.3.0) |
| `src/r3lfe_format_cst.erl` | CST parser | **import** |
| `src/r3lfe_formatter.erl` (1869 ln) | renderer | **import** (split in v0.4.0) |
| `test/r3lfe_formatter_SUITE.erl` (3057 ln) | CT suite | **import** |
| `test/r3lfe_format_cst_SUITE.erl` (412 ln) | CT suite | **import** |
| `test/r3lfe_format_lexer_SUITE.erl` (415 ln) | CT suite | **import** |
| `test/r3lfe_format_lexer_SUITE_data/` (incl. `tq_corpus.lfe`) | fixtures | **import** |
| `docs/design/022-lfe-format/` (whole tree) | spec + per-arc CC-prompt record | **import** here; arc1–6 placed in slice2, **arc7 placed by the v0.2.0 project** |
| `src/r3lfe_prv_format.erl` | rebar3 provider | **stays** — rewired in v0.4.0/slice3 |
| `test/r3lfe_prv_format_SUITE.erl`, `test/e2e/` | provider tests | **stays** |

The three engine modules are self-contained (they call only each other +
stdlib). The suites additionally use `lfe_io` as an AST-equivalence oracle, so
they need the `lfe` test dep — which `fmt`'s `rebar.config` **already carries**
(`{lfe, "~> 2.2"}`, test profile). Imported modules keep their `r3lfe_*` names
through this arc; the rename to `lfmt_fezzik*` is v0.3.0.

## Slice breakdown

| # | Slice | Delivers | Gate |
|---|-------|----------|------|
| 1 | **history-transfer** | `git filter-repo` extract of the 8 paths above → `merge --allow-unrelated-histories` into `fmt`; imported `r3lfe_*` modules + 3 CT suites compile and pass **under their original names**; the corpus sweep re-pointed off the absent `_integration/` dir onto the `lfe` test-dep corpus (`code:lib_dir`) so coverage stays real | all Fezzik commits present in `fmt`'s DAG with original authorship/dates (`git log --follow` works on every file back to `0f74364`); `rebar3 compile` zero-warning; `rebar3 ct` green; corpus sweep exercises a disclosed, non-trivial file count (not 1) |
| 2 | **docs-and-tag** | `git mv` the imported **arc1-lexer … arc6-release** dirs + spec/gallery/bootstrap/smoke into the `docs/planning/v0.1.0/` tree (per the §7a map, minus arc7); tag `0.1.0` (rewritten `A6·S0`) | the 0.1.0 docs land per the map; `git log --follow` intact across the moves; `0.1.0` resolves to the correct imported commit (located by message/date, since SHAs were rewritten); nothing under `docs/planning/v0.5.0/` (pe) disturbed; **arc7 left in place** for the v0.2.0 project |

Two slices because the work splits cleanly along a verification boundary: slice1
is *code + history + green suites* (the part with engineering risk), slice2 is
*0.1.0 doc placement + tagging* (the part with git-archaeology risk). Each lands
as one reviewable diff.

## Arc Ledger (composition rows — v2.1 retrofit)

> Opened retroactively (see Version History v1.3): arc7-import was planned
> pre-v2.1, so its composition rows are stated here now and **walked to closure
> in `closing-report.md`**. Per LEDGER-DISCIPLINE Section B, class-(b) rows are
> *reproduced at arc scale*, not inherited from the slices.

Capability: *relocate Fezzik into `fmt` with full, authorship-preserving git
history and establish the 0.1.0 brute baseline (design record + `0.1.0` tag),
keeping the suites honest and `pe`/v0.5.0 untouched.*

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A7-1 | slice 1 (history-transfer) closed | ptr: `slice1-history-transfer/cdc-verification.md` | correctness | arc-plan | open | | class-(a); attested by pointer |
| A7-2 | slice 2 (docs-and-tag) closed | ptr: `slice2-docs-and-tag/cdc-verification.md` | correctness | arc-plan | open | | class-(a) |
| A7-3 | **slices compose**: Fezzik present in `fmt` with preserved history **and** the 0.1.0 baseline (arc1-6 docs placed + `0.1.0` tag) **and** a real corpus **and** green suites — demonstrable end-to-end | arc-scale demo: DAG root `c5bfc71`↔`0f74364`; `ls docs/planning/v0.1.0`; `git show 0.1.0`; `rebar3 ct` / CI | serious | arc-plan | open | | class-(b) — **reproduce at arc scale**; suites-green via CI |
| A7-4 | slice-1 bubble-up (Unicode inline-oracle defect) dispositioned | ptr: arc-plan v1.1 + routing to v0.3.0 | serious | bubble-up | open | | class-(c) |
| A7-5 | slice-2 bubble-up (`RESEARCH-BOOTSTRAP` phantom; `A6·S0` tag-anchor) dispositioned | ptr: arc-plan v1.2 + migration §7a fix | correctness | bubble-up | open | | class-(c) |
| A7-6 | slice-1 bubble-up (`--follow` gate wording) dispositioned | ptr: arc-plan v1.1 | polish | bubble-up | open | | class-(c) |

## Key decisions carried into the slices

- **CC runs the history surgery** (operator decision 2026-06-25). The
  `filter-repo` extract and `merge --allow-unrelated-histories` are CC's job in
  the real environment; CDC + operator verify the resulting DAG before slice2
  proceeds. CC commits and reports SHAs as in every pe slice.
- **The Fezzik tip is on `rebar3_lfe`'s `release/0.5.x` branch** (HEAD
  `c28de51`), not `main` — clone/merge that branch.
- **Corpus portability is a first-class slice1 concern, not an afterthought.**
  The corpus-sweep tests (`conf_wide_sweep`, `corpus_sweep`) discover `.lfe`
  files under `<repo>/_integration/**` and assert only `Checked > 0`. That dir
  does not exist in `fmt` and is not imported, so the sweep would pass
  *hollowly* on the single bundled `tq_corpus.lfe`. Slice1's **one sanctioned
  non-mechanical edit** is re-pointing discovery at the `lfe` test-dep's bundled
  corpus (`code:lib_dir(lfe)` → `examples/` + `test/`). Named in the ledger, not
  buried.
- **SHAs are rewritten by filter-repo.** Never reference Fezzik commits by old
  hash post-import; re-locate by commit message (`--grep='A6·S0'`) and
  author-date. The `0.1.0` tag is placed in slice2 once the imported commit
  exists.

## Out of scope → later projects

- **Refined-brute (0.2.0) docs + tag** → **v0.2.0** project (arc7-rules-v2 docs;
  tag `0.2.0`). The commit it tags is already imported by this arc.
- **Namespace rename** (`r3lfe_format*` → `lfmt_fezzik*`, app `fmt` → `lfmt`)
  → v0.3.0.
- **Renderer split, hex publish, `rebar3_lfe` rewire** → v0.4.0.
- Deleting the engine from `rebar3_lfe` happens only after `lfmt` is on hex
  (v0.4.0 / slice3) — Fezzik stays live in both repos through these arcs.

## How we work (unchanged)

Peer frame; CC implements walking a ledger; CDC verifies independently
(re-runs / reads diffs and the actual DAG, not summaries); the implementer never
marks its own work verified; iteration cap 5/slice. The **Cowork sandbox cannot
mutate git** — CDC verification is read-only; any `git`/`rm` the sandbox would
need is handed to the operator. Load **collaboration-framework** (ledger
discipline) and **erlang-guidelines** (`11-anti-patterns` first). Ledger IDs in
this arc: `A7S<slice>-<row>`.

## Findings carried forward (bubbled up from slice closes)

Recorded here so slice-level discoveries are not lost between slices. Detail in
each slice's `closing-report.md`.

- **(from slice 1) Latent Unicode defect in Fezzik's inline oracle helpers.**
  `assert_idempotent` / `assert_token_preservation` / `assert_ast_equiv` flatten
  formatter output with `iolist_to_binary`, which corrupts the >127 codepoints
  the formatter emits for multibyte-UTF-8 sources (re-read → `invalid_encoding`).
  Surfaced by re-pointing the corpus at the `lfe` dep (2 files trip it:
  `core-macros.lfe`, `clj-tests.lfe`). Contained in slice 1 by restricting the
  inline-oracle corpus to 7-bit-ASCII (the sweeps, which use
  `unicode:characters_to_binary`, still cover all files). **This is neither
  import nor docs/tag work, so it does not belong to arc7-import.** Recommended
  routing: a small test-harness slice (swap `iolist_to_binary` →
  `unicode:characters_to_binary` in the inline helpers) in the **v0.3.0** rename
  line, or earlier if the operator prefers. Left for the operator/CDC to slot.
- **(from slice 1) Slice-1 gate wording — `git log --follow … back to
  `0f74364`.** Holds literally only for the **lexer** (the file present at the
  root commit); the formatter (born A3 `ce03797`) and cst (born arc2 `e3bbade`)
  `--follow` back to *their* birth commits, since a file cannot be followed
  before it existed. The DAG root for all three is `0f74364`→`c5bfc71`. Slice 2,
  when it reads history to place the `0.1.0` tag, should use this corrected
  framing rather than expecting per-module `--follow` to the root.

## Version History

- **v1.3 — 2026-06-26** (CDC, at arc close). Added the **Arc Ledger**
  composition-rows section above, retrofitting the v2.1 ledger discipline this
  arc-plan predated (the disclosed gap named in slice 1's bubble-up). No change
  to the slice breakdown or the work; this makes "the slices compose into the
  capability" *checkable* and gives `closing-report.md` rows to walk. Opened by
  CDC; gate sign-off is the operator's.
- **v1.2 — 2026-06-26** (surfaced by **slice 2** close/bubble-up). Two
  corrections to the §7a-derived slice-2 plan, neither changing the slice
  breakdown: (a) **`RESEARCH-BOOTSTRAP.md` ("bootstrap" in the slice-2 line) is
  a phantom** — it never existed in `rebar3_lfe`, so the v0.1.0 loose-file set
  is **6**, not 7; v0.2.0/arc8 should not expect it either, and migration-plan
  §7a is worth correcting. (b) **The `A6·S0` token is not a unique tag locator**
  (a "Sidecar" commit references it in-body); tag by the full message
  `Implement Arc A6·S0` → `d2e79c7`. v0.2.0/arc8 tags `0.2.0` the same way and
  should anchor on full messages. Slices 1 and 2 both delivered; arc is ready
  for formal close pending CDC verification of both.
- **v1.1 — 2026-06-26** (surfaced by **slice 1** close/bubble-up). Added the
  *Findings carried forward* section above: the inline-oracle `iolist_to_binary`
  Unicode defect (routed out of this arc, recommended for v0.3.0) and the
  corrected `--follow` framing for the slice-1 history gate. No change to the
  slice breakdown — slices 1 (history-transfer) and 2 (docs-and-tag) stand as
  planned; the bubble-up forced no re-sequencing or new arc7-import slice.
  *Disclosed gap (not changed here):* this arc-plan predates collaboration-
  framework v2.1 and lacks a formal arc-ledger composition-rows section; left
  for an explicit arc-planning pass, named so it is not a silent omission.
- **v1.0 — 2026-06-25** (initial). Arc roadmap: slices 1 (history-transfer) and
  2 (docs-and-tag); the single `filter-repo` + merge import, the `0.1.0`
  baseline, and the scope boundaries against v0.2.0/v0.3.0/v0.4.0.
