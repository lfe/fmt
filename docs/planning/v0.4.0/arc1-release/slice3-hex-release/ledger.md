# Slice 3: hex-release — ledger

> Per-slice verification ledger. CC prepares + self-assesses; the **publish +
> tag are operator steps**; CDC verifies (read-only fetch from hex). Implementer
> never marks its own rows CDC-verified. Iteration cap: 5. Project `v0.4.0` ·
> arc `arc1-release` · slice `slice3-hex-release`. Toolchain/publish reconcile
> via **CI / hex**.

## Ledger

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S3-1 | `lfmt.app.src` `vsn` → `"0.4.0"`; metadata complete (description, licenses, links) | inspect `lfmt.app.src` | serious | slice-doc | open | | metadata staged in v0.3.0 |
| A1S3-2 | `rebar3 hex build` tarball **includes** all engine modules + the slice-2 API (`lfmt.erl` dispatch + `lfmt_engine.erl` behaviour) + `lfmt.app.src` + **every `.hrl`** (`lfmt_fezzik.hrl` + the `#lfmt_opts{}` header) + LICENSE + README | `rebar3 hex build`; list tarball contents; cross-check vs `ls src/` | serious | slice-doc | open | | the `.hrl`s are critical (modules `-include` them); module set grew in slice 2 |
| A1S3-3 | tarball **excludes** test/bench/docs/workbench/research/_build/.github | inspect tarball file list | serious | slice-doc | open | | no internal/dev cruft |
| A1S3-4 | `{deps, []}` in the packaged config (zero runtime deps; `lfe` test-only doesn't leak) | inspect packaged `rebar.config` / hex metadata | serious | slice-doc | open | | |
| A1S3-5 | `rebar3 hex publish --dry-run` clean | run dry-run | serious | engineering bar | open | | CC stops here |
| A1S3-6 | F3 (31 lines >100 cols in `lfmt_fezzik_render`) confirmed not a release/CI blocker, or scoped | check CI config / `make check`; disclose | polish | slice1 cdc F3 | open | | cosmetic; doesn't affect tarball |
| A1S3-7 | **[operator]** `lfmt 0.4.0` live on hex.pm | `rebar3 hex publish`; `mix hex.info lfmt` / hex.pm page | serious | slice-doc | open | | irreversible; needs HEX_API_KEY |
| A1S3-8 | **[operator]** annotated `0.4.0` tag on `main`; descendant of `0.3.0` | `git show 0.4.0`; `git merge-base --is-ancestor 0.3.0 0.4.0` | serious | slice-doc | open | | tag on main post-merge |
| A1S3-9 | a fresh consumer can fetch `{lfmt,"~> 0.4"}` from hex and compile | scratch project pulls + compiles (or confirm at slice 4) | serious | slice-doc | open | | proves the tarball is usable |
| A1S3-10 | closing report: tarball listing + publish/tag confirmation | closing-report check | serious | methodology | open | | |

## Amendments (CC-raised refinements)

_(none yet)_

## Caveats

_(CC fills at close.)_

## What Worked

_(CC fills at close.)_

## Closure

_(CC prepares (rows 1–6); operator completes 7–8; CDC verifies + closes. As this
is not arc1's last slice, slice 4 (rebar3-integration) follows.)_
