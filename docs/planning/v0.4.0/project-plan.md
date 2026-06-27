# v0.4.0 — project plan (Split, publish, integrate)

> Plan-of-record for the **v0.4.0** project: split the monolithic Fezzik
> renderer, **publish `lfmt 0.4.0` to hex.pm** (the first hex release of the
> line), and rewire `rebar3_lfe` to consume it. The capstone of the
> Fezzik-migration saga. Design reference: `workbench/fezzik-migration-plan.md`
> §6–§8.
>
> **Two firsts that raise the stakes:** this is the first project that (a)
> **publishes to hex** — an irreversible, user-facing operator action — and (b)
> spans **two repos** (`fmt` *and* `rebar3_lfe`). Composition is verified
> end-to-end (on hex, cross-repo), reconciled via **CI**.

## Base branch (operator constraint)

v0.4.0 is cut from a `main` that already carries v0.1.0 + v0.2.0 + v0.3.0 —
**now satisfied** (verified 2026-06-26: `main` has `lfmt_fezzik*`, zero `r3lfe`,
app `lfmt` v0.3.0, tags `0.1.0 < 0.2.0 < 0.3.0` ancestors of `main`). Branch
`feature/v0.4.0-release` off `main`. See `arc1-release/arc-plan.md` §Base branch.

## Definition of done, and boundaries

**v0.4.0 delivers:**

- The renderer `lfmt_fezzik.erl` **decomposed** into focused modules with clean
  acyclic layering — a **pure, behaviour-identical refactor** (`ct` unchanged).
- The **multi-engine public API**: a shared `#lfmt_opts{engine}` record, an
  `lfmt_engine` behaviour, and `lfmt:new/1` + `lfmt:format/1,2` dispatch
  (`fezzik` wired; `pe`/`pc` reserved) — the stable API surface the v0.5.0/v0.6.0
  engines slot into, shipped from the first release.
- **`lfmt 0.4.0` published to hex.pm** (`vsn` `0.4.0`, full metadata, zero
  runtime deps), tagged `0.4.0` on `main`.
- `rebar3_lfe` rewired to `{lfmt, "~> 0.4"}`, calling `lfmt_fezzik:format/1`;
  its local `r3lfe_format{ter,_cst,_lexer}` engine + suites **deleted**; `ct` +
  `test/e2e/` green against the dep.
- The carried v0.3.0 `conf_wide_sweep` hygiene closed.

**v0.4.0 explicitly does NOT:** rename `pe_*` → `lfmt_pe_*` (→ v0.5.0); touch the
`pe`/`pc` engine lines (→ v0.5.0/v0.6.0); change the `rebar3_lfe` provider's
*default-engine* behaviour (slice 3 preserves Fezzik-as-engine, just sourced
from the dep — an engine-selection flag is a separate provider-design question).

## Arc roadmap

| Arc | Capability | Status | Depends on |
|-----|-----------|--------|------------|
| `arc1-release` | `lfmt 0.4.0` split, multi-engine API, published, and consumed by `rebar3_lfe` | in progress (v2.1; **4 slices**) | consolidated `main` (v0.1.0+v0.2.0+v0.3.0) ✓ |

No imported historical arcs under v0.4.0 → numbering starts at **arc1**.

## Current status

In progress. **slice 1 (split) — CDC-closed.** Next: **slice 2 (engine-api)** —
the multi-engine API, inserted (operator direction, 2026-06-27) before the hex
release so the API ships in 0.4.0. Then slice 3 (hex-release) and slice 4
(rebar3-integration). slice 3/4 open-sets firm up after slice 2 (the tarball must
include the slice-2 modules; the rewire targets the published API).

## Project Ledger (DoD composition rows — LEDGER-DISCIPLINE Section C)

> Opens here; closes (per-row walk) in `closing-report.md`. Class-(b) reproduced
> at **project scale** — the on-hex, cross-repo end-to-end demonstration.

Definition of done: *`lfmt 0.4.0` is split (behaviour-identical), exposes the
multi-engine `lfmt:new/1` API, is on hex, and is consumed by `rebar3_lfe` with no
local engine left; `conf_wide_sweep` honest.*

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| P-1 | arc1-release closed + composed | ptr: `arc1-release/closing-report.md` | correctness | project-plan | open | | class-(a) |
| P-2 | **DoD demonstrable at project scale**: `lfmt 0.4.0` fetchable from hex; the split engine behaviour-identical (full `ct`) with clean `xref` layering; **`lfmt:new(#{engine=>fezzik})` formats** (and `pe`/`pc` reserved cleanly); `rebar3_lfe`@`{lfmt,"~>0.4"}` formats end-to-end (`ct`+`e2e`) with no `r3lfe_format*` left | project-scale demo (hex fetch + `lfmt:new/format` + cross-repo ct/e2e) + CI | serious | project-plan | open | | class-(b); reproduce at project scale |
| P-3 | findings dispositioned (conf_wide_sweep hygiene closed; any new bubble-ups) | ptr: Version History + v0.3.0 back-link | correctness | bubble-up | open | | class-(c) |

## Version History

- **v1.1 — 2026-06-27** (operator direction). Added the **multi-engine public
  API** to the DoD and inserted **`slice2-engine-api`** (shared `#lfmt_opts{}` +
  `lfmt_engine` behaviour + `lfmt:new/1` dispatch), so the API shape ships in
  0.4.0 and the v0.5.0/v0.6.0 engines slot in behind it. Slice count 3 → **4**
  (hex-release → slice 3, rebar3-integration → slice 4). Field `engine` +
  behaviour `lfmt_engine` recommended; record is `engine`-only for 0.4.0 (no
  hollow options). Slice 1 (split) is CDC-closed.
- **v1.0 — 2026-06-26** (initial; planned forward on consolidated `main`).
  Roadmap (`arc1-release`, 3 slices), DoD + boundaries, project-ledger. Carries
  in the v0.3.0 `conf_wide_sweep` hygiene (closed by arc1 slice 1). Notes the two
  firsts (hex publish; cross-repo) that make the project gate an irreversible,
  operator-run, CI-reconciled step.
