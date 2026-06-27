# Slice 1: place-and-tag

> Project: `v0.2.0`
> Arc: `arc8-docs-and-tag`
> Slice: `slice1-place-and-tag`
> Status: planned for CC
> Prior: `v0.1.0/arc7-import` (import + 0.1.0 baseline) — must be merged/present

## Purpose

Land v0.2.0's design record and release marker: relocate the imported
`arc7-rules-v2` design docs into `docs/planning/v0.2.0/`, remove the now-empty
`docs/design/022-lfe-format/` staging dir (completing the doc-split begun in
v0.1.0/slice2), and create the `0.2.0` tag on the refined-brute tip.

Docs + one tag + one dir removal. **No code changes.**

## Scope

In scope:

- `git mv docs/design/022-lfe-format/arc7-rules-v2` →
  `docs/planning/v0.2.0/arc7-rules-v2` (history-preserving).
- Remove the emptied `docs/design/022-lfe-format/` directory.
- Create the annotated `0.2.0` tag on the refined-brute tip.

Out of scope: import (v0.1.0); rename (v0.3.0); build/split/publish (v0.4.0);
the README pointer to the living spec (non-gating follow-up).

## Precondition

Runs on `feature/fezzik-import` after `v0.1.0/arc7-import` is present, so
`docs/design/022-lfe-format/` contains exactly `arc7-rules-v2/` (verified at
v0.1.0/slice2 close) and the refined-brute tip is in the DAG.

## The move

| from | to |
|---|---|
| `docs/design/022-lfe-format/arc7-rules-v2/` | `docs/planning/v0.2.0/arc7-rules-v2/` |

After the move, `docs/design/022-lfe-format/` is empty → remove it. (This is the
last of the doc-split; v0.1.0/slice2 placed arc1-6 + the loose files.)

## The tag

- `0.2.0`, annotated, on the **refined-brute tip** `5334ff8` *"A7·S6 — gallery
  regen + full sweep"* (rewritten `rebar3_lfe` `4a509c1` — the last imported
  Fezzik commit). Locate by **full message**
  (`git log --all --fixed-strings --grep='A7·S6 — gallery regen + full sweep'`),
  not a short token (`A7·S6`/`A6·S0`-style tokens are not unique — v0.1.0
  slice-2 finding).
- **Operator decision (confirm before tagging):** A7·S6 is docs-only; the
  formatter code froze at `5086e4e` (A7·S5c·fix1). Default = the tip `5334ff8`
  (complete milestone); alternative = `5086e4e` (newest formatter-code commit).
  Code is identical between them. See arc-plan §Scope detail.
- Verify `0.2.0` is a **descendant of `0.1.0`** so the tags are DAG-ordered.
- A source-history marker, not buildable (the commit carries only engine files).

## Success criteria

- `docs/planning/v0.2.0/arc7-rules-v2/` present; `git log --follow` on a sampled
  file reaches its imported origin.
- `docs/design/022-lfe-format/` no longer exists.
- `0.2.0` annotated tag resolves to the chosen refined-brute tip (located by full
  message); `git merge-base --is-ancestor 0.1.0 0.2.0` succeeds.
- `git diff --stat` for the slice = the `arc7-rules-v2` rename only (+ the dir
  removal); zero `src/`/`test/` changes.
- `docs/planning/v0.1.0/`, `docs/planning/v0.5.0/`, and `arc7-import/` untouched.

## Handoff

CC provides: the move committed (history-preserving `git mv`); the `0.2.0` tag +
resolved SHA and full commit message; confirmation the staging dir is gone and
the tag is a descendant of `0.1.0`; a per-row ledger walk; the
`closing-report.md` (per-row walk + bubble-up to the arc).
