%%% @doc EUnit tests for the {@link pe} public facade.
-module(pe_tests).

-include_lib("eunit/include/eunit.hrl").

%% group(vconcat("aa", "bb")): flat "aa bb" or broken "aa"/"bb".
group_doc() ->
    B0 = pe_doc:new(),
    {A, B1} = pe_doc:text(<<"aa">>, B0),
    {C, B2} = pe_doc:text(<<"bb">>, B1),
    {V, B3} = pe_doc:vconcat(A, C, B2),
    {G, B4} = pe_doc:group(V, B3),
    pe_doc:freeze(B4, G).

%% A1S2-4: defaults — wide default width (80) picks the flat layout.
format_defaults_test() ->
    {Bin, Measure, Stats} = pe:format_binary(group_doc(), #{}),
    ?assertEqual(<<"aa bb">>, Bin),
    ?assertEqual({0, 0}, pe_measure:cost(Measure)),
    ?assertMatch(#{memo_size := _, calls := _, tainted := _}, Stats).

%% format/2 returns an iolist that flattens to the same bytes.
format_iolist_test() ->
    {Iolist, _M, _S} = pe:format(group_doc(), #{}),
    ?assert(is_list(Iolist)),
    ?assertEqual(<<"aa bb">>, iolist_to_binary(Iolist)).

%% A1S2-5: a narrow width override forces the broken layout.
format_opts_override_test() ->
    {Bin, Measure, _S} = pe:format_binary(group_doc(), #{width => 3}),
    ?assertEqual(<<"aa\nbb">>, Bin),
    ?assertEqual({0, 1}, pe_measure:cost(Measure)).

%% Overriding the memo backend still produces the same result.
format_memo_override_test() ->
    {Bin, _M, _S} = pe:format_binary(group_doc(), #{width => 3, memo => pe_memo_ets}),
    ?assertEqual(<<"aa\nbb">>, Bin).

%% resolve/2 is a pass-through requiring full opts; matches pe_resolve.
resolve_passthrough_test() ->
    Opts = #{cost => pe_cost_squared, memo => pe_memo_map, width => 80, limit => 80},
    ?assertEqual(
        pe_resolve:resolve(group_doc(), Opts),
        pe:resolve(group_doc(), Opts)
    ).

%% limit defaults to the page width (so a narrow width also limits computation).
limit_defaults_to_width_test() ->
    {_Bin, _M, _S} = Result = pe:format_binary(group_doc(), #{width => 80}),
    ?assertMatch({<<"aa bb">>, _, _}, Result).
