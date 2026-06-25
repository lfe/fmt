%%% @doc Slice8 differential oracle: compares our Πₑ engine against the mjl
%%% `pretty-expressive' reference, document-by-document, over a width sweep.
%%%
%%% For each random document we serialise the frozen DAG into the wire format
%%% understood by the `pe-oracle' Rust binary (see `test/oracle/'), render it
%%% through both engines at `(W, limit = trunc(1.2 * W))', and compare the
%%% **reported optimal cost** — the `{Badness, Height}' each engine itself
%%% attaches to the chosen layout (ours via {@link pe_measure:cost/1}, mjl via
%%% `PrintResult::cost()'). Πₑ guarantees both engines reach the same optimal
%%% *cost*, never the same *string*, so reported-cost equality is the canonical
%%% gate (iteration 1). Byte identity is a *secondary* statistic — expected only
%%% on unique-optimum documents; a cost-equal byte difference is a legitimate
%%% tie, not a failure.
%%%
%%% Reported cost (not cost recomputed from the string) is canonical because an
%%% injected `cost' node contributes to the engine's internal cost while being
%%% invisible in the rendered string; string-recompute therefore cannot see it
%%% (that is why 8a had to exclude `cost'). Comparing the reported cost re-admits
%%% `cost' and closes the blind spot for any future invisible-cost feature.
%%%
%%% This module is deliberately NOT a PropEr property and its functions are not
%%% named `prop_*', so the default `rebar3 proper' run does not pick it up — it
%%% needs the Rust binary and is driven explicitly via `escript bench/pe_oracle'.
%%%
%%% Corpus bound (operator decision, slice8; A1-R018): our newline cost charges
%%% for indentation overflow (paper LineM) whereas mjl's does not. The two
%%% diverge only when a line's indentation exceeds the page width — so reported
%%% costs agree *only* within bounds where LineM charges nothing. The generator
%%% keeps documents small (shallow depth, small nests, short text) and the sweep
%%% starts at width 40, so every reachable indentation stays well under it and
%%% the divergence is never exercised. Growing the corpus to indentation-overflow
%%% cases is gated on resolving that divergence (an operator decision).
-module(pe_oracle_mjl).

-export([run/0, run/1, check/2, serialize/1, recompute/2, dump_samples/2]).

-define(ORACLE, "test/oracle/target/release/pe-oracle").
-define(WIDTHS, [40, 80, 120]).
-define(DEPTH, 3).

%%%-------------------------------------------------------------------
%%% Driver
%%%-------------------------------------------------------------------

-doc "Run the default sweep (300 documents per width).".
-spec run() -> ok.
run() -> run(300).

-doc "Generate `N' documents, compare both engines at every swept width.".
-spec run(non_neg_integer()) -> ok.
run(N) ->
    case filelib:is_regular(?ORACLE) of
        false ->
            io:format(
                "oracle binary not found at ~s~n"
                "build it first: (cd test/oracle && cargo build --release)~n",
                [?ORACLE]
            ),
            error(no_oracle_binary);
        true ->
            Cases = [{rand_doc(?DEPTH), W} || _ <- lists:seq(1, N), W <- ?WIDTHS],
            Tally = lists:foldl(fun tally/2, {0, 0, []}, Cases),
            report(N, length(Cases), Tally)
    end.

tally({Sym, W}, {CostEq, ByteEq, Mismatches}) ->
    case check(Sym, W) of
        {ok, identical} -> {CostEq + 1, ByteEq + 1, Mismatches};
        {ok, tie} -> {CostEq + 1, ByteEq, Mismatches};
        {mismatch, Detail} -> {CostEq, ByteEq, [Detail | Mismatches]}
    end.

report(N, Total, {CostEq, ByteEq, Mismatches}) ->
    Widths = lists:join(",", [integer_to_list(W) || W <- ?WIDTHS]),
    io:format("mjl differential oracle: ~b docs x widths {~s} = ~b cases~n", [N, Widths, Total]),
    io:format("  cost-equal:     ~b/~b~n", [CostEq, Total]),
    io:format("  byte-identical: ~b/~b~n", [ByteEq, Total]),
    case Mismatches of
        [] ->
            io:format("  PASS: both engines agree on cost for every case~n"),
            ok;
        _ ->
            io:format("  FAIL: ~b cost mismatch(es)~n", [length(Mismatches)]),
            [io:format("    ~p~n", [M]) || M <- lists:sublist(Mismatches, 10)],
            error(oracle_mismatch)
    end.

-doc """
Write `N' diverse oracle cases to `Path' as a CSV (one row per doc x width):
the wire, width, both engines' rendered strings (newlines shown as `\n', the
literal sequence backslash-n), and each engine's **reported** optimal cost (the
canonical gate). For a cost-free row the reported cost also equals the
string-recomputed `{badness, height}', so a verifier without a Rust toolchain
can re-derive it from the rendered string; a cost-bearing row carries an
injected cost invisible to the string, so there the CSV documents the two
reported costs whose equality is the check (mirrors slice7's `frontier.csv').
""".
-spec dump_samples(non_neg_integer(), file:name_all()) -> ok.
dump_samples(N, Path) ->
    Header = "width,wire,our_render,mjl_render,our_cost,mjl_cost\n",
    Rows = [sample_row(rand_doc(?DEPTH), W) || _ <- lists:seq(1, N), W <- ?WIDTHS],
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, [Header | Rows]),
    io:format("wrote ~b oracle sample rows to ~s~n", [length(Rows), Path]).

sample_row(Sym, W) ->
    {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
    Dag = pe_doc:freeze(B, Root),
    Wire = iolist_to_binary(serialize(Dag)),
    {OurStr, OurCost} = render_field(our_render(Dag, W)),
    {MjlStr, MjlCost} = render_field(mjl_render(Wire, W)),
    io_lib:format("~b,~s,~s,~s,~s,~s\n", [
        W, csv(Wire), csv(OurStr), csv(MjlStr), cost_str(OurCost), cost_str(MjlCost)
    ]).

render_field(failed) -> {<<"<<FAIL>>">>, failed};
render_field({ok, Bin, Cost}) -> {shownl(Bin), Cost}.

%% Render real newlines as the two-character sequence `\n' so each case is one
%% CSV line.
shownl(Bin) -> binary:replace(Bin, <<"\n">>, <<"\\n">>, [global]).

csv(Bin) -> [$", binary:replace(Bin, <<"\"">>, <<"\"\"">>, [global]), $"].

cost_str(failed) -> "failed";
cost_str({Bn, Hn}) -> io_lib:format("(~b ~b)", [Bn, Hn]).

%%%-------------------------------------------------------------------
%%% Single-case comparison
%%%-------------------------------------------------------------------

-doc """
Render one symbolic document through both engines at width `W' and compare on
**reported cost** (the canonical gate). Returns `{ok, identical}' when the
reported costs match and the byte output is identical, `{ok, tie}' when the
reported costs match but the layouts differ (a legitimate equal-cost tie), or
`{mismatch, Detail}' when the reported costs differ or the engines disagree on
printability.
""".
-spec check(pe_gen:sym(), pos_integer()) ->
    {ok, identical | tie} | {mismatch, map()}.
check(Sym, W) ->
    {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
    Dag = pe_doc:freeze(B, Root),
    Wire = iolist_to_binary(serialize(Dag)),
    compare(Sym, W, Wire, our_render(Dag, W), mjl_render(Wire, W)).

compare(_Sym, _W, _Wire, failed, failed) ->
    %% both engines reject the document as unprintable.
    {ok, identical};
compare(Sym, W, Wire, Ours, Mjl) when Ours =:= failed; Mjl =:= failed ->
    {mismatch, #{
        reason => printability,
        width => W,
        sym => Sym,
        wire => Wire,
        ours => Ours,
        mjl => Mjl
    }};
compare(Sym, W, Wire, {ok, OurBin, OurCost}, {ok, MjlBin, MjlCost}) ->
    %% Canonical: reported-cost equality. Secondary (only distinguishes the
    %% return tag, never gates): byte identity, expected on unique optima.
    case {OurCost =:= MjlCost, OurBin =:= MjlBin} of
        {true, true} ->
            {ok, identical};
        {true, false} ->
            {ok, tie};
        {false, _} ->
            {mismatch, #{
                reason => cost,
                width => W,
                sym => Sym,
                wire => Wire,
                ours => OurBin,
                mjl => MjlBin,
                our_cost => OurCost,
                mjl_cost => MjlCost
            }}
    end.

%% Our reported optimal cost is the cost of the Measure the resolver returns.
our_render(Dag, W) ->
    try pe:format_binary(Dag, #{width => W}) of
        {Bin, Measure, _Stats} -> {ok, Bin, pe_measure:cost(Measure)}
    catch
        error:no_valid_layout -> failed
    end.

%% mjl reports `OK <badness> <height>\n<layout>' on success, `FAIL' when the
%% document has no valid layout.
mjl_render(Wire, W) ->
    Limit = trunc(1.2 * W),
    File = tmp_path(),
    ok = file:write_file(File, Wire),
    Cmd = lists:flatten(
        io_lib:format("~s ~b ~b ~s", [?ORACLE, W, Limit, File])
    ),
    Out = os:cmd(Cmd),
    _ = file:delete(File),
    parse_mjl(Out).

parse_mjl("FAIL") ->
    failed;
parse_mjl(Out) ->
    {HeaderLine, Layout} = split_first_line(Out),
    ["OK", BadnessStr, HeightStr] = string:lexemes(HeaderLine, " "),
    Cost = {list_to_integer(BadnessStr), list_to_integer(HeightStr)},
    {ok, list_to_binary(Layout), Cost}.

%% Split off the first line (the `OK b h' header); the remainder, after the one
%% separating newline, is the layout verbatim (may be empty or multi-line).
split_first_line(Str) ->
    case string:split(Str, "\n") of
        [Header, Rest] -> {Header, Rest};
        [Header] -> {Header, ""}
    end.

tmp_path() ->
    Dir =
        case os:getenv("TMPDIR") of
            false -> "/tmp";
            T -> T
        end,
    Unique = erlang:integer_to_list(erlang:unique_integer([positive])),
    filename:join(Dir, "pe_oracle_" ++ Unique ++ ".sexp").

%%%-------------------------------------------------------------------
%%% Cost recomputed from a rendered string
%%%-------------------------------------------------------------------

-doc """
The `{Badness, Height}' cost of a rendered string at page width `W', recomputed
independently of either engine: badness is the sum over lines of
`max(0, len - W)^2' and height is the newline count. ASCII-only corpus, so the
display width of a line equals its byte length. This is a *secondary* check
(used by `pe_wire_tests'): on a cost-free, in-bounds document it equals the
engine's reported cost, but an injected `cost' node is invisible here — hence
the reported cost, not this, is the oracle's canonical gate.
""".
-spec recompute(binary(), pos_integer()) -> {non_neg_integer(), non_neg_integer()}.
recompute(Bin, W) ->
    Lines = binary:split(Bin, <<"\n">>, [global]),
    Badness = lists:sum([sq(max(0, byte_size(L) - W)) || L <- Lines]),
    {Badness, length(Lines) - 1}.

sq(X) -> X * X.

%%%-------------------------------------------------------------------
%%% Wire serialisation of a frozen DAG
%%%-------------------------------------------------------------------

-doc "Serialise a frozen DAG into the `pe-oracle' wire S-expression.".
-spec serialize(pe_doc:dag()) -> iolist().
serialize(Dag) -> ser(Dag, pe_doc:root(Dag)).

ser(Dag, Id) -> ser_node(pe_doc:get(Dag, Id), Dag).

ser_node({text, S, _W}, _Dag) ->
    ["(t ", quote(S), ")"];
ser_node(nl, _Dag) ->
    "(nl)";
ser_node(brk, _Dag) ->
    "(brk)";
ser_node(hard_nl, _Dag) ->
    "(hnl)";
ser_node(fail, _Dag) ->
    "(fail)";
ser_node({concat, A, B}, Dag) ->
    ["(cat ", ser(Dag, A), " ", ser(Dag, B), ")"];
ser_node({nest, N, D}, Dag) ->
    ["(nest ", integer_to_list(N), " ", ser(Dag, D), ")"];
ser_node({align, D}, Dag) ->
    ["(align ", ser(Dag, D), ")"];
ser_node({reset, D}, Dag) ->
    ["(reset ", ser(Dag, D), ")"];
ser_node({cost, {Bn, Hn}, D}, Dag) ->
    ["(cost ", integer_to_list(Bn), " ", integer_to_list(Hn), " ", ser(Dag, D), ")"];
ser_node({choice, A, B}, Dag) ->
    ["(alt ", ser(Dag, A), " ", ser(Dag, B), ")"].

quote(S) -> [$", esc(S), $"].

esc(<<>>) -> [];
esc(<<C, R/binary>>) when C =:= $"; C =:= $\\ -> [$\\, C | esc(R)];
esc(<<C, R/binary>>) -> [C | esc(R)].

%%%-------------------------------------------------------------------
%%% Bounded random document generator
%%%
%%% Plain `rand'-driven (no PropEr) so the oracle runs from a bare `erl' shell.
%%% Bounds keep every reachable indentation small: nests are 0..2 and depth is
%%% capped, so even an `align' past the longest flat line stays under width 40 —
%%% keeping the LineM newline-cost divergence (A1-R018) unexercised so the
%%% reported costs are comparable.
%%%
%%% `cost' is included (iteration 1): the canonical comparator is the reported
%%% cost, which both engines compute identically through an injected `cost'
%%% node, so cost-bearing documents are now in scope. (8a had excluded `cost'
%%% only because its earlier string-recompute comparator could not see an
%%% injected cost.)
%%%-------------------------------------------------------------------

rand_doc(0) ->
    rand_leaf();
rand_doc(Depth) ->
    case rand:uniform(13) of
        N when N =< 2 -> rand_leaf();
        N when N =< 4 -> {concat, rand_doc(Depth - 1), rand_doc(Depth - 1)};
        5 -> {nest, rand:uniform(3) - 1, rand_doc(Depth - 1)};
        6 -> {align, rand_doc(Depth - 1)};
        7 -> {reset, rand_doc(Depth - 1)};
        8 -> {cost, {rand:uniform(4) - 1, rand:uniform(3) - 1}, rand_doc(Depth - 1)};
        N when N =< 10 -> {choice, rand_doc(Depth - 1), rand_doc(Depth - 1)};
        N when N =< 12 -> {group, rand_doc(Depth - 1)};
        13 -> {vconcat, rand_doc(Depth - 1), rand_doc(Depth - 1)}
    end.

rand_leaf() ->
    case rand:uniform(11) of
        N when N =< 5 -> {text, rand_text()};
        N when N =< 7 -> nl;
        8 -> brk;
        9 -> hard_nl;
        10 -> nl;
        11 -> fail
    end.

rand_text() ->
    N = rand:uniform(3),
    list_to_binary([$a + (rand:uniform(26) - 1) || _ <- lists:seq(1, N)]).
