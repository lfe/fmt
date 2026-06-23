%%% @doc PropEr properties for the default cost factory's Fig. 6 contracts.
-module(prop_pe_cost).

-include_lib("proper/include/proper.hrl").

-export([prop_factory_contracts/0]).

-define(MOD, pe_cost_squared).

%% A1S1-6: the default factory satisfies the four cost-factory contracts that
%% license the Pareto pruning (paper Fig. 6):
%%   1. `le' is a total order (total, antisymmetric, transitive);
%%   2. `combine' is monotone in both arguments;
%%   3. `text_cost' decomposes additively and is monotone in the column;
%%   4. `text_cost(W, C, 0) = text_cost(W, 0, 0)'.
prop_factory_contracts() ->
    ?FORALL(
        {W, C, C2, L1, L2, A, B, D, E},
        {range(1, 30), range(0, 40), range(0, 40), range(0, 40), range(0, 40), cost(), cost(),
            cost(), cost()},
        begin
            L = L1 + L2,
            Total = ?MOD:le(A, B) orelse ?MOD:le(B, A),
            AntiSym = (not (?MOD:le(A, B) andalso ?MOD:le(B, A))) orelse (A =:= B),
            Trans = (not (?MOD:le(A, B) andalso ?MOD:le(B, D))) orelse ?MOD:le(A, D),
            Monotone =
                (not (?MOD:le(A, B) andalso ?MOD:le(D, E))) orelse
                    ?MOD:le(?MOD:combine(A, D), ?MOD:combine(B, E)),
            Additive =
                ?MOD:text_cost(W, C, L) =:=
                    ?MOD:combine(?MOD:text_cost(W, C, L1), ?MOD:text_cost(W, C + L1, L2)),
            ZeroLength = ?MOD:text_cost(W, C, 0) =:= ?MOD:text_cost(W, 0, 0),
            ColumnMonotone =
                case C =< C2 of
                    true -> ?MOD:le(?MOD:text_cost(W, C, L), ?MOD:text_cost(W, C2, L));
                    false -> true
                end,
            Total andalso AntiSym andalso Trans andalso Monotone andalso
                Additive andalso ZeroLength andalso ColumnMonotone
        end
    ).

cost() ->
    {range(0, 1000), range(0, 50)}.
