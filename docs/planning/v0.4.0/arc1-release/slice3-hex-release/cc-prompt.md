# CC prompt — fmt v0.4.0 · arc1-release / slice3-hex-release

You are CC. **Prepare and verify** the `lfmt 0.4.0` hex release — vsn, metadata,
tarball contents, dry-run. **Do NOT run the real `rebar3 hex publish` or create
the `0.4.0` tag** — those are irreversible/credentialed **operator** steps you
hand to Duncan. You run `git` + the toolchain directly.

Target OTP 28. Load **collaboration-framework** (ledger discipline) and
**erlang-guidelines** (`02-api-design`, `17-tooling`).

## Read first

- `docs/planning/v0.4.0/project-plan.md` and `arc1-release/arc-plan.md`.
- This slice's `slice-doc.md` (esp. §Tarball contents) and `ledger.md`.

## Base

`feature/v0.4.0-release` after slices 1–2 (the split + the `lfmt`/`lfmt_engine`
dispatch API are in; `lfmt_fezzik` + `_render` + `_util` + `.hrl`).

## Step 1 — version + metadata

`src/lfmt.app.src`: `vsn` `"0.3.0"` → **`"0.4.0"`**. Confirm `description`,
`{licenses, ["Apache-2.0"]}`, `{links, [{"GitHub", …}]}` present (staged in
v0.3.0). Keep `rebar.config` `{deps, []}`.

## Step 2 — build + INSPECT the tarball (the load-bearing check)

```sh
rebar3 hex build
```

List the tarball contents and verify:

- **Includes:** `src/lfmt_fezzik.erl`, `src/lfmt_fezzik_render.erl`,
  `src/lfmt_fezzik_util.erl`, `src/lfmt_fezzik_lexer.erl`,
  `src/lfmt_fezzik_cst.erl`, `src/lfmt.erl`, `src/lfmt.app.src`, **`src/lfmt_fezzik.hrl`**
  (critical — the modules `-include` it; without it the package won't compile
  for consumers), `LICENSE`, `README*`.
- **Excludes:** `test/`, `bench/`, `docs/`, `workbench/`, `research/`, `_build/`,
  `.github/`.

If the `.hrl` or any module is missing, fix the `{files, …}` list (or hex
include config) until the tarball is correct — this is the row most likely to
bite users.

## Step 3 — dry-run

```sh
rebar3 hex publish --dry-run
```

Confirm clean. **Stop here.**

## Step 4 — F3 (line-width) disposition

Check whether CI / `make check` enforces `erlfmt --check` (the repo already has
non-clean `pe_*` files, so likely not a gate). Record: not a release blocker, or
scope erlfmt config / wrap the 31 long lines in `lfmt_fezzik_render.erl`. Don't
run a global `rebar3 fmt` (it would touch `pe_*`).

## Operator steps (hand to Duncan — do NOT do these)

- `rebar3 hex publish` (needs `HEX_API_KEY`) → `lfmt 0.4.0` live.
- `git tag -a 0.4.0` on `main` (post-merge); verify `0.3.0 < 0.4.0`.

## Working ledger + close

Update `ledger.md` per-row for rows 1–6 (mark 7–8 as operator-pending). At close
write `closing-report.md`: the tarball file listing (includes/excludes + the
`.hrl`), the dry-run result, the F3 disposition, and the bubble-up. Don't mark
your own rows CDC-verified. The slice closes after the operator publishes + tags
and CDC fetches from hex to confirm.

## When done (CC phase)

Hand back: the vsn bump; the tarball **file listing**; the clean dry-run; the F3
disposition; the per-row ledger walk + closing-report — plus the explicit
"operator: publish + tag" handoff. Sets up slice 4 (`rebar3_lfe` integration
against the published `{lfmt, "~> 0.4"}`).
