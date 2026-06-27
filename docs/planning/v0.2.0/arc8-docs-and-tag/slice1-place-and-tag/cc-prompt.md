# CC prompt — fmt v0.2.0 · arc8-docs-and-tag / slice1-place-and-tag

You are CC. Land v0.2.0's design record + release marker: move the imported
`arc7-rules-v2` docs into `docs/planning/v0.2.0/`, remove the emptied
`docs/design/022-lfe-format/` staging dir, and tag `0.2.0` on the refined-brute
tip. **No code changes.** You run `git` directly (the Cowork sandbox can't).

## Read first

- `docs/planning/v0.2.0/project-plan.md` and
  `docs/planning/v0.2.0/arc8-docs-and-tag/arc-plan.md`.
- This slice's `slice-doc.md` and `ledger.md`.

Load **collaboration-framework** (ledger discipline).

## Precondition

Work on `feature/fezzik-import` (where v0.1.0/arc7-import lives). Confirm
`docs/design/022-lfe-format/` contains **only** `arc7-rules-v2/` before starting.

## Step 1 — move the docs (history-preserving)

```sh
git mv docs/design/022-lfe-format/arc7-rules-v2 docs/planning/v0.2.0/arc7-rules-v2
# docs/design/022-lfe-format/ should now be empty:
rmdir docs/design/022-lfe-format
git add -A docs/design/022-lfe-format 2>/dev/null || true
```

Commit, e.g. `docs: place v0.2.0 refined-brute design record (arc7-rules-v2)`.
Confirm `git log --follow docs/planning/v0.2.0/arc7-rules-v2/cc-prompt.md`
reaches its imported origin (history crossed the rename).

## Step 2 — tag 0.2.0

Locate the refined-brute tip by **full message** (short tokens are not unique —
v0.1.0 slice-2 finding):

```sh
git log --all --fixed-strings --grep='A7·S6 — gallery regen + full sweep' --oneline
```

Default target is the tip `5334ff8` (the complete refined-brute milestone). A7·S6
is docs-only; the formatter code froze at `5086e4e` (A7·S5c·fix1). **Confirm with
Duncan** which to tag (code is identical between them); default = the tip. Then:

```sh
git tag -a 0.2.0 <tip-sha> \
  -m "Fezzik: refined brute-force LFE formatter (imported rebar3_lfe A7 rules-v2)"
git show 0.2.0 | head -5
git merge-base --is-ancestor 0.1.0 0.2.0 && echo "0.1.0 < 0.2.0 ✓"
```

Source-history marker, not buildable — don't expect `rebar3 compile`.

## Gate

- `docs/planning/v0.2.0/arc7-rules-v2/` present; `--follow` reaches origin.
- `docs/design/022-lfe-format/` gone.
- `0.2.0` annotated, resolves to the chosen tip, descendant of `0.1.0`.
- `git diff --name-status <base>..HEAD` = `arc7-rules-v2` rename only; no
  `src/`/`test/`.
- `docs/planning/v0.1.0/`, `docs/planning/v0.5.0/`, `arc7-import/` untouched.

## Working ledger + close

Update `ledger.md` per-row as you work (evidence at `attested`). At close write
`closing-report.md`: the per-row walk + **bubble-up to the arc** (did slice1
deliver arc8's capability; anything the arc-plan didn't anticipate; the
silent-drop diff). Don't mark your own rows CDC-verified. Since arc8 has only
this slice, your close sets up the arc close directly.
