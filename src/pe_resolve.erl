%%% @doc The resolver: find the cost-optimal measure of a document (paper Fig. 15).
%%%
%%% `resolve/2' is `⇓RS'/`⇓RSC' fused with measure computation, with pruning
%%% baked into the {@link pe_mset:merge/3} and memoization keyed on
%%% `{Id, Column, Indent}'. It is parameterised by a cost factory, a memo
%%% backend, the page `width', and the computation-width `limit' `W'.
%%%
%%% Two efficiency points from §6 are load-bearing:
%%% <ul>
%%%   <li><b>Delay beyond `W'</b> (Lemma 6.9): resolving at a column or
%%%       indentation past `W' returns a <em>tainted</em> set immediately —
%%%       without recursing or memoizing — so the work stays bounded
%%%       (`O(n·W²)' memo entries) and `shared&lt;&gt;shared' stays linear.</li>
%%%   <li><b>Lazy tainted</b>: tainted measures are held behind thunks and never
%%%       forced during resolution (merging discards a tainted beside a `Set'),
%%%       so the exponential cost of a fully-overflowing layout is paid at most
%%%       once, only if the whole document is tainted.</li>
%%% </ul>
%%%
%%% There is no rendering here: correctness is at the cost/measure level (the
%%% returned measure carries the choiceless document for slice2's renderer).
%%% @end
-module(pe_resolve).

-moduledoc "The resolver: find the cost-optimal measure of a document (Fig. 15).".

-export([resolve/2]).

-export_type([opts/0, stats/0]).

-doc "Resolver options: cost factory, memo backend, page width, computation limit.".
-type opts() :: #{
    cost := module(),
    memo := module(),
    width := non_neg_integer(),
    limit := non_neg_integer()
}.

-doc "Diagnostics: distinct memo entries, resolver invocations, tainted results.".
-type stats() :: #{
    memo_size := non_neg_integer(),
    calls := non_neg_integer(),
    tainted := non_neg_integer()
}.

%% Immutable config plus the threaded handle and counters.
-record(rs, {
    dag :: pe_doc:dag(),
    cost :: module(),
    memo :: module(),
    page_width :: non_neg_integer(),
    limit :: non_neg_integer(),
    handle :: pe_memo:handle(),
    calls = 0 :: non_neg_integer(),
    tainted = 0 :: non_neg_integer(),
    memo_size = 0 :: non_neg_integer()
}).

-doc "Resolve a document to its optimal measure and resolver statistics.".
-spec resolve(pe_doc:dag(), opts()) -> {pe_measure:measure(), stats()}.
resolve(Dag, #{cost := CostMod, memo := MemoMod, width := PageWidth, limit := Limit}) ->
    Handle0 = MemoMod:new(),
    RS0 = #rs{
        dag = Dag,
        cost = CostMod,
        memo = MemoMod,
        page_width = PageWidth,
        limit = Limit,
        handle = Handle0
    },
    try
        {Set, RS} = resolve_node(pe_doc:root(Dag), 0, 0, RS0),
        Optimal = pe_mset:optimal(Set),
        Stats = #{
            memo_size => RS#rs.memo_size,
            calls => RS#rs.calls,
            tainted => RS#rs.tainted
        },
        {Optimal, Stats}
    after
        MemoMod:dispose(Handle0)
    end.

%%%-------------------------------------------------------------------
%%% ⇓RS — resolve a node under a printing context
%%%-------------------------------------------------------------------

-spec resolve_node(pe_doc:id(), non_neg_integer(), non_neg_integer(), #rs{}) ->
    {pe_mset:mset(), #rs{}}.
resolve_node(Id, C, I, RS0) ->
    RS = RS0#rs{calls = RS0#rs.calls + 1},
    W = RS#rs.limit,
    case C > W orelse I > W of
        true ->
            %% Delay beyond W: a tainted promise, no recursion, no memo.
            Thunk = fun() -> tainted_measure(Id, C, I, RS) end,
            {pe_mset:tainted_lazy(Thunk), RS#rs{tainted = RS#rs.tainted + 1}};
        false ->
            #rs{memo = Memo, handle = H} = RS,
            Key = {Id, C, I},
            case Memo:find(Key, H) of
                {ok, Set} ->
                    {Set, RS};
                error ->
                    {Set, RS1} = compute_node(Id, C, I, RS),
                    H1 = Memo:put(Key, Set, RS1#rs.handle),
                    Tainted =
                        case pe_mset:is_tainted(Set) of
                            true -> RS1#rs.tainted + 1;
                            false -> RS1#rs.tainted
                        end,
                    {Set, RS1#rs{handle = H1, memo_size = RS1#rs.memo_size + 1, tainted = Tainted}}
            end
    end.

-spec compute_node(pe_doc:id(), non_neg_integer(), non_neg_integer(), #rs{}) ->
    {pe_mset:mset(), #rs{}}.
compute_node(Id, C, I, RS) ->
    case pe_doc:get(RS#rs.dag, Id) of
        {text, S, Width} -> resolve_text(S, Width, C, RS);
        nl -> resolve_nl(I, RS);
        {concat, A, B} -> resolve_concat(Id, A, B, C, I, RS);
        {nest, N, D} -> resolve_nest(N, D, C, I, RS);
        {align, D} -> resolve_align(D, C, I, RS);
        {choice, A, B} -> resolve_choice(A, B, C, I, RS)
    end.

%% TextRS / TextRSTnt: here C =< W and I =< W (the entry guard), so a text taints
%% only when placing it would pass W.
resolve_text(S, Width, C, #rs{cost = CM, page_width = PW, limit = W} = RS) ->
    M = pe_measure:text_leaf(S, Width, C, CM, PW),
    case C + Width =< W of
        true -> {pe_mset:singleton(M), RS};
        false -> {pe_mset:tainted(M), RS}
    end.

%% LineRS: here C =< W and I =< W, so a newline always resolves to a Set.
resolve_nl(I, #rs{cost = CM, page_width = PW} = RS) ->
    {pe_mset:singleton(pe_measure:nl_leaf(I, CM, PW)), RS}.

%% ConcatRS / ConcatRSTnt.
resolve_concat(Id, A, B, C, I, RS) ->
    {Sa, RS1} = resolve_node(A, C, I, RS),
    case Sa of
        {set, Measures} ->
            concat_set(Measures, B, I, RS1);
        {tainted, _} ->
            %% Left is tainted: the whole concat is tainted. Defer the measure
            %% (leftmost widening) and do not resolve B — that keeps it bounded.
            Thunk = fun() -> tainted_measure(Id, C, I, RS1) end,
            {pe_mset:tainted_lazy(Thunk), RS1}
    end.

%% For each left measure (cost-ascending), resolve-and-concatenate the right
%% (⇓RSC), then merge all the resulting sets left-to-right.
-spec concat_set([pe_measure:measure(), ...], pe_doc:id(), non_neg_integer(), #rs{}) ->
    {pe_mset:mset(), #rs{}}.
concat_set([M1 | Rest], B, I, RS) ->
    {S1, RS1} = rsc(M1, B, I, RS),
    lists:foldl(
        fun(M, {AccSet, AccRS}) ->
            {Sk, RS2} = rsc(M, B, I, AccRS),
            {pe_mset:merge(AccSet, Sk, RS2#rs.cost), RS2}
        end,
        {S1, RS1},
        Rest
    ).

%% ⇓RSC: concatenate a fixed left measure with the right's resolved set.
-spec rsc(pe_measure:measure(), pe_doc:id(), non_neg_integer(), #rs{}) ->
    {pe_mset:mset(), #rs{}}.
rsc(M, B, I, RS) ->
    {Sb, RS1} = resolve_node(B, pe_measure:last(M), I, RS),
    CM = RS1#rs.cost,
    case Sb of
        {set, Measures} ->
            Composed = [pe_measure:compose(M, Mb, CM) || Mb <- Measures],
            {{set, pe_mset:dedup(Composed, CM)}, RS1};
        {tainted, _} ->
            Thunk = fun() -> pe_measure:compose(M, pe_mset:optimal(Sb), CM) end,
            {pe_mset:tainted_lazy(Thunk), RS1}
    end.

%% NestRS.
resolve_nest(N, D, C, I, RS) ->
    {Set, RS1} = resolve_node(D, C, I + N, RS),
    {pe_mset:lift(Set, fun(M) -> pe_measure:adjust_nest(N, M) end), RS1}.

%% AlignRS. The align node's own (C, I) already passed the entry guard, so
%% C =< W; resolving the child at indentation C stays within the limit, and the
%% i > W case (AlignRSTnt) is subsumed by the delay-beyond-W entry guard.
resolve_align(D, C, I, RS) ->
    {Set, RS1} = resolve_node(D, C, C, RS),
    {pe_mset:lift(Set, fun(M) -> pe_measure:adjust_align(I, M) end), RS1}.

%% UnionRS: resolve both branches and merge (left-biased on taint).
resolve_choice(A, B, C, I, RS) ->
    {Sa, RS1} = resolve_node(A, C, I, RS),
    {Sb, RS2} = resolve_node(B, C, I, RS1),
    {pe_mset:merge(Sa, Sb, RS2#rs.cost), RS2}.

%%%-------------------------------------------------------------------
%%% Tainted fallback: one valid (not necessarily optimal) measure
%%%-------------------------------------------------------------------

%% A tainted set need only hold one valid measure (no optimality is promised
%% past W). We take the leftmost widening and measure it directly — O(subtree),
%% but computed only if this thunk is ever forced.
-spec tainted_measure(pe_doc:id(), non_neg_integer(), non_neg_integer(), #rs{}) ->
    pe_measure:measure().
tainted_measure(Id, C, I, #rs{dag = Dag, cost = CM, page_width = PW}) ->
    pe_measure:measure_term(leftmost(Dag, Id), C, I, CM, PW).

-spec leftmost(pe_doc:dag(), pe_doc:id()) -> pe_measure:cdoc().
leftmost(Dag, Id) ->
    case pe_doc:get(Dag, Id) of
        {text, S, _W} -> {text, S};
        nl -> nl;
        {concat, A, B} -> {concat, leftmost(Dag, A), leftmost(Dag, B)};
        {nest, N, D} -> {nest, N, leftmost(Dag, D)};
        {align, D} -> {align, leftmost(Dag, D)};
        {choice, A, _B} -> leftmost(Dag, A)
    end.
