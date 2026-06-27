# Slice 3: hex-release

> Project: `v0.4.0`
> Arc: `arc1-release`
> Slice: `slice3-hex-release`
> Status: planned for CC (+ operator publish step)
> Prior: `slice2-engine-api` (CDC-closed) · Next: `slice4-rebar3-integration`

## Purpose

Publish **`lfmt 0.4.0` to hex.pm** — the first hex release of the line. Set the
version, verify the package *contents* (the part that bites users), dry-run, then
the operator runs the irreversible `hex publish` + tags `0.4.0` on `main`.

## The irreversibility split (read first)

`hex publish` is **irreversible and credentialed** — an **operator** action. So
this slice is two phases:

- **CC (prepare + verify):** vsn bump, metadata, `rebar3 hex build`, **tarball
  contents inspection**, `rebar3 hex publish --dry-run`. CC stops here.
- **Operator (Duncan):** `rebar3 hex publish` (needs `HEX_API_KEY`) + `git tag
  -a 0.4.0` on `main` post-merge. CDC then verifies read-only by fetching from
  hex.

## Scope

In scope:

- `src/lfmt.app.src`: `vsn` `0.3.0` → **`0.4.0`**; confirm `description`,
  `{licenses, ["Apache-2.0"]}`, `{links, …}` present (staged in v0.3.0).
- `rebar3 hex build` and **verify the tarball contents** (below).
- `rebar3 hex publish --dry-run` clean.
- Confirm the F3 line-width item is not a release blocker (or scope it).

Out of scope: `rebar3_lfe` rewire (slice 4); any code change to the engine
(slices 1–2 are done — slice 3 is packaging only).

## Tarball contents — the load-bearing check

A consumer gets exactly what's in the tarball, so verify it explicitly:

**Must include:** the Fezzik engine modules (`lfmt_fezzik.erl`,
`lfmt_fezzik_render.erl`, `lfmt_fezzik_util.erl`, `lfmt_fezzik_lexer.erl`,
`lfmt_fezzik_cst.erl`); the **slice-2 API** (`lfmt.erl` — now the dispatch, not a
stub — and `lfmt_engine.erl`, the behaviour); `src/lfmt.app.src`; **and
critically every `.hrl` the modules `-include`** — `src/lfmt_fezzik.hrl` *and*
the slice-2 opts header (`src/lfmt.hrl` or wherever the `#lfmt_opts{}` record
lives) — omit one and the package won't compile for anyone; plus `LICENSE` and
`README`. (Confirm the exact module/hrl set against `src/` at build time — it
grew in slice 2.)

**Must exclude:** `test/`, `bench/`, `docs/` (incl. `docs/planning/`),
`workbench/`, `research/`, `_build/`, `.github/` — internal/dev cruft.

`rebar.config` must keep **`{deps, []}`** (zero runtime deps — `lfe` is
test-only and must not leak into the package's deps).

## Dependency / base

`feature/v0.4.0-release` after slice 1 (the split). The `0.4.0` tag goes on
`main` once this branch merges (per the branch/merge strategy) so
`git checkout 0.4.0` == the published code.

## Success criteria (gate)

- `lfmt.app.src` `vsn` = `"0.4.0"`, metadata complete.
- `rebar3 hex build` tarball includes the six modules + `lfmt.erl` +
  `lfmt.app.src` + **`lfmt_fezzik.hrl`** + `LICENSE` + `README`, and **excludes**
  test/bench/docs/workbench/research/_build/.github.
- `{deps, []}` in the packaged config.
- `rebar3 hex publish --dry-run` clean.
- **[operator]** `lfmt 0.4.0` live on hex.pm; **[operator]** annotated `0.4.0`
  tag on `main`, `git merge-base --is-ancestor 0.3.0 0.4.0`.
- A fresh consumer can fetch `{lfmt, "~> 0.4"}` from hex and compile it
  (proves the tarball is usable — can be confirmed at slice 4, which actually
  consumes it).
- F3 (erlfmt 31 long lines) confirmed not a release blocker, or scoped.

## Handoff

CC provides: the vsn bump; the `hex build` tarball **file listing** (showing the
includes/excludes, esp. the `.hrl`); the clean dry-run; the F3 disposition; a
per-row ledger walk + `closing-report.md`. CC does **not** run the real
`hex publish` or create the tag — those are flagged for the operator, and the
slice closes once they're done + CDC-fetched.
