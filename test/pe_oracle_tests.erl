%%% @doc EUnit sanity checks for the brute-force oracle in {@link pe_gen}.
%%%
%%% These pin the oracle itself (the resolver's correctness gate) on a layout
%%% whose optimum we can compute by hand, before the resolver leans on it.
-module(pe_oracle_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SQ, pe_cost_squared).

%% group(vconcat("aa", "bb")) offers two layouts:
%%   flat   : "aa bb"  (one line, length 5)
%%   broken : "aa" / "bb" (two lines)
group_doc() ->
    B0 = pe_doc:new(),
    {A, B1} = pe_doc:text(<<"aa">>, B0),
    {C, B2} = pe_doc:text(<<"bb">>, B1),
    {V, B3} = pe_doc:vconcat(A, C, B2),
    {G, B4} = pe_doc:group(V, B3),
    pe_doc:freeze(B4, G).

%% Both layouts are widened (flatten branch + broken branch).
widen_count_test() ->
    Dag = group_doc(),
    ?assertEqual(2, length(pe_gen:widen(Dag, pe_doc:root(Dag)))).

%% Wide page: the flat layout fits and wins on height (cost {0, 0}).
oracle_prefers_flat_when_it_fits_test() ->
    Dag = group_doc(),
    M = pe_gen:oracle_optimal(Dag, ?SQ, 80),
    ?assertEqual({0, 0}, pe_measure:cost(M)).

%% Narrow page (width 3): the flat "aa bb" (length 5) overflows by 2 -> squared
%% cost {4, 0}; the broken layout fits with cost {0, 1}, which is the optimum.
oracle_prefers_broken_when_flat_overflows_test() ->
    Dag = group_doc(),
    M = pe_gen:oracle_optimal(Dag, ?SQ, 3),
    ?assertEqual({0, 1}, pe_measure:cost(M)).
