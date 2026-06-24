%%% @doc PropEr properties: the frontier instrumentation is observation-only —
%%% it changes neither the optimal measure nor any other counter — and the
%%% resolver still matches the oracle with the flag on.
-module(prop_pe_frontier).

-include_lib("proper/include/proper.hrl").

-export([prop_frontier_invariant/0, prop_frontier_oracle/0]).

-define(SQ, pe_cost_squared).

dag() ->
    ?LET(
        Sym,
        proper_types:resize(7, pe_gen:doc_sym()),
        begin
            {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
            pe_doc:freeze(B, Root)
        end
    ).

%% A1S7-5/6: flag-on vs flag-off return the identical optimal measure and the
%% identical memo_size/calls/tainted counters; the `frontier' key appears iff on.
%% limit = width here so taint actually occurs, exercising the tainted counter.
prop_frontier_invariant() ->
    ?FORALL(
        {Dag, Width},
        {dag(), range(1, 20)},
        begin
            Base = #{cost => ?SQ, memo => pe_memo_map, width => Width, limit => Width},
            {MeasureOff, StatsOff} = pe_resolve:resolve(Dag, Base),
            {MeasureOn, StatsOn} = pe_resolve:resolve(Dag, Base#{frontier_stats => true}),
            MeasureOff =:= MeasureOn andalso
                StatsOff =:= maps:remove(frontier, StatsOn) andalso
                not maps:is_key(frontier, StatsOff) andalso
                maps:is_key(frontier, StatsOn)
        end
    ).

%% A1S7-8: with a computation limit large enough to taint nothing, the resolver's
%% optimal cost equals the brute-force oracle's — with the frontier flag on.
prop_frontier_oracle() ->
    ?FORALL(
        {Dag, Width},
        {dag(), range(1, 20)},
        begin
            Opts = #{
                cost => ?SQ,
                memo => pe_memo_map,
                width => Width,
                limit => 1000000,
                frontier_stats => true
            },
            {Resolved, _Stats} = pe_resolve:resolve(Dag, Opts),
            Oracle = pe_gen:oracle_optimal(Dag, ?SQ, Width),
            pe_measure:cost(Resolved) =:= pe_measure:cost(Oracle)
        end
    ).
