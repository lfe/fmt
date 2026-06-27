# lfe/fmt

[![Build Status][gh-actions-badge]][gh-actions]
[![LFE Versions][lfe-badge]][lfe]
[![Erlang Versions][erlang-badge]][version]
[![Tags][github-tags-badge]][github-tags]

*A code formatter for LFE*

[![LFE fmt project logo][logo]][logo-large]

## About

**lfmt** is a code formatter for [LFE][lfe] (Lisp Flavoured Erlang). It reads LFE
source and pretty-prints it into a consistent, canonical layout — preserving
comments and guaranteeing **idempotence**: formatting already-formatted code
leaves it unchanged (`format(format(X)) == format(X)`).

lfmt has a **multi-engine** design: a single, stable API (`lfmt:new/1`) sits in
front of pluggable formatting *engines*, so you can choose the algorithm that
suits you. This release ships the **`fezzik`** engine; two further engines are
planned:

| Engine   | Status        | Notes                                          |
|----------|---------------|------------------------------------------------|
| `fezzik` | **available** | direct, fast brute-force formatter             |
| `pe`     | planned       | pretty-expressive (optimal-layout) engine      |
| `pc`     | planned       | pretty-canny engine                            |

Although it begins life formatting LFE, lfmt is written in Erlang by deliberate
design: the aim is a **general-purpose formatter for the wider BEAM community**.
The forthcoming `pe` and `pc` engines are built around user-supplied
**formatting-rules files** — given a rule set, lfmt is intended to format *any*
text file according to those rules, not only LFE source.

The engine is pure OTP with **zero runtime dependencies**.

## Usage

lfmt is an Erlang/LFE library. Add it as a dependency (rebar3):

```erlang
{deps, [{lfmt, "~> 0.4"}]}.
```

### Formatting

The simplest form uses the default engine (`fezzik`):

```erlang
{ok, Formatted} = lfmt:format(Source).
```

To select an engine explicitly, build a reusable formatter with `lfmt:new/1`:

```erlang
Fmtr = lfmt:new(#{engine => fezzik}),
{ok, Formatted} = lfmt:format(Fmtr, Source).
```

`Source` is LFE source as a binary or string, and the result is an `iolist`.
Because formatted output can contain Unicode codepoints (> 127), convert it to a
binary with `unicode:characters_to_binary/1` — **not** `iolist_to_binary/1`:

```erlang
{ok, IoData} = lfmt:format(<<"(defun id (x) x)">>),
Bin = unicode:characters_to_binary(IoData).
```

From LFE:

```lisp
(case (lfmt:format source)
  (`#(ok ,formatted) formatted)
  (`#(error ,reason) (error reason)))
```

Selecting an engine that isn't available yet (e.g. `pe`/`pc`) is reported
explicitly rather than silently ignored.

## License

Apache-2.0. See [LICENSE](LICENSE).

[//]: ---Named-Links---

[logo]: priv/images/logo-x250.png
[logo-large]: priv/images/logo-x1254.png
[gh-actions-badge]: https://github.com/lfe/fmt/actions/workflows/ci.yml/badge.svg
[gh-actions]: https://github.com/lfe/fmt/actions
[lfe]: https://github.com/rvirding/lfe
[lfe-badge]: https://img.shields.io/badge/lfe-2.2+-blue.svg
[erlang-badge]: https://img.shields.io/badge/erlang-26+-blue.svg
[version]: https://github.com/lfe/fmt/blob/main/.github/workflows/ci.yml
[github-tags]: https://github.com/lfe/fmt/tags
[github-tags-badge]: https://img.shields.io/github/tag/lfe/fmt.svg
