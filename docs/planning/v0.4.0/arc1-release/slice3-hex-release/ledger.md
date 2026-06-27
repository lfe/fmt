# Slice 3: hex-release — ledger

> Per-slice verification ledger. CC prepares + self-assesses; the **publish +
> tag are operator steps**; CDC verifies (read-only fetch from hex). Implementer
> never marks its own rows CDC-verified. Iteration cap: 5. Project `v0.4.0` ·
> arc `arc1-release` · slice `slice3-hex-release`. Toolchain/publish reconcile
> via **CI / hex**.

## Ledger

> CC self-assessment (rows 1–6). Base `main` `9daf271`; the vsn bump +
> `exclude_files` live in `src/lfmt.app.src` (working tree — **uncommitted**, see
> Caveats). Rows 7–8 are **operator** steps; 9 confirms at slice 4. Every `done`
> is **proposed-done** until CDC verifies (read-only hex fetch).

| ID | Criterion | Verify | Significance | Origin | Status | Evidence | Notes |
|----|-----------|--------|--------------|--------|--------|----------|-------|
| A1S3-1 | `lfmt.app.src` `vsn` → `"0.4.0"`; metadata complete (description, licenses, links) | inspect `lfmt.app.src` | serious | slice-doc | done | `src/lfmt.app.src`: `{vsn, "0.4.0"}`, `{description, "A code formatter for LFE"}`, `{licenses, ["Apache-2.0"]}`, `{links, [{"GitHub", "https://github.com/lfe/fmt"}]}`. | metadata staged in v0.3.0 |
| A1S3-2 | tarball **includes** all engine modules + the slice-2 API + `lfmt.app.src` + **every `.hrl`** + LICENSE + README | `rebar3 hex build`; list tarball contents; cross-check vs `ls src/` | serious | slice-doc | done | Operator `hex publish --dry-run` "Included files": `src/lfmt_fezzik{,_render,_util,_lexer,_cst}.erl`, `src/lfmt.erl`, `src/lfmt_engine.erl`, `src/lfmt.app.src`, **`src/lfmt.hrl` + `src/lfmt_fezzik.hrl`**, LICENSE, NOTICE, README.md, rebar.config, rebar.lock. All required present. | both `.hrl`s confirmed |
| A1S3-3 | tarball **excludes** test/bench/docs/workbench/research/_build/.github (and the unreleased `pe_*` engine + design assets) | inspect tarball file list | serious | slice-doc | done | Dry-run list has **no** `test/`/`docs/`/`_build/`/etc. **`{exclude_files, ["priv/images", "src/pe*"]}`** in `app.src` removes the 18 `pe_*` v0.5.0 modules + `priv/images/` (incl. `hobbit-hole.afphoto`). CC's pre-exclude default build had shown **15 `pe_*` + `priv/images` leaking** — fixed. | the load-bearing catch |
| A1S3-4 | `{deps, []}` in the packaged config (zero runtime deps; `lfe` test-only doesn't leak) | inspect packaged `rebar.config` / hex metadata | serious | slice-doc | done | Dry-run "Dependencies:" **empty**. `rebar.config` `{deps, []}` (top-level); `lfe`/`proper` are test-profile-only. | |
| A1S3-5 | `rebar3 hex publish --dry-run` clean | run dry-run | serious | engineering bar | done | Operator's `rebar3 hex publish --dry-run` printed the package (name/vsn/description/files/licenses/links/build-tools) with no errors — only the standard COC notice. | CC stops here |
| A1S3-6 | F3 (31 lines >100 cols in `lfmt_fezzik_render`) confirmed not a release/CI blocker, or scoped | check CI config; disclose | polish | slice1 cdc F3 | done | `.github/workflows/ci.yml:95` "Format check" is **`cargo fmt --check`** (Rust), **not** erlfmt. No erlfmt gate on the Erlang source → the 31 long lines are **not** a release/CI blocker. Cosmetic; doesn't affect the tarball. | |
| A1S3-7 | **[operator]** `lfmt 0.4.0` live on hex.pm | `rebar3 hex publish`; hex.pm page | serious | slice-doc | **operator-pending** | dry-run clean + package verified; awaiting the credentialed `rebar3 hex publish` | irreversible; needs HEX_API_KEY |
| A1S3-8 | **[operator]** annotated `0.4.0` tag on `main`; descendant of `0.3.0` | `git show 0.4.0`; `git merge-base --is-ancestor 0.3.0 0.4.0` | serious | slice-doc | **operator-pending** | tag on `main` after the app.src edit is committed | post-publish |
| A1S3-9 | a fresh consumer can fetch `{lfmt,"~> 0.4"}` from hex and compile | scratch project pulls + compiles (or confirm at slice 4) | serious | slice-doc | **deferred → slice 4** | slice 4 (`rebar3_lfe`) consumes the published dep end-to-end | re-entry: slice 4 |
| A1S3-10 | closing report: tarball listing + publish/tag confirmation | closing-report check | serious | methodology | done | `closing-report.md` written: included-files listing, exclude mechanism, dry-run, F3, operator handoff. | |

## Amendments (CC-raised refinements)

_(none — the `pe_*`/`priv/images` exclusion is the slice-doc's "verify the
tarball contents" working as intended, not a scope change.)_

## Caveats

- **`src/lfmt.app.src` is uncommitted** (vsn `0.4.0` + `exclude_files`). It must
  be committed on `main` **before** the operator tags `0.4.0`, so
  `git checkout 0.4.0` == the published code (slice-doc requirement). Flagged for
  the operator (who owns the publish/tag).
- **`priv/lfe-format-rules.eterm` ships** in the 0.4.0 tarball (only `priv/images`
  is excluded). It is consumed by `pe_lfe` (which is *not* shipped at 0.4.0), so
  it is currently inert in the package — small, harmless, and a reasonable
  canonical-rules artifact to carry forward. Disclosed, not a blocker.
- **Exclude lives in `app.src`** (`{exclude_files, …}`), not `rebar.config`
  `{files, …}` — operator's choice; it subtracts from the default include set
  (keeps every `.hrl` automatically) rather than re-listing everything.

## What Worked

- **Inspecting the *default* tarball before configuring anything.** Listing the
  no-exclude build surfaced the real leaks — 15 `pe_*` modules **and**
  `priv/images/` (a multi-MB `.afphoto`) — which a "does it include the modules?"
  check alone would have missed. The exclude then had a precise target.

## Closure

CC phase complete: rows 1–6 **done**; 7–8 **operator-pending** (publish + tag);
9 **deferred to slice 4** (consumer fetch); 10 **done**. Total rows: 10. CC
self-assessment only — **CDC verification pending** (read-only hex fetch after
publish). The slice closes once the operator publishes + tags and CDC confirms.
Operator handoff is explicit in `closing-report.md`.
