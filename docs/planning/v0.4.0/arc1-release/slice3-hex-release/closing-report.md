# Slice 3: hex-release — closing report (CC phase)

> CC closing report for the **prepare + verify** phase. The **publish + tag are
> operator steps** (irreversible/credentialed); CDC verifies read-only by
> fetching from hex after publish. Every `done` is **proposed-done** until then.
> Project `v0.4.0` · arc `arc1-release` · slice `slice3-hex-release`. Base `main`
> `9daf271`; vsn + exclude live in `src/lfmt.app.src` (uncommitted — see below).

## Per-row walk

10 rows; CC owns 1–6, operator 7–8, slice 4 confirms 9, CC writes 10.

| ID | Status | Evidence (summary) |
|----|--------|--------------------|
| A1S3-1 | done | `lfmt.app.src` `vsn "0.4.0"` + description/Apache-2.0/GitHub link. |
| A1S3-2 | done | Dry-run includes all 6 engine modules + `lfmt.erl`/`lfmt_engine.erl` + app.src + **both `.hrl`** + LICENSE/NOTICE/README. |
| A1S3-3 | done | No test/docs/_build; `{exclude_files,["priv/images","src/pe*"]}` drops `pe_*` + `priv/images` (CC's default build had shown them leaking). |
| A1S3-4 | done | Dry-run "Dependencies:" empty; `{deps,[]}`. |
| A1S3-5 | done | Operator `hex publish --dry-run` clean. |
| A1S3-6 | done | CI "Format check" is `cargo fmt` (Rust); no erlfmt gate → F3 not a blocker. |
| A1S3-7 | operator-pending | awaiting `rebar3 hex publish`. |
| A1S3-8 | operator-pending | awaiting `0.4.0` tag on `main`. |
| A1S3-9 | deferred → slice 4 | consumer fetch confirmed when `rebar3_lfe` pulls the dep. |
| A1S3-10 | done | this report. |

**CC phase: rows 1–6 done; 7–8 operator; 9 slice-4; 10 done.** No amendments.

## Bubble-up to the arc (arc1-release)

### 1. Did the CC phase deliver its assigned piece?

Yes. The arc-plan slice-3 row (CC half): *vsn → 0.4.0 + complete metadata; build +
inspect the tarball (all `src/` modules + every `.hrl` + app.src + LICENSE);
exclude test/bench/docs cruft; `{deps,[]}`; dry-run clean*. All verified. The
tarball is correct and the dry-run is clean; only the irreversible publish + tag
remain (operator).

### 2. What did the CC phase reveal that the plan did not fully anticipate

- **The default package leaked more than dev cruft.** Beyond the test/docs the
  plan named, the no-exclude tarball shipped the **18 `pe_*` v0.5.0 modules** and
  **`priv/images/`** (logos + a multi-MB `hobbit-hole.afphoto` Affinity source).
  Caught by listing the default build; fixed with
  `{exclude_files, ["priv/images", "src/pe*"]}` in `app.src`. The plan's
  "verify tarball contents" step earned its place.
- **`priv/lfe-format-rules.eterm` still ships** (only `priv/images` excluded) —
  inert at 0.4.0 (its consumer `pe_lfe` isn't shipped); disclosed, harmless.

### 3. The silent-drop diff at slice scale (CC phase)

- **Specified → delivered:** vsn + metadata ✓; tarball includes all modules +
  both `.hrl` + LICENSE/README ✓; excludes cruft (+`pe_*`/images) ✓; `{deps,[]}` ✓;
  dry-run clean ✓; F3 disposition ✓.
- **Operator-pending (not dropped):** publish (7), tag (8).
- **Deferred-with-re-entry:** consumer fetch (9) → slice 4.
- **Silent drops: none.**

## OPERATOR HANDOFF (Duncan) — do these to finish the slice

1. **Commit `src/lfmt.app.src`** (vsn `0.4.0` + `exclude_files`) on `main` — so the
   `0.4.0` tag lands on a commit that already carries the release version + exclude.
2. **`rebar3 hex publish`** (needs `HEX_API_KEY`) → `lfmt 0.4.0` live on hex.pm.
3. **`git tag -a 0.4.0`** on `main` (the commit from step 1); verify
   `git merge-base --is-ancestor 0.3.0 0.4.0`.
4. (push `main` + tags when ready.)

CC did **not** run publish or create the tag. The slice closes once 2–3 are done
and CDC fetches `{lfmt, "~> 0.4"}` from hex to confirm it compiles.

## Open items for CDC / operator

- **`cdc-verification.md` pending** — after publish: fetch `lfmt 0.4.0` from hex,
  confirm the tarball matches (both `.hrl`, no `pe_*`/images), and that
  `0.4.0` resolves on `main` as a descendant of `0.3.0`.
- Next: `slice4-rebar3-integration` — rewire `rebar3_lfe` onto `{lfmt, "~> 0.4"}`
  (which also satisfies A1S3-9 end-to-end).
