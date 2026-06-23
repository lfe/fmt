%%% @doc Test-only cost factory that crashes in `text_cost/3'.
%%%
%%% Used to verify the resolver's `try … after' disposes a memo backend's
%%% resources even when resolution raises mid-call.
-module(pe_cost_crash).

-behaviour(pe_cost).

-export([le/2, combine/2, text_cost/3, nl_cost/2]).

le(A, B) -> A =< B.

combine({Oa, Ha}, {Ob, Hb}) -> {Oa + Ob, Ha + Hb}.

text_cost(_W, _C, _L) -> error(boom).

nl_cost(_W, _I) -> {0, 1}.
