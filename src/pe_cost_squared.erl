%%% @doc Default cost factory: squared overflow, then height (paper Example 3.5).
%%%
%%% Cost is `{Badness, Height}' compared lexicographically (Erlang term order on
%%% the tuple <em>is</em> lexicographic, so `le' is `=<'). `Badness' is the sum
%%% of squared overflow past the page width; `Height' is the newline count.
%%%
%%% `text_cost' accumulates squared overflow one placement at a time via the
%%% identity `(a+b)² − a² = b·(2a+b)', where `a' is how far past the width the
%%% placement starts and `b' is its overflow length. This is the engine's
%%% production default.
%%% @end
-module(pe_cost_squared).

-moduledoc "Default cost factory: squared overflow, then height.".

-behaviour(pe_cost).

-export([le/2, combine/2, text_cost/3, nl_cost/2]).

-export_type([cost/0]).

-doc "`{Badness, Height}', ordered lexicographically.".
-type cost() :: {non_neg_integer(), non_neg_integer()}.

-doc "Total order: Erlang term order on `{Badness, Height}' is lexicographic.".
-spec le(cost(), cost()) -> boolean().
le(A, B) -> A =< B.

-doc "Componentwise addition; identity is `{0, 0}' = `text_cost(W, 0, 0)'.".
-spec combine(cost(), cost()) -> cost().
combine({Oa, Ha}, {Ob, Hb}) -> {Oa + Ob, Ha + Hb}.

-doc "Squared-overflow delta `b·(2a+b)' for text of length `L' starting at column `C'.".
-spec text_cost(non_neg_integer(), non_neg_integer(), non_neg_integer()) -> cost().
text_cost(W, C, L) when C + L > W ->
    A = max(W, C) - W,
    B = C + L - max(W, C),
    {B * (2 * A + B), 0};
text_cost(_W, _C, _L) ->
    {0, 0}.

-doc "A newline costs one unit of height; indentation overflow is charged by the engine.".
-spec nl_cost(non_neg_integer(), non_neg_integer()) -> cost().
nl_cost(_W, _I) -> {0, 1}.
