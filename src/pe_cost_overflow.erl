%%% @doc Test-only cost factory: sum of overflow, then height (paper Example 3.4).
%%%
%%% Cost is `{Overflow, Height}' compared lexicographically, where `Overflow' is
%%% the linear sum of characters past the page width. It exists to prove the
%%% factory is genuinely pluggable and to reproduce the paper's Fig. 7 numbers
%%% ((20,0) and (8,3) at column 3, width 6); production uses
%%% {@link pe_cost_squared} instead.
%%% @end
-module(pe_cost_overflow).

-moduledoc "Test-only cost factory: linear sum of overflow, then height (Example 3.4).".

-behaviour(pe_cost).

-export([le/2, combine/2, text_cost/3, nl_cost/2]).

-export_type([cost/0]).

-doc "`{Overflow, Height}', ordered lexicographically.".
-type cost() :: {non_neg_integer(), non_neg_integer()}.

-spec le(cost(), cost()) -> boolean().
le(A, B) -> A =< B.

-spec combine(cost(), cost()) -> cost().
combine({Oa, Ha}, {Ob, Hb}) -> {Oa + Ob, Ha + Hb}.

-doc "Linear overflow: the number of characters of this placement past the width.".
-spec text_cost(non_neg_integer(), non_neg_integer(), non_neg_integer()) -> cost().
text_cost(W, C, L) ->
    {max(C + L - max(W, C), 0), 0}.

-spec nl_cost(non_neg_integer(), non_neg_integer()) -> cost().
nl_cost(_W, _I) -> {0, 1}.
