# CC prompt — fmt v0.3.0 · arc1-rename / slice1-namespace-rename

You are CC. The **pure, mechanical** rename: bring the imported Fezzik engine
under the `lfmt_` namespace and rename the OTP app `fmt` → `lfmt`. **No logic
changes** — the diff must read as "names only." The carried Unicode harness fix
is slice 2; do **not** touch it here. You run `git` + the toolchain directly.

Target OTP 28. Load **collaboration-framework** (ledger discipline) and
**erlang-guidelines** (`11-anti-patterns`, `17-tooling`).

## Read first

- `docs/planning/v0.3.0/project-plan.md` and `arc1-rename/arc-plan.md`.
- This slice's `slice-doc.md` (the full rename map) and `ledger.md`.

## Base branch

Branch `feature/v0.3.0-namespace` off whichever carries the imported
`r3lfe_format*` modules: **`main` if `feature/fezzik-import` (v0.1.0+v0.2.0) has
already been merged there; otherwise off `feature/fezzik-import`.** Either is
fine for *this* slice — the operator's hard constraint is only that **all of
v0.1.0–v0.3.0 land on `main` before the v0.4.0 branch is cut** (see
`v0.4.0/arc1-release/arc-plan.md`), not where v0.3.0 itself is based. **Confirm
the base with Duncan** before starting.

## Step 1 — rename modules, suites, data dir

`git mv` each (history follows); update `-module(...)` in each. Per the map in
`slice-doc.md`: `r3lfe_format_lexer`→`lfmt_fezzik_lexer`,
`r3lfe_format_cst`→`lfmt_fezzik_cst`, `r3lfe_formatter`→`lfmt_fezzik`, the three
`*_SUITE` files, and the `_SUITE_data` dir to match the CT
`<suite>_SUITE_data` convention.

## Step 2 — update every cross-reference

`r3lfe_format_lexer:`→`lfmt_fezzik_lexer:`, `r3lfe_format_cst:`→`lfmt_fezzik_cst:`,
`r3lfe_formatter:`→`lfmt_fezzik:`, and `-type r3lfe_format_cst:cst_node()`→
`lfmt_fezzik_cst:cst_node()`. The `-ifdef(TEST). -export([regime/2]).` and
`-dialyzer({no_underspecs, format/1}).` attributes carry into `lfmt_fezzik`.
**End state: `grep -rn r3lfe src test` is empty.**

## Step 3 — rename the OTP app fmt → lfmt (repo-wide)

- `git mv src/fmt.app.src src/lfmt.app.src`; `{application, lfmt, [...]}`; set
  `vsn` `"0.3.0"`.
- `git mv src/fmt.erl src/lfmt.erl`; `-module(lfmt)`.
- **Hunt app-name references** the rename must follow: `grep -rn '\bfmt\b' src
  test rebar.config` — handle any `application:ensure_all_started(fmt)` /
  `application:get_env(fmt, …)`, CT/test config naming the app, relx stanzas.
  The app contains **both** `pe_*` and Fezzik, so this is a repo-wide app
  rename — but **do not edit any `pe_*` module source** (only the shared
  app.src / app-name references).

## Step 4 — stage hex metadata (do NOT publish)

In `lfmt.app.src`: `{licenses, ["Apache-2.0"]}`, `{links, [{"GitHub",
"https://github.com/lfe/fmt"}]}`. In `rebar.config`: add `rebar3_hex` to
`project_plugins`. Keep `{deps, []}`. **No `rebar3 hex publish`** — that's v0.4.0.

## Engineering bar

- `grep -rn r3lfe src test` → empty.
- `rebar3 compile` zero warnings; `rebar3 ct` green (the v0.1.0 ASCII
  restriction is still present — **leave it**, slice 2 removes it); `rebar3
  xref` clean; `rebar3 dialyzer` clean.
- `git diff -- 'src/pe_*.erl' docs/planning/v0.5.0` → empty.
- The `lfmt_fezzik.erl` diff is identifier-level only (no function-body changes).
- **No `0.3.0` tag** (created at arc completion, after slice 2).

## Working ledger + close

Update `ledger.md` per-row (evidence at `attested`; toolchain rows note "CI
reconciles"). At close write `closing-report.md`: per-row walk + **bubble-up to
the arc** (did slice1 deliver the namespace; anything unexpected — e.g. an
app-name reference that made it more than names-only; the silent-drop diff).
Don't mark your own rows CDC-verified.

## When done

Hand back: the rename committed; green compile/ct/xref/dialyzer; the empty
`grep -rn r3lfe`; the `pe_*` no-touch diff; the per-row ledger walk +
closing-report. Leave the harness fix and the `0.3.0` tag for slice 2 / arc
close.
