%%% @doc EUnit goldens for the arc2/slice1 literal constructors added to
%%% `pe_lfe:form()' — `{float}', `{binary}', `{map}', `{splice}' — plus faithful
%%% `{str}' escaping. Each asserts the rendered text and (where it matters) that
%%% the text re-reads through `lfe_io' to the original value.
-module(pe_lfe_literal_tests).

-include_lib("eunit/include/eunit.hrl").

fmt(Form) ->
    {Bin, _M, _S} = pe_lfe:format_binary(Form, #{width => 80}),
    Bin.

%% Read the single form back from rendered text.
reread(Bin) ->
    {ok, [Sexpr]} = lfe_io:read_string(binary_to_list(Bin)),
    Sexpr.

%%%-------------------------------------------------------------------
%%% float — canonical, round-trippable rendering
%%%-------------------------------------------------------------------

float_render_test() ->
    ?assertEqual(<<"1.5">>, fmt({float, 1.5})),
    ?assertEqual(<<"3.0e10">>, fmt({float, 3.0e10})),
    ?assertEqual(<<"0.1">>, fmt({float, 0.1})).

float_reads_back_equal_test() ->
    [
        ?assertEqual(F, reread(fmt({float, F})))
     || F <- [1.5, 0.1, 3.0e10, -2.25, 1.0, 1.0e-9]
    ].

%%%-------------------------------------------------------------------
%%% binary — `#"…"' when printable ASCII, else `#B(byte …)'
%%%-------------------------------------------------------------------

binary_printable_test() ->
    ?assertEqual(<<"#\"abc\"">>, fmt({binary, <<"abc">>})),
    ?assertEqual(<<"abc">>, reread(fmt({binary, <<"abc">>}))).

binary_bytes_test() ->
    ?assertEqual(<<"#B(1 2 3)">>, fmt({binary, <<1, 2, 3>>})),
    ?assertEqual(<<1, 2, 3>>, reread(fmt({binary, <<1, 2, 3>>}))).

binary_empty_test() ->
    %% `#""' is illegal in LFE; the empty binary uses the byte form.
    ?assertEqual(<<"#B()">>, fmt({binary, <<>>})),
    ?assertEqual(<<>>, reread(fmt({binary, <<>>}))).

binary_escapes_quote_test() ->
    ?assertEqual(<<"#\"a\\\"b\"">>, fmt({binary, <<"a\"b">>})),
    ?assertEqual(<<"a\"b">>, reread(fmt({binary, <<"a\"b">>}))).

%%%-------------------------------------------------------------------
%%% map — `#M(k v …)'
%%%-------------------------------------------------------------------

map_render_test() ->
    M = {map, [{{sym, <<"a">>}, {int, 1}}, {{sym, <<"b">>}, {int, 2}}]},
    ?assertEqual(<<"#M(a 1 b 2)">>, fmt(M)),
    ?assertEqual(#{a => 1, b => 2}, reread(fmt(M))).

map_empty_test() ->
    ?assertEqual(<<"#M()">>, fmt({map, []})),
    ?assertEqual(#{}, reread(fmt({map, []}))).

%%%-------------------------------------------------------------------
%%% splice — `,@x' (faithful comma-at, distinct from `,x' unquote)
%%%-------------------------------------------------------------------

splice_render_test() ->
    %% rendered standalone for the golden; semantically it lives in a backquote.
    ?assertEqual(<<",@xs">>, fmt({splice, {sym, <<"xs">>}})),
    Bq = {bquote, {list, [{sym, <<"a">>}, {splice, {sym, <<"c">>}}]}},
    ?assertEqual(<<"`(a ,@c)">>, fmt(Bq)),
    ?assertEqual([backquote, [a, ['comma-at', c]]], reread(fmt(Bq))).

splice_is_distinct_from_unquote_test() ->
    ?assertEqual(<<",x">>, fmt({unquote, {sym, <<"x">>}})),
    ?assertEqual(<<",@x">>, fmt({splice, {sym, <<"x">>}})).

%%%-------------------------------------------------------------------
%%% str — faithful escaping (slice6 used a printed-text leaf)
%%%-------------------------------------------------------------------

str_escapes_test() ->
    ?assertEqual(<<"\"a\\\"b\"">>, fmt({str, <<"a\"b">>})),
    ?assertEqual("a\"b", reread(fmt({str, <<"a\"b">>}))),
    ?assertEqual(<<"\"a\\\\b\"">>, fmt({str, <<"a\\b">>})).
