# Slice 2: docs-and-tag

> Project: `v0.1.0`
> Arc: `arc7-import`
> Slice: `slice2-docs-and-tag`
> Status: planned for CC
> Prior slice: `slice1-history-transfer` (must be merged first)
> Next: `v0.2.0/arc8-docs-and-tag` (the arc7 docs + `0.2.0` tag)

## Purpose

Establish v0.1.0's **design record** and its **release marker**: relocate the
imported brute-formatter design docs for arcs 1–6 (plus the loose spec/gallery/
bootstrap/smoke files) into the `docs/planning/v0.1.0/` tree, and create the
`0.1.0` tag on the imported first-usable-brute commit (`rebar3_lfe`'s `A6·S0`).

This slice moves docs and creates one tag. It changes **no code**. It leaves
`arc7-rules-v2` untouched — that belongs to the separate `v0.2.0` project.

## Scope

In scope:

- `git mv` the imported `arc1-lexer … arc6-release` dirs and the seven loose
  files into `docs/planning/v0.1.0/`, preserving history.
- Create the annotated `0.1.0` tag on the imported `A6·S0` commit.

Out of scope:

- Moving `arc7-rules-v2` or creating the `0.2.0` tag (→ `v0.2.0/arc8`).
- Removing the now-nearly-empty `docs/design/022-lfe-format/` source dir — leave
  it holding `arc7-rules-v2`; `v0.2.0/arc8` empties and removes it.
- Any code change, rename, split, or publish.

## Precondition

Runs on the `feature/fezzik-import` branch **after `slice1-history-transfer` is
merged**, so the imported docs exist in `fmt` at `docs/design/022-lfe-format/`
(filter-repo preserved that path) and the `A6·S0` commit is in the DAG.

## The move map (§7a of the migration plan, v0.1.0 share)

From `docs/design/022-lfe-format/` → `docs/planning/v0.1.0/`:

| from | to |
|---|---|
| `arc1-lexer/` | `docs/planning/v0.1.0/arc1-lexer/` |
| `arc2-cst/` | `docs/planning/v0.1.0/arc2-cst/` |
| `arc3-printer/` | `docs/planning/v0.1.0/arc3-printer/` |
| `arc4-indent/` | `docs/planning/v0.1.0/arc4-indent/` |
| `arc5-provider/` | `docs/planning/v0.1.0/arc5-provider/` |
| `arc6-release/` | `docs/planning/v0.1.0/arc6-release/` |
| `cc-prompt-gallery.md` | `docs/planning/v0.1.0/` |
| `cc-prompts.md` | `docs/planning/v0.1.0/` |
| `formatting-gallery.md` | `docs/planning/v0.1.0/` |
| `formatting-rules.md` | `docs/planning/v0.1.0/` |
| `rebar3-lfe-provider.md` | `docs/planning/v0.1.0/` |
| `RESEARCH-BOOTSTRAP.md` | `docs/planning/v0.1.0/` |
| `SMOKE.md` | `docs/planning/v0.1.0/` |

`arc7-rules-v2/` is **not** moved here.

Result: `docs/planning/v0.1.0/` ends up holding the imported dev arcs
`arc1-lexer … arc6-release` (numbers 1–6) **alongside** this migration arc
`arc7-import/` — exactly the intended end state (six imported dev arcs + the
fmt-side arc7).

## The tag

- `0.1.0`, annotated, on the imported commit whose message is
  *"Implement Arc A6·S0 — e2e CLI test + fix bare-provider app discovery"*
  (was `41fcc55` in `rebar3_lfe`; **rewritten hash** after filter-repo).
- Locate it by message, not hash: `git log --all --grep='A6·S0' --oneline`.
  Confirm a single match and that it's the e2e-CLI commit before tagging.
- This tag is a **source-history marker, not a buildable release** — the
  imported commit carries only engine files (no `app.src`/`rebar.config`). First
  buildable, publishable tag is `0.4.0`.

## Note: the docs are archival, and two are *living*

The placed `arcN-*` dirs are `rebar3_lfe`'s historical CC-prompt record — they
keep their original shape (per-arc `cc-prompt-*.md`), not the fmt slice layout.
They are an archived design record, not active framework arcs.

Two of the loose files — `formatting-rules.md` and `formatting-gallery.md` — are
the **living Fezzik spec**, not just history. They land in `v0.1.0/` with the
rest, but consider a README pointer so they're discoverable as the current rules
(migration plan §7a raises this; not a gate for this slice).

## Success criteria

- All six `arcN-*` dirs and seven loose files present under
  `docs/planning/v0.1.0/`; `git log --follow` works on a sampled moved file.
- `arc7-rules-v2/` still in `docs/design/022-lfe-format/`, untouched.
- `0.1.0` annotated tag created, resolves to the unique `A6·S0` commit.
- `docs/planning/v0.5.0/` (pe) and `docs/planning/v0.1.0/arc7-import/` (this
  migration arc) untouched by the moves.
- `git diff --stat` for the slice shows **only** doc renames — no `src/` or
  `test/` changes.

## Handoff

When complete, CC provides:

- the doc moves committed on `feature/fezzik-import` (history-preserving `mv`s);
- the `0.1.0` tag + the resolved SHA and its commit message (proving it's
  `A6·S0`);
- the final `docs/planning/v0.1.0/` listing;
- a per-row ledger walk with command evidence;
- confirmation that `arc7-rules-v2` remains for the `v0.2.0` project.
