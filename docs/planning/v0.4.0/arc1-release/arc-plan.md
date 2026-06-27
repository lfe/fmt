# arc1-release — plan

> The arc that turns the namespaced-but-monolithic Fezzik engine into a
> **published, depended-upon library**: split the 1869-line renderer into
> focused modules, publish `lfmt` `0.4.0` to hex.pm, and rewire `rebar3_lfe` to
> consume it (deleting its now-duplicated local copy). This is the **first
> buildable, publishable tag** in the line. Project: **v0.4.0**. One arc, three
> slices (split → publish → integrate) — provisional grouping; we re-assess
> granularity when we arrive. Master reference:
> `workbench/fezzik-migration-plan.md` §6, §7, §8.

## Base branch (operator constraint — 2026-06-26)

**All v0.4.0 work is cut from `main`, and `main` must already have
v0.1.0 + v0.2.0 + v0.3.0 merged into it before the branch is created.** This is
a hard precondition: when `lfmt 0.4.0` is published to hex, users get what's on
`main`, so `main` must be the real, complete code — not a feature branch.
Concretely, before starting any slice here: confirm `git log main` contains the
import (v0.1.0/v0.2.0) **and** the rename + harness fix (v0.3.0), and that the
`0.1.0`/`0.2.0`/`0.3.0` tags are ancestors of `main`. Then branch
`feature/v0.4.0-release` off `main`. (A working branch is fine; the constraint is
the *base*, not working directly on `main`.)

## Why this arc

By the end of v0.3.0, `lfmt` is a clean, namespaced, green project — but the
renderer is a single 1869-line module and nothing depends on the package yet.
This arc closes the loop the whole migration was for: a standalone `lfmt` on
hex that `rebar3_lfe` (and anyone else) can pull in, with the formatter engine
living in exactly one place. Three distinct capabilities, each independently
verifiable, hence three slices behind one release banner.

## Slice breakdown

| # | Slice | Delivers | Gate |
|---|-------|----------|------|
| 1 | **split** | decompose `lfmt_fezzik.erl` into focused modules along the existing section banners (proposal: `lfmt_fezzik` = public API + regime classification + document-level dispatch; `lfmt_fezzik_render` = break-preserving / flat / classified-broken renderers; `lfmt_fezzik_clause` = clause + defform + head-classification; `lfmt_fezzik_data` = cons-dot + map k/v + data-container layout) | **pure refactor** — `rebar3 ct` byte-identical formatter behaviour (idempotence + token-preservation suites green); `rebar3 xref` confirms a clean acyclic layering (`lexer → cst → {data, clause} → render → fezzik`); zero-warning compile; dialyzer clean. Any seam that mutual recursion won't allow is **disclosed and merged**, not forced |
| 2 | **hex-release** | `lfmt.app.src` `vsn` → `"0.4.0"` + complete hex metadata; `rebar3_hex` wired; `rebar3 hex build` tarball inspected; `rebar3 hex publish` | `lfmt 0.4.0` live on hex.pm; tarball contains `src/` + app.src + LICENSE and **excludes** test/bench/docs cruft; tag `0.4.0` on the release commit; `rebar.config` still `{deps, []}` (zero runtime deps) |
| 3 | **rebar3-integration** | in `rebar3_lfe`: add `{lfmt, "~> 0.4"}`; rewire `r3lfe_prv_format` to call `lfmt_fezzik:format/1`; **delete** the local `r3lfe_format{ter,_cst,_lexer}.erl` + their three suites + the lexer data dir; bump + release `rebar3_lfe` | `rebar3 ct` green in `rebar3_lfe` — the **provider suite + `test/e2e/`** now exercise the external `lfmt` end-to-end (proving the dependency edge); no `r3lfe_format*` engine code remains; `rebar3_lfe`'s CLAUDE.md safety gates untouched (this is a dep swap, not a wrapper-flag change) |

**Dependency ordering:** slice2 needs slice1 (publish a clean surface, not a
monolith); slice3 needs `lfmt` resolvable at `~> 0.4` — develop/verify against a
`{lfmt, {git, …}}` or path dep if useful, but the **closing gate uses the hex
dep**. slice3 is the only slice that touches a second repo (`rebar3_lfe`); CC
operates there too.

**Carried hygiene (rides in slice 1):** the v0.3.0 follow-up — `conf_wide_sweep`
flattens with `iolist_to_binary` and so silently *skips* the 2 multibyte files —
is folded into slice 1 as a **separate, test-only commit** (swap its flatten to
`fmt_output_bin`). It is kept distinct from the split commit so the split stays a
*pure src refactor*; it is not its own slice (far less than one slice's worth,
per the collapse rule). Tracked as arc-ledger row A1-5.

## The split is a proposal, not a settled boundary (slice1)

The four-module decomposition above follows the section banners in the current
`lfmt_fezzik.erl` (regime classification ~L39, document layout ~L83,
break-preserving renderer ~L224, cons-dot/map helpers ~L455–840, clause/defform/
head-classification ~L841–1075, classified-broken ~L1062, flat ~L1677). The
renderer and the clause/data helpers are **likely mutually recursive**; slice1
must confirm a clean layering with `xref` *before* committing the boundaries.
Where recursion crosses a proposed seam, the honest move is to keep that
recursion inside one module (or thread it through `lfmt_fezzik` as orchestrator)
and **disclose the merged boundary** — not to introduce indirection purely to
honour a guessed split. The gate is "behaviour identical + layering clean," not
"exactly four modules."

## Arc Ledger (composition rows — LEDGER-DISCIPLINE Section B)

> Opens here; closes (per-row walk) in `closing-report.md`. Class-(b) is
> *reproduced at arc scale* — the cross-repo, on-hex end-to-end demonstration —
> never inherited from the slices.

Capability: *`lfmt 0.4.0` is a published, split, depended-upon library — the
Fezzik engine lives in exactly one place (`lfmt` on hex), `rebar3_lfe` consumes
it, and the engine is decomposed into focused modules with clean layering.*

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1-1 | slice 1 (split) closed | ptr: `slice1-split/cdc-verification.md` | correctness | arc-plan | open | | class-(a) |
| A1-2 | slice 2 (hex-release) closed | ptr: `slice2-hex-release/cdc-verification.md` | correctness | arc-plan | open | | class-(a) |
| A1-3 | slice 3 (rebar3-integration) closed | ptr: `slice3-rebar3-integration/cdc-verification.md` | correctness | arc-plan | open | | class-(a) |
| A1-4 | **composes**: `lfmt 0.4.0` resolvable on hex; the split engine is behaviour-identical (full `ct` green) with clean acyclic layering; `rebar3_lfe` formats via the `{lfmt,"~>0.4"}` dep with **no** local `r3lfe_format*` engine left — demonstrable end-to-end | arc-scale demo: hex fetch + `rebar3_lfe` `ct`/`e2e` against the dep + `xref` layering | serious | arc-plan | open | | class-(b); reproduce at arc scale (CI + hex + cross-repo) |
| A1-5 | carried v0.3.0 `conf_wide_sweep` hygiene closed (disposition = slice 1, separate commit) | ptr: slice1 cdc + v0.3.0 closing-report back-link | polish | bubble-up | open | | class-(c) — closes the v0.3.0 carry-out |

## Out of scope → later projects

- **`pe` line** (the pretty-expressive engine, its own arcs) → v0.5.0.
- **`pc` line** (pretty-canny) → v0.6.0.
- **`pe_*` → `lfmt_pe_*`** namespace pass → v0.5.0.
- Choosing `lfmt` as the *default* formatter behind the `rebar3_lfe` provider
  (vs. an engine-selection flag) is a provider-design question for `rebar3_lfe`,
  not this arc — slice3 preserves current behaviour (Fezzik is the engine), just
  sourced from the dep.

## How we work (unchanged)

Peer frame; CC implements walking a ledger; CDC verifies independently
(re-runs / reads diffs, including the cross-repo `rebar3_lfe` diff in slice3);
implementer never marks its own work verified; iteration cap 5/slice. Sandbox
cannot mutate git or publish — hand the operator any `git`/`rm`/`hex publish`;
CDC verifies the published tarball + tags read-only. Load
**collaboration-framework** + **erlang-guidelines** (`11-anti-patterns`,
`02-api-design`, `15-testing`, `17-tooling`). Ledger IDs: arc-ledger `A1-<row>`;
slice ledgers `A1S<slice>-<row>`.

## Version History

- **v1.2 — 2026-06-27** (surfaced by **slice 1** close/bubble-up). Recorded the
  split's realized shape: the proposed 4-module render/clause/data decomposition
  is **infeasible** (one 23-function mutually-recursive SCC), so slice 1 delivered
  a **3-module** split — `lfmt_fezzik` (orchestrator), `lfmt_fezzik_render` (the
  core SCC), `lfmt_fezzik_util` (leaf helpers) — plus a shared `lfmt_fezzik.hrl`.
  Behaviour-identical (byte-identical 32-file corpus golden). **Slice 2 must
  package this module set** (`lfmt_fezzik{,_render,_util,_lexer,_cst}` + the
  `.hrl`) in the hex tarball. Arc-ledger row **A1-5** (carried v0.3.0
  `conf_wide_sweep` hygiene) **closed**. No re-sequencing; slice breakdown
  (split → publish → integrate) stands.
- **v1.1 — 2026-06-26** (CDC, planning v0.4.0 forward, on consolidated `main`).
  Brought the plan to collaboration-framework v2.1: added the **Arc Ledger**
  composition rows (incl. the cross-repo/on-hex class-(b) demonstration), and
  **folded the carried v0.3.0 `conf_wide_sweep` hygiene** into slice 1 as a
  separate test-only commit (row A1-5) rather than a standalone slice (collapse
  rule). Slice breakdown unchanged (split → publish → integrate); the
  three-slice grouping stays provisional pending slice-1's split outcome.
- **v1.0 — 2026-06-25** (initial). Three-slice release arc (split / hex-release /
  rebar3-integration) + the §Base-branch operator constraint (v0.4.0 cut from a
  `main` carrying v0.1.0+v0.2.0+v0.3.0) + the split-is-a-proposal caution.
