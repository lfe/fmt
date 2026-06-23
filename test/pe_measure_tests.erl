%%% @doc EUnit tests for {@link pe_measure} (Figs. 12–13).
-module(pe_measure_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SQ, pe_cost_squared).
-define(OV, pe_cost_overflow).

%% Leaf measures carry last, cost, and the choiceless doc.
text_leaf_test() ->
    ?assertEqual(
        {3, {0, 0}, {text, <<"abc">>}},
        pe_measure:text_leaf(<<"abc">>, 3, 0, ?SQ, 80)
    ),
    %% starting at a column that overflows charges squared overflow.
    ?assertEqual(
        {12, {(12 - 6) * (12 - 6), 0}, {text, <<"abcdef">>}},
        pe_measure:text_leaf(<<"abcdef">>, 6, 6, ?SQ, 6)
    ).

%% LineM: a newline's cost is nlF +F textF(0, Indent) — indentation past the
%% width is charged even though nl_cost itself is {0, 1}.
nl_leaf_test() ->
    ?assertEqual({2, {0, 1}, nl}, pe_measure:nl_leaf(2, ?SQ, 80)),
    %% indent 10 past width 6: textF(0,10) = (10-6)^2 = 16, plus height 1.
    ?assertEqual({10, {16, 1}, nl}, pe_measure:nl_leaf(10, ?SQ, 6)).

compose_test() ->
    Ma = {3, {1, 0}, {text, <<"a">>}},
    Mb = {5, {2, 1}, {text, <<"b">>}},
    ?assertEqual(
        {5, {3, 1}, {concat, {text, <<"a">>}, {text, <<"b">>}}},
        pe_measure:compose(Ma, Mb, ?SQ)
    ).

adjust_test() ->
    M = {5, {2, 0}, {text, <<"z">>}},
    ?assertEqual({5, {2, 0}, {nest, 4, {text, <<"z">>}}}, pe_measure:adjust_nest(4, M)),
    ?assertEqual({5, {2, 0}, {align, {text, <<"z">>}}}, pe_measure:adjust_align(7, M)).

dominates_test() ->
    A = {3, {1, 0}, ignore},
    B = {5, {2, 1}, ignore},
    ?assert(pe_measure:dominates(A, B, ?SQ)),
    ?assertNot(pe_measure:dominates(B, A, ?SQ)),
    %% reflexive: equal last and cost dominate.
    ?assert(pe_measure:dominates(A, A, ?SQ)),
    %% incomparable: lower last but higher cost.
    C = {2, {9, 0}, ignore},
    ?assertNot(pe_measure:dominates(A, C, ?SQ)),
    ?assertNot(pe_measure:dominates(C, A, ?SQ)).

%% A1S1-8 anchor: measure_term reproduces the broken Fig. 7 layout's cost (8, 3)
%% with last line length 1, using the linear-overflow factory at column 3, w=6.
%% Document is Example 3.1:
%%   "= func(" <> nest 2 (nl <> "pretty," <> nl <> "print") <> nl <> ")"
measure_term_fig7_test() ->
    Inner =
        {concat, nl,
            {concat, {text, <<"pretty,">>}, {concat, nl, {text, <<"print">>}}}},
    Doc =
        {concat, {text, <<"= func(">>},
            {concat, {nest, 2, Inner}, {concat, nl, {text, <<")">>}}}},
    M = pe_measure:measure_term(Doc, 3, 0, ?OV, 6),
    ?assertEqual(1, pe_measure:last(M)),
    ?assertEqual({8, 3}, pe_measure:cost(M)).

%% The flattened layout (all nl -> space) is one line and costs (20, 0).
measure_term_fig7_flat_test() ->
    Sp = {text, <<" ">>},
    Doc =
        {concat, {text, <<"= func(">>},
            {concat, {nest, 2, {concat, Sp, {concat, {text, <<"pretty,">>}, {concat, Sp, {text, <<"print">>}}}}},
                {concat, Sp, {text, <<")">>}}}},
    M = pe_measure:measure_term(Doc, 3, 0, ?OV, 6),
    ?assertEqual({20, 0}, pe_measure:cost(M)).
