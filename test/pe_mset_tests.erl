%%% @doc EUnit tests for {@link pe_mset} (Fig. 14).
-module(pe_mset_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CM, pe_cost_squared).

m(Last, Overflow, Height) -> {Last, {Overflow, Height}, {text, <<"x">>}}.

%% A1S1-10: merge prefers a Set over a Tainted, either side.
merge_prefers_set_test() ->
    Set = pe_mset:singleton(m(3, 0, 0)),
    Tnt = pe_mset:tainted(m(9, 5, 0)),
    ?assertEqual(Set, pe_mset:merge(Set, Tnt, ?CM)),
    ?assertEqual(Set, pe_mset:merge(Tnt, Set, ?CM)).

%% Merging two Tainted sets is left-biased.
merge_tainted_left_biased_test() ->
    L = pe_mset:tainted(m(3, 1, 0)),
    R = pe_mset:tainted(m(9, 2, 0)),
    Merged = pe_mset:merge(L, R, ?CM),
    ?assert(pe_mset:is_tainted(Merged)),
    ?assertEqual(m(3, 1, 0), pe_mset:optimal(Merged)).

%% taint(Set) collapses to the least-cost head; taint(Tainted) is identity.
taint_test() ->
    %% frontier ordered by cost ascending: head is least cost.
    Set = {set, [m(5, 1, 0), m(3, 4, 0)]},
    Tainted = pe_mset:taint(Set),
    ?assert(pe_mset:is_tainted(Tainted)),
    ?assertEqual(m(5, 1, 0), pe_mset:optimal(Tainted)),
    ?assertEqual(Tainted, pe_mset:taint(Tainted)).

%% lift maps over a Set's measures and through a Tainted's thunk.
lift_test() ->
    Bump = fun({L, C, D}) -> {L + 100, C, D} end,
    Set = pe_mset:singleton(m(3, 0, 0)),
    ?assertEqual({set, [{103, {0, 0}, {text, <<"x">>}}]}, pe_mset:lift(Set, Bump)),
    Tnt = pe_mset:tainted(m(3, 0, 0)),
    Lifted = pe_mset:lift(Tnt, Bump),
    ?assertEqual({103, {0, 0}, {text, <<"x">>}}, pe_mset:optimal(Lifted)).

%% optimal returns the least-cost head of a frontier.
optimal_test() ->
    Set = {set, [m(5, 1, 0), m(3, 4, 0)]},
    ?assertEqual(m(5, 1, 0), pe_mset:optimal(Set)).

%% Merging two frontiers prunes dominated measures and stays sorted.
merge_frontiers_prunes_test() ->
    %% Left frontier: last 5 cost {1,0}, last 3 cost {4,0}.
    L = {set, [m(5, 1, 0), m(3, 4, 0)]},
    %% Right: last 4 cost {2,0} (kept, incomparable), last 3 cost {9,0} (dominated by m(3,4,0)).
    R = {set, [m(4, 2, 0), m(3, 9, 0)]},
    {set, Ms} = pe_mset:merge(L, R, ?CM),
    ?assertEqual([m(5, 1, 0), m(4, 2, 0), m(3, 4, 0)], Ms).

%% dedup drops dominated measures from a last-descending, cost-ascending list.
dedup_test() ->
    %% m(3,9,0) is dominated by the following m(2,4,0)? No: last 3 > 2, cost 9 > 4,
    %% so m(2,4,0) does NOT dominate (needs last =< ). Keep both.
    ?assertEqual(
        [m(5, 1, 0), m(3, 4, 0)],
        pe_mset:dedup([m(5, 1, 0), m(3, 4, 0)], ?CM)
    ),
    %% here m(3,1,0) dominates m(5,4,0)? dominates needs last 3 =< 5 and cost {1,0} =< {4,0}: yes.
    %% input is [head=m(5,4,0), next=m(3,1,0)]; next dominates head -> drop head.
    ?assertEqual(
        [m(3, 1, 0)],
        pe_mset:dedup([m(5, 4, 0), m(3, 1, 0)], ?CM)
    ).
