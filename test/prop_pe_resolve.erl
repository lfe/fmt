%%% @doc PropEr property: the resolver's optimum equals the brute-force oracle.
-module(prop_pe_resolve).

-include_lib("proper/include/proper.hrl").

-export([prop_resolver_optimal/0]).

-define(SQ, pe_cost_squared).

%% A1S1-11: with a computation limit large enough to taint nothing, the
%% resolver's optimal cost equals the brute-force oracle's optimal cost, over
%% random small documents and a range of page widths.
prop_resolver_optimal() ->
    ?FORALL(
        {Sym, PageWidth},
        {proper_types:resize(7, pe_gen:doc_sym()), range(1, 20)},
        begin
            {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
            Dag = pe_doc:freeze(B, Root),
            Opts = #{cost => ?SQ, memo => pe_memo_map, width => PageWidth, limit => 1000000},
            {Resolved, _Stats} = pe_resolve:resolve(Dag, Opts),
            Oracle = pe_gen:oracle_optimal(Dag, ?SQ, PageWidth),
            pe_measure:cost(Resolved) =:= pe_measure:cost(Oracle)
        end
    ).
