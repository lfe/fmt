# CC prompt — fmt v0.1.0 · arc7-import / slice2-docs-and-tag

You are CC. With the Fezzik engine imported (slice1), this slice **establishes
v0.1.0's design record and release marker**: relocate the imported arc1–6 design
docs (+ loose spec files) into `docs/planning/v0.1.0/`, and tag `0.1.0` on the
imported `A6·S0` commit. **No code changes.** Leave `arc7-rules-v2` alone — it's
the v0.2.0 project's.

You operate in the real environment and run `git` directly (the Cowork sandbox
can't mutate git; you can).

## Read first

- `docs/planning/v0.1.0/arc7-import/arc-plan.md`.
- This slice's `slice-doc.md` and `ledger.md`.
- `workbench/fezzik-migration-plan.md` §7a (the doc-split map) and §4 (tags).

Load **collaboration-framework** (ledger discipline).

## Precondition

`slice1-history-transfer` is merged on `feature/fezzik-import`, so
`docs/design/022-lfe-format/` exists in `fmt` and the `A6·S0` commit is in the
DAG. Work on that same branch.

## Step 1 — move the v0.1.0 docs (history-preserving)

`git mv` each path; do **not** copy+delete (that breaks `--follow`).

```sh
cd <fmt worktree on feature/fezzik-import>
mkdir -p docs/planning/v0.1.0
SRC=docs/design/022-lfe-format
for d in arc1-lexer arc2-cst arc3-printer arc4-indent arc5-provider arc6-release; do
  git mv "$SRC/$d" "docs/planning/v0.1.0/$d"
done
for f in cc-prompt-gallery.md cc-prompts.md formatting-gallery.md \
         formatting-rules.md rebar3-lfe-provider.md RESEARCH-BOOTSTRAP.md SMOKE.md; do
  git mv "$SRC/$f" "docs/planning/v0.1.0/$f"
done
```

Do **not** move `arc7-rules-v2/` and do **not** remove `$SRC` — `arc7-rules-v2`
stays there for the v0.2.0 project, which empties and removes `$SRC`.

Commit the moves (one commit), e.g.
`docs: place v0.1.0 Fezzik design record (arc1-6 + spec)`.

## Step 2 — tag 0.1.0

Locate the imported `A6·S0` commit by message (its hash was rewritten by
filter-repo):

```sh
git log --all --grep='A6·S0' --oneline
```

Confirm a **single** match and that it is
*"Implement Arc A6·S0 — e2e CLI test + fix bare-provider app discovery"*. Then:

```sh
git tag -a 0.1.0 <that-sha> \
  -m "Fezzik: first usable brute-force LFE formatter (imported from rebar3_lfe A6·S0)"
git show 0.1.0 | head -5   # verify it points where you think
```

This is a source-history marker, not a buildable release — don't expect it to
`rebar3 compile` (the imported commit has no `app.src`).

## Gate

- Six `arcN-*` dirs + seven loose files present under `docs/planning/v0.1.0/`;
  `git log --follow docs/planning/v0.1.0/formatting-rules.md` reaches its
  `rebar3_lfe` origin.
- `arc7-rules-v2/` still under `docs/design/022-lfe-format/`.
- `0.1.0` resolves to the unique `A6·S0` commit (`git show 0.1.0`).
- `git diff --stat <base>..HEAD` shows **only** doc renames — zero `src/` /
  `test/` changes.
- `docs/planning/v0.5.0/` and `docs/planning/v0.1.0/arc7-import/` untouched.

## Working ledger

Update `ledger.md` as you work. Every row reaches `done`/`deferred`/`no-op`;
`done` needs command-output evidence. Don't mark your own rows CDC-verified.

## When done

Hand back: the moves committed; the `0.1.0` tag + resolved SHA and its commit
message; the final `docs/planning/v0.1.0/` listing; the per-row ledger walk;
confirmation `arc7-rules-v2` remains for v0.2.0.
