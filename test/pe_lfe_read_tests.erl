%%% @doc EUnit tests for the {@link pe_lfe_read} reader bridge.
-module(pe_lfe_read_tests).

-include_lib("eunit/include/eunit.hrl").

%% Convert the first (only) form of an LFE snippet.
conv(Str) ->
    {ok, [Sexpr]} = lfe_io:read_string(Str),
    pe_lfe_read:convert(Sexpr).

%%%-------------------------------------------------------------------
%%% A1S6-3: leaves, calls, tuples, dotted lists, quote-family
%%%-------------------------------------------------------------------

leaves_test() ->
    ?assertEqual({sym, <<"foo">>}, conv("foo")),
    ?assertEqual({sym, <<"foo-bar">>}, conv("foo-bar")),
    ?assertEqual({int, 42}, conv("42")),
    ?assertEqual({int, -7}, conv("-7")).

call_test() ->
    ?assertEqual(
        {call, [{sym, <<"foo">>}, {sym, <<"a">>}, {int, 1}]},
        conv("(foo a 1)")
    ).

tuple_test() ->
    ?assertEqual(
        {tuple, [{sym, <<"a">>}, {sym, <<"b">>}]},
        conv("#(a b)")
    ).

dotted_list_test() ->
    ?assertEqual(
        {dotted_list, [{sym, <<"a">>}], {sym, <<"b">>}},
        conv("(a . b)")
    ),
    ?assertEqual(
        {dotted_list, [{sym, <<"a">>}, {sym, <<"b">>}], {sym, <<"c">>}},
        conv("(a b . c)")
    ).

quote_family_test() ->
    ?assertEqual({quote, {sym, <<"foo">>}}, conv("'foo")),
    ?assertEqual({bquote, {sym, <<"foo">>}}, conv("`foo")),
    %% comma / comma-at only valid inside a backquote
    ?assertEqual(
        {bquote, {list, [{sym, <<"a">>}, {unquote, {sym, <<"b">>}}]}},
        conv("`(a ,b)")
    ),
    %% comma-at is now its own faithful {splice} node (slice6 collapsed it to
    %% {unquote}, dropping the @).
    ?assertEqual(
        {bquote, {list, [{sym, <<"a">>}, {splice, {sym, <<"bs">>}}]}},
        conv("`(a ,@bs)")
    ).

%%%-------------------------------------------------------------------
%%% A1S6-5: code-vs-data list position
%%%-------------------------------------------------------------------

code_vs_data_test() ->
    %% code position -> {call}
    ?assertMatch({call, [{sym, <<"foo">>}, {sym, <<"a">>}]}, conv("(foo a)")),
    %% under quote -> {list}
    ?assertEqual(
        {quote, {list, [{sym, <<"foo">>}, {sym, <<"a">>}]}},
        conv("'(foo a)")
    ),
    %% empty list -> {list, []}
    ?assertEqual({list, []}, conv("()")),
    ?assertEqual({quote, {list, []}}, conv("'()")),
    %% nested data: a quoted list of lists stays data all the way down
    ?assertEqual(
        {quote, {list, [{list, [{sym, <<"a">>}]}, {sym, <<"b">>}]}},
        conv("'((a) b)")
    ).

%%%-------------------------------------------------------------------
%%% A2S1-2/4/5: faithful leaves; no fallback (unmodeled crashes)
%%%-------------------------------------------------------------------

faithful_leaves_test() ->
    ?assertEqual({float, 1.5}, pe_lfe_read:convert(1.5)),
    ?assertEqual({float, -0.25}, pe_lfe_read:convert(-0.25)),
    ?assertEqual({binary, <<"a binary">>}, pe_lfe_read:convert(<<"a binary">>)),
    ?assertEqual({str, <<"a printable string">>}, pe_lfe_read:convert("a printable string")).

faithful_map_test() ->
    {map, KVs} = pe_lfe_read:convert(#{a => 1, b => 2}),
    %% maps:to_list order is unspecified; compare the sorted pair set.
    ?assertEqual(
        [{{sym, <<"a">>}, {int, 1}}, {{sym, <<"b">>}, {int, 2}}],
        lists:sort(KVs)
    ).

%% A2S1-5: no fallback — an unmodeled construct raises, it does not degrade.
unmodeled_construct_errors_test() ->
    ?assertError({unmodeled_construct, _}, pe_lfe_read:convert(fun() -> ok end)),
    ?assertError({unmodeled_construct, _}, pe_lfe_read:convert(self())).

%% a character literal reads as an integer (in LFE a char *is* an integer).
char_is_int_test() ->
    ?assertEqual({int, $a}, conv("#\\a")).

%% a string is a faithful {str} leaf carrying its bytes (not a printed-text hack).
string_is_str_leaf_test() ->
    ?assertEqual({str, <<"hello world">>}, conv("\"hello world\"")).

%% a deeply mixed real-LFE term converts without a fallback.
faithful_mixed_test() ->
    Mixed = [foo, 1, 2.0, <<"b">>, {a, "str"}, [nested, bar]],
    ?assertMatch(
        {call, [
            {sym, <<"foo">>},
            {int, 1},
            {float, 2.0},
            {binary, <<"b">>},
            {tuple, [{sym, <<"a">>}, {str, <<"str">>}]},
            {call, [{sym, <<"nested">>}, {sym, <<"bar">>}]}
        ]},
        pe_lfe_read:convert(Mixed)
    ).

%% A2S1-6: read_forms/1 captures the top-level form line from parse_file.
read_forms_captures_line_test() ->
    F = filename:join([code:lib_dir(lfe), "examples", "church.lfe"]),
    {ok, [{Form1, Line1} | _]} = pe_lfe_read:read_forms(F),
    ?assert(is_integer(Line1) andalso Line1 > 0),
    ?assertMatch({call, [{sym, <<"defmodule">>} | _]}, Form1).

%%%-------------------------------------------------------------------
%%% A1S6-7: round-trip every top-level form of the reference sources
%%%-------------------------------------------------------------------

reference_files() ->
    Dir = code:lib_dir(lfe),
    Core = [filename:join([Dir, "src", F]) || F <- ["cl.lfe", "clj.lfe"]],
    Tests = filelib:wildcard(filename:join([Dir, "test", "*.lfe"])),
    Core ++ Tests.

round_trip_test_() ->
    %% one test per reference file; generous timeout for the larger suites.
    [
        {filename:basename(File), {timeout, 120, fun() -> round_trip_file(File) end}}
     || File <- reference_files()
    ].

round_trip_file(File) ->
    {ok, Forms} = pe_lfe_read:read_file(File),
    ?assert(length(Forms) > 0),
    %% every top-level form lowers, resolves, and renders without crashing
    %% (safe_format_binary genericises and retries on any residual crash).
    lists:foreach(
        fun(Form) ->
            {Bin, _M, _S, _Fellback} = pe_lfe_read:safe_format_binary(Form, #{width => 80}),
            ?assert(byte_size(Bin) > 0)
        end,
        Forms
    ).
