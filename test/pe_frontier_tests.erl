%%% @doc EUnit tests for the frontier-width instrumentation in {@link pe_resolve}.
-module(pe_frontier_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SQ, pe_cost_squared).

opts(Width, Frontier) ->
    Base = #{cost => ?SQ, memo => pe_memo_map, width => Width, limit => Width},
    case Frontier of
        on -> Base#{frontier_stats => true};
        off -> Base
    end.

%% choice(text "aaaa", vconcat("a", "a")): at a wide width the two layouts are
%% incomparable — flat (last 4, cost {0,0}) vs broken (last 1, cost {0,1}) — so
%% the choice's memo entry holds a 2-wide Pareto frontier. Everything else is a
%% singleton, so the histogram is hand-computable.
choice_dag() ->
    B0 = pe_doc:new(),
    {Flat, B1} = pe_doc:text(<<"aaaa">>, B0),
    {A, B2} = pe_doc:text(<<"a">>, B1),
    {V, B3} = pe_doc:vconcat(A, A, B2),
    {Ch, B4} = pe_doc:choice(Flat, V, B3),
    pe_doc:freeze(B4, Ch).

%% A1S7-4: the frontier summary on a known DAG.
frontier_choice_test() ->
    {Measure, Stats} = pe_resolve:resolve(choice_dag(), opts(80, on)),
    %% the flat layout wins (fits, zero cost).
    ?assertEqual({0, 0}, pe_measure:cost(Measure)),
    F = maps:get(frontier, Stats),
    ?assertEqual(2, maps:get(max, F)),
    %% one frontier sample per memo entry (none tainted at width 80).
    ?assertEqual(maps:get(memo_size, Stats), maps:get(count, F)),
    ?assertEqual(6, maps:get(count, F)),
    ?assertEqual(#{1 => 5, 2 => 1}, maps:get(histogram, F)),
    ?assertEqual(1, maps:get(p50, F)),
    ?assertEqual(2, maps:get(p90, F)),
    ?assertEqual(2, maps:get(p99, F)),
    ?assertEqual(7 / 6, maps:get(mean, F)),
    %% max_at is a {Id, C, I} key at the root context.
    ?assertMatch({_Id, 0, 0}, maps:get(max_at, F)),
    %% the histogram counts sum to count.
    ?assertEqual(maps:get(count, F), lists:sum(maps:values(maps:get(histogram, F)))).

%% A choiceless document has a width-1 frontier at every memo entry.
frontier_choiceless_test() ->
    B0 = pe_doc:new(),
    {X, B1} = pe_doc:text(<<"x">>, B0),
    {Nl, B2} = pe_doc:nl(B1),
    {C1, B3} = pe_doc:concat(X, Nl, B2),
    {C2, B4} = pe_doc:concat(C1, X, B3),
    Dag = pe_doc:freeze(B4, C2),
    {_M, Stats} = pe_resolve:resolve(Dag, opts(80, on)),
    F = maps:get(frontier, Stats),
    ?assertEqual(1, maps:get(max, F)),
    ?assertEqual(1.0, maps:get(mean, F)),
    ?assertEqual(1, maps:get(p99, F)),
    Count = maps:get(count, F),
    ?assertEqual(#{1 => Count}, maps:get(histogram, F)).

%% A1S7-2: the frontier key is present iff the flag is on.
frontier_absent_when_off_test() ->
    {_M, Stats} = pe_resolve:resolve(choice_dag(), opts(80, off)),
    ?assertNot(maps:is_key(frontier, Stats)),
    ?assertMatch(#{memo_size := _, calls := _, tainted := _}, Stats).

frontier_present_when_on_test() ->
    {_M, Stats} = pe_resolve:resolve(choice_dag(), opts(80, on)),
    ?assert(maps:is_key(frontier, Stats)).

%% A1S7-5/6 (concrete anchor for the property): on/off agree on the measure and
%% on every non-frontier counter.
invariance_anchor_test() ->
    Dag = choice_dag(),
    {Moff, Soff} = pe_resolve:resolve(Dag, opts(80, off)),
    {Mon, Son} = pe_resolve:resolve(Dag, opts(80, on)),
    ?assertEqual(Moff, Mon),
    ?assertEqual(Soff, maps:remove(frontier, Son)).
