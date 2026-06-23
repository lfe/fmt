%%% @doc EUnit tests for the cost factories, including the paper's Fig. 7 check.
-module(pe_cost_tests).

-include_lib("eunit/include/eunit.hrl").

%% Cost of a layout (a list of line lengths) rendered at column C, per the
%% paper's inductive Cost definition (Section 3.2): the first line is charged
%% at column C, each subsequent line is a newline plus text at column 0.
cost_of_lines(Mod, W, C, [L1 | Rest]) ->
    lists:foldl(
        fun(Ln, Acc) ->
            Mod:combine(Mod:combine(Acc, Mod:nl_cost(W, 0)), Mod:text_cost(W, 0, Ln))
        end,
        Mod:text_cost(W, C, L1),
        Rest
    ).

%% A1S1-7: reproduce Fig. 7 with the Example-3.4 (linear overflow) factory.
%% Both layouts render at column 3 with page width 6.
%%   Layout 1 (flat):  one line of length 23           -> (20, 0)
%%   Layout 2 (broken): lines of length 7, 9, 7, 1     -> (8, 3)
fig7_cost_test() ->
    ?assertEqual({20, 0}, cost_of_lines(pe_cost_overflow, 6, 3, [23])),
    ?assertEqual({8, 3}, cost_of_lines(pe_cost_overflow, 6, 3, [7, 9, 7, 1])).

%% The squared factory's Fig. 7 costs (Example 3.5): 20^2 = 400 and
%% 4^2 + 3^2 + 1^2 + 0^2 = 26.
fig7_squared_cost_test() ->
    ?assertEqual({400, 0}, cost_of_lines(pe_cost_squared, 6, 3, [23])),
    ?assertEqual({26, 3}, cost_of_lines(pe_cost_squared, 6, 3, [7, 9, 7, 1])).

%% No overflow below the width: both factories charge nothing.
no_overflow_test() ->
    ?assertEqual({0, 0}, pe_cost_squared:text_cost(80, 0, 10)),
    ?assertEqual({0, 0}, pe_cost_overflow:text_cost(80, 0, 10)),
    ?assertEqual({0, 1}, pe_cost_squared:nl_cost(80, 0)).

%% le is exactly the lexicographic comparison on {Overflow, Height}.
le_lexicographic_test() ->
    ?assert(pe_cost_squared:le({8, 3}, {20, 0})),
    ?assertNot(pe_cost_squared:le({20, 0}, {8, 3})),
    ?assert(pe_cost_squared:le({8, 3}, {8, 4})),
    ?assert(pe_cost_squared:le({8, 3}, {8, 3})).
