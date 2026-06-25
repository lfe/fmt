%%% @doc PropEr property: the resolver's optimum equals the brute-force oracle.
-module(prop_pe_resolve).

-include_lib("proper/include/proper.hrl").

-export([prop_resolver_optimal/0]).

-define(SQ, pe_cost_squared).

%% A1S1-11 / A1S8-13: with a computation limit large enough to taint nothing,
%% the resolver's optimal cost equals the brute-force oracle's, over random small
%% documents (now spanning the full mjl algebra: fail/brk/hard_nl/reset/cost) and
%% a range of page widths. A document with no valid layout (`failed' oracle) must
%% make the resolver report `no_valid_layout' too.
prop_resolver_optimal() ->
    ?FORALL(
        {Sym, PageWidth},
        {proper_types:resize(7, pe_gen:doc_sym()), range(1, 20)},
        begin
            {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
            Dag = pe_doc:freeze(B, Root),
            Opts = #{cost => ?SQ, memo => pe_memo_map, width => PageWidth, limit => 1000000},
            case pe_gen:oracle_optimal(Dag, ?SQ, PageWidth) of
                failed ->
                    try pe_resolve:resolve(Dag, Opts) of
                        _ -> false
                    catch
                        error:no_valid_layout -> true
                    end;
                Oracle ->
                    {Resolved, _Stats} = pe_resolve:resolve(Dag, Opts),
                    pe_measure:cost(Resolved) =:= pe_measure:cost(Oracle)
            end
        end
    ).
