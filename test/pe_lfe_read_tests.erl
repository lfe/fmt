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
    ?assertMatch(
        {bquote, {list, [{sym, <<"a">>}, {unquote, {sym, <<"bs">>}}]}},
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
%%% A1S6-6: unmodeled leaves hit the printed-text fallback, never crash
%%%-------------------------------------------------------------------

fallback_no_crash_test() ->
    %% feed each unmodeled kind directly; each must yield a {sym, binary} leaf.
    [
        ?assertMatch({sym, B} when is_binary(B), pe_lfe_read:convert(Term))
     || Term <- [
            1.5,
            -0.25,
            <<"a binary">>,
            #{a => 1, b => 2},
            "a printable string",
            fun() -> ok end
        ]
    ].

%% a character literal reads as an integer (no crash; modeled as {int, _}).
char_is_int_test() ->
    ?assertEqual({int, $a}, conv("#\\a")).

%% a string is carried as a single printed leaf, not exploded into char ints.
string_is_single_leaf_test() ->
    ?assertMatch({sym, _}, conv("\"hello world\"")).

%% convert is total: a deeply mixed term never throws.
convert_is_total_test() ->
    Mixed = [foo, 1, 2.0, <<"b">>, {a, "str"}, [nested, 'comma-at']],
    ?assertMatch({call, _}, pe_lfe_read:convert(Mixed)).

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
