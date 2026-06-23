%%% @doc EUnit tests for {@link pe_render} (paper Fig. 8 rendering).
-module(pe_render_tests).

-include_lib("eunit/include/eunit.hrl").

bin(Cdoc) -> pe_render:render_binary(Cdoc).

%% A1S1-1: text, nl, concat.
text_test() ->
    ?assertEqual(<<"abc">>, bin({text, <<"abc">>})).

nl_test() ->
    ?assertEqual(<<"\n">>, bin(nl)).

concat_test() ->
    ?assertEqual(<<"ab">>, bin({concat, {text, <<"a">>}, {text, <<"b">>}})).

%% render/1 always returns an iolist (even for a bare text leaf).
render_returns_iolist_test() ->
    R = pe_render:render({text, <<"x">>}),
    ?assert(is_list(R)),
    ?assertEqual(<<"x">>, iolist_to_binary(R)).

%% A newline re-indents to the current indentation level.
nl_reindents_test() ->
    ?assertEqual(
        <<"a\n  b">>,
        bin({nest, 2, {concat, {text, <<"a">>}, {concat, nl, {text, <<"b">>}}}})
    ).

%% A1S1-2: nest is relative (indent += N); align is absolute (indent := column).
%% Here the column after "abc" is 3, so they differ: nest 2 -> 2 spaces,
%% align -> 3 spaces.
nest_relative_test() ->
    ?assertEqual(
        <<"abc\n  x">>,
        bin({concat, {text, <<"abc">>}, {nest, 2, {concat, nl, {text, <<"x">>}}}})
    ).

align_absolute_test() ->
    ?assertEqual(
        <<"abc\n   x">>,
        bin({concat, {text, <<"abc">>}, {align, {concat, nl, {text, <<"x">>}}}})
    ).

nest_and_align_differ_test() ->
    Body = {concat, nl, {text, <<"x">>}},
    Nest = {concat, {text, <<"abc">>}, {nest, 2, Body}},
    Align = {concat, {text, <<"abc">>}, {align, Body}},
    ?assertNotEqual(bin(Nest), bin(Align)).

%% align captures the column at the align point, not a fixed indent: the
%% second and third lines align under "b".
align_multiline_test() ->
    %% "a" then align of ("b" <nl> "c" <nl> "d"): align indent = column 1.
    Doc =
        {concat, {text, <<"a">>},
            {align, {concat, {text, <<"b">>}, {concat, nl, {concat, {text, <<"c">>}, {concat, nl, {text, <<"d">>}}}}}}},
    ?assertEqual(<<"ab\n c\n d">>, bin(Doc)).

%% nested nest accumulates relative indentation.
nested_nest_test() ->
    Inner = {nest, 2, {concat, nl, {text, <<"y">>}}},
    Doc = {nest, 2, {concat, {text, <<"x">>}, {concat, nl, Inner}}},
    %% outer nest=2 -> "x" then nl to col 2; inner nest +2 -> nl to col 4.
    ?assertEqual(<<"x\n  \n    y">>, bin(Doc)).

%% A1S1-3: render_binary flattens to a stable binary without the caller
%% flattening anything.
render_binary_stable_test() ->
    Doc = {concat, {text, <<"(a ">>}, {concat, {text, <<"b">>}, {text, <<")">>}}},
    ?assertEqual(<<"(a b)">>, bin(Doc)),
    ?assert(is_binary(bin(Doc))).
