%%% @doc EUnit tests for {@link pe_resolve}: concrete optima and ETS lifecycle.
-module(pe_resolve_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SQ, pe_cost_squared).

%% group(vconcat("aa", "bb")): flat "aa bb" or broken "aa"/"bb".
group_doc() ->
    B0 = pe_doc:new(),
    {A, B1} = pe_doc:text(<<"aa">>, B0),
    {C, B2} = pe_doc:text(<<"bb">>, B1),
    {V, B3} = pe_doc:vconcat(A, C, B2),
    {G, B4} = pe_doc:group(V, B3),
    pe_doc:freeze(B4, G).

opts(Memo, Width) ->
    #{cost => ?SQ, memo => Memo, width => Width, limit => 1000}.

%% Wide page: the resolver picks the flat layout (cost {0, 0}).
resolve_prefers_flat_test() ->
    {M, _Stats} = pe_resolve:resolve(group_doc(), opts(pe_memo_map, 80)),
    ?assertEqual({0, 0}, pe_measure:cost(M)),
    %% the winning choiceless doc has no newline (it is the flattened branch).
    ?assertNot(has_nl(pe_measure:doc(M))).

%% Narrow page: the resolver picks the broken layout (cost {0, 1}).
resolve_prefers_broken_test() ->
    {M, _Stats} = pe_resolve:resolve(group_doc(), opts(pe_memo_map, 3)),
    ?assertEqual({0, 1}, pe_measure:cost(M)),
    ?assert(has_nl(pe_measure:doc(M))).

%% All three backends agree on the optimum for the same input.
backends_agree_test() ->
    Costs = [
        pe_measure:cost(element(1, pe_resolve:resolve(group_doc(), opts(Memo, 3))))
     || Memo <- [pe_memo_map, pe_memo_ets, pe_memo_pd]
    ],
    ?assertEqual([{0, 1}, {0, 1}, {0, 1}], Costs).

%% Stats are reported.
stats_reported_test() ->
    {_M, Stats} = pe_resolve:resolve(group_doc(), opts(pe_memo_map, 80)),
    ?assertMatch(#{memo_size := _, calls := _, tainted := _}, Stats),
    ?assert(maps:get(memo_size, Stats) > 0).

%% A1S1-14: the ETS backend creates a private table per call and deletes it
%% before returning — no table leaks across the call.
ets_lifecycle_test() ->
    Before = length(ets:all()),
    {M, _Stats} = pe_resolve:resolve(group_doc(), opts(pe_memo_ets, 80)),
    After = length(ets:all()),
    ?assertEqual(Before, After),
    ?assertEqual({0, 0}, pe_measure:cost(M)).

%% The ETS table is cleaned up even when resolution crashes mid-call.
ets_lifecycle_on_crash_test() ->
    Before = length(ets:all()),
    %% a factory that crashes mid-resolution; the try...after must still
    %% dispose the private table.
    BadOpts = #{cost => pe_cost_crash, memo => pe_memo_ets, width => 80, limit => 1000},
    ?assertError(boom, pe_resolve:resolve(group_doc(), BadOpts)),
    ?assertEqual(Before, length(ets:all())).

%% The process-dictionary backend leaves no keys behind.
pd_leaves_no_keys_test() ->
    Before = length(erlang:get()),
    {_M, _Stats} = pe_resolve:resolve(group_doc(), opts(pe_memo_pd, 80)),
    ?assertEqual(Before, length(erlang:get())).

has_nl(nl) -> true;
has_nl({text, _}) -> false;
has_nl({concat, A, B}) -> has_nl(A) orelse has_nl(B);
has_nl({nest, _, D}) -> has_nl(D);
has_nl({align, D}) -> has_nl(D).
