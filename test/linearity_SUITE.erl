%%% @doc CT suite (A1S1-12): the paper's `shared <> shared' chain `mk(n)' (DAG
%%% size O(n), tree size O(2^n)) resolves with memo size and call count linear
%%% in the DAG size — the memoization + delay-beyond-W bound, not the
%%% exponential blow-up of Example 6.3.
-module(linearity_SUITE).

-include_lib("eunit/include/eunit.hrl").

-export([all/0, linear/1]).

%% Computation-width limit. Beyond it the resolver delays (taints) instead of
%% recursing, which is what bounds the work.
-define(LIMIT, 16).
-define(WIDTH, 16).
-define(MAX_N, 14).

all() ->
    [linear].

linear(_Config) ->
    Series = [{N, resolve_mk(N)} || N <- lists:seq(1, ?MAX_N)],
    ct:pal(
        "mk(n) linearity (limit=~p): ~p",
        [?LIMIT, [{N, MemoSize, Calls} || {N, {MemoSize, Calls, _}} <- Series]]
    ),
    %% (1) Every point sits under the linear bound (DAG size) * (LIMIT + 1):
    %% one column band per node, indentation 0 throughout. Exponential growth
    %% would blow past this immediately.
    [check_bound(N, R) || {N, R} <- Series],
    %% (2) The per-level memo growth plateaus to a small constant — linear, not
    %% doubling. (Exponential would double the increment each level.)
    MemoSizes = [MemoSize || {_, {MemoSize, _, _}} <- Series],
    Increments = increments(MemoSizes),
    ?assert(lists:max(Increments) =< ?LIMIT + 1),
    ?assert(lists:last(Increments) =< 2),
    %% (3) Decisively non-exponential at the top of the range.
    {MaxN, {TopMemo, _, _}} = lists:last(Series),
    ?assert(TopMemo * 100 < (1 bsl MaxN)).

check_bound(N, {MemoSize, Calls, _Cost}) ->
    DagSize = N + 1,
    MemoBound = DagSize * (?LIMIT + 1),
    ?assert(MemoSize =< MemoBound),
    ?assert(Calls =< MemoBound * (?LIMIT + 2)).

increments([A, B | Rest]) -> [B - A | increments([B | Rest])];
increments(_) -> [].

resolve_mk(N) ->
    {Root, B} = mk(N, pe_doc:new()),
    Dag = pe_doc:freeze(B, Root),
    Opts = #{cost => pe_cost_squared, memo => pe_memo_map, width => ?WIDTH, limit => ?LIMIT},
    {Measure, Stats} = pe_resolve:resolve(Dag, Opts),
    {maps:get(memo_size, Stats), maps:get(calls, Stats), pe_measure:cost(Measure)}.

%% mk(0) = "x"; mk(n) = let shared = mk(n-1) in shared <> shared. Hash-consing
%% makes concat(Id, Id) one node with two refs, so the DAG has n+1 nodes.
mk(0, B) ->
    pe_doc:text(<<"x">>, B);
mk(N, B0) ->
    {Id, B1} = mk(N - 1, B0),
    pe_doc:concat(Id, Id, B1).
