%%% @doc PropEr property: merge yields a valid Pareto frontier (Fig. 14).
-module(prop_pe_mset).

-include_lib("proper/include/proper.hrl").

-export([prop_mset_pareto/0]).

-define(CM, pe_cost_squared).

%% A1S1-9: merging two valid frontiers produces a valid Pareto frontier —
%% last strictly descending and cost strictly ascending (so no measure
%% dominates another).
prop_mset_pareto() ->
    ?FORALL(
        {Ms1, Ms2},
        {non_empty(list(measure())), non_empty(list(measure()))},
        begin
            F1 = make_frontier(Ms1),
            F2 = make_frontier(Ms2),
            Merged = pe_mset:merge(F1, F2, ?CM),
            valid_pareto(Merged)
        end
    ).

measure() ->
    ?LET(
        {Last, Overflow, Height},
        {range(0, 40), range(0, 500), range(0, 30)},
        {Last, {Overflow, Height}, {text, <<"x">>}}
    ).

%% Normalise an arbitrary list of measures into a valid frontier by folding the
%% merge over singletons (merge maintains the Pareto invariant).
make_frontier([M | Rest]) ->
    lists:foldl(
        fun(X, Acc) -> pe_mset:merge(pe_mset:singleton(X), Acc, ?CM) end,
        pe_mset:singleton(M),
        Rest
    ).

valid_pareto({set, Ms}) ->
    Lasts = [pe_measure:last(M) || M <- Ms],
    Costs = [pe_measure:cost(M) || M <- Ms],
    strictly_descending(Lasts) andalso strictly_ascending_costs(Costs).

strictly_descending([_]) -> true;
strictly_descending([A, B | Rest]) -> A > B andalso strictly_descending([B | Rest]);
strictly_descending([]) -> true.

strictly_ascending_costs([_]) ->
    true;
strictly_ascending_costs([A, B | Rest]) ->
    ?CM:le(A, B) andalso A =/= B andalso strictly_ascending_costs([B | Rest]);
strictly_ascending_costs([]) ->
    true.
