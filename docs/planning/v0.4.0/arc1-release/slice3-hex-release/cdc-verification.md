# CDC verification — v0.4.0 · arc1-release / slice3-hex-release

Verifier: Claude (Cowork chat seat, acting as CDC — independent of CC).
Date: 2026-06-27.
Reviewed: fmt `main` working tree (slice-3 app.src changes **uncommitted** per the
operator handoff). **Partial close**: CC-phase rows (A1S3-1…6) verified now; the
operator rows (publish/tag) + the hex-fetch confirmation close the slice later.

## Verification boundary

Reproduced (source/inspection) the vsn/metadata, the `exclude_files` mechanism,
deps, and the F3 disposition. The `hex build` tarball listing + `hex publish
--dry-run` are **attested by CC** (no OTP/hex in the CDC sandbox). The publish,
tag, and consumer-fetch are operator steps, verified after the fact.

## Per-row verdict

| ID | CC status | CDC verdict | Basis |
|----|-----------|-------------|-------|
| A1S3-1 | done | **reproduced** | `lfmt.app.src`: `{vsn,"0.4.0"}`, `{description,"A code formatter for LFE"}`, `{licenses,["Apache-2.0"]}`, `{links,[{"GitHub",…}]}`. (Uncommitted — commit before tagging, per handoff.) |
| A1S3-2 | done | **reproduced (mechanism) + attested (tarball)** | `src/` holds all required: `lfmt.erl`, `lfmt_engine.erl`, `lfmt_fezzik{,_cst,_lexer,_render,_util}.erl`, **both** `lfmt.hrl` + `lfmt_fezzik.hrl`, app.src. `{exclude_files,…}` *subtracts* from the default include set, so every `.hrl` stays automatically (clean approach). Actual tarball listing = CC dry-run (attested). |
| A1S3-3 | done | **reproduced + see F4** | `{exclude_files, ["priv/images", "src/pe*"]}` drops the 15 `pe_*` modules + `priv/images` (logos/`.afphoto`/its `drafts/`). **F4**: `priv/lfe-format-rules.eterm` still ships. |
| A1S3-4 | done | **reproduced** | `rebar.config` `{deps, []}` (zero runtime deps); `lfe`/`proper` are test-profile only. |
| A1S3-5 | done | **attested** | `hex publish --dry-run` clean — CC/operator run. |
| A1S3-6 | done | **reproduced** | F3 disposition confirmed: `.github/workflows/ci.yml` "Format check" is **`cargo fmt --check`** (the Rust-oracle job); there is **no erlfmt gate** on the Erlang source. The 31 long lines in `lfmt_fezzik_render` are **not** a CI/release blocker. |
| A1S3-7 | open | **operator-pending** | `rebar3 hex publish` → `lfmt 0.4.0` live. |
| A1S3-8 | open | **operator-pending** | annotated `0.4.0` tag on `main`; `0.3.0 < 0.4.0`. |
| A1S3-9 | open | **CDC-pending** | fetch `{lfmt,"~>0.4"}` from hex + compile (post-publish). |

## Findings

- **F1 — `exclude_files` is the right mechanism (endorse).** Subtracting from the
  default include set (rather than enumerating includes) means every `.hrl` and
  every future engine module stays in automatically — exactly the robust choice;
  it won't silently drop a file when the module set grows again (v0.5.0).
- **F2 — F3 (line-width) is conclusively not a release blocker (verified).** CI's
  only format gate is `cargo fmt` on the Rust oracle; the Erlang source has no
  erlfmt check. Closed.
- **F3 — the engine needs nothing from `priv/` at 0.4.0 (verified).** `grep`
  confirms no `priv_dir`/`priv/` access in `lfmt`/`lfmt_fezzik*`/`lfmt_engine`;
  `priv/lfe-format-rules.eterm` is pe's rule registry, and `pe_lfe` is excluded.
- **F4 — `priv/lfe-format-rules.eterm` ships as orphaned dead weight (CC-flagged;
  endorse + extend).** `exclude_files` drops `priv/images` but not the `.eterm`,
  so it ships at 0.4.0 with no consumer in the package (harmless, inert). Since
  **nothing** in `priv/` is needed by the 0.4.0 package (F3), the cleanest fix is
  to exclude all of `priv/`: `{exclude_files, ["priv", "src/pe*"]}`. It returns
  naturally in 0.5.0 when `pe`/the registry ship. **Minor/optional** — Duncan's
  call; not a blocker.

## Closure (partial)

**CDC accepts the slice-3 CC phase (A1S3-1…6).** vsn/metadata, the exclude
mechanism, zero-deps, and the F3 disposition are verified; the tarball + dry-run
are credibly attested. One optional hygiene rec (F4: exclude all `priv/`).

**Not yet fully closed** — operator steps remain: (1) commit `lfmt.app.src`
(+ confirm the About/Usage `README.md` is committed too — it ships in the tarball
and is the hex front page); (2) `rebar3 hex publish`; (3) tag `0.4.0` on `main`.
Then CDC fetches `{lfmt,"~>0.4"}` from hex (A1S3-9) to confirm it compiles, which
closes the slice — and unblocks the **rebar3_lfe 0.5.5** publish (its hard
dependency, per 023 F1).

Reviewed by: CDC (Cowork chat seat).
