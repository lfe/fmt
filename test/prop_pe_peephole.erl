%%% @doc PropEr property: the smart-constructor peepholes are transparent.
%%%
%%% The resolver renders through the dag produced by pe_doc's smart constructors
%%% (every transparent peephole — `(Text 0,_)=>rhs', `(_,Text 0)=>self',
%%% `(Text,Text)' merge, cost push-out, the nest/align/reset short-circuits —
%%% has already fired). The oracle here widens the SYMBOLIC tree directly
%%% (`pe_gen:oracle_optimal_sym/3'), never building a dag, so it never sees a
%%% peephole. Equal optimal cost over random inputs therefore proves the
%%% peepholes did not silently change output or cost (A1S8-8) — a guard the
%%% dag-driven `prop_resolver_optimal' cannot give, since both its sides share
%%% the peepholed dag.
-module(prop_pe_peephole).

-include_lib("proper/include/proper.hrl").

-export([prop_peephole_transparent/0]).

-define(SQ, pe_cost_squared).

prop_peephole_transparent() ->
    ?FORALL(
        {Sym, PageWidth},
        {proper_types:resize(7, pe_gen:doc_sym()), range(1, 20)},
        begin
            {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
            Dag = pe_doc:freeze(B, Root),
            %% Huge limit => nothing is tainted, so the resolver reaches the true
            %% optimum and any discrepancy is a peephole, not a dropped layout.
            Opts = #{cost => ?SQ, memo => pe_memo_map, width => PageWidth, limit => 1000000},
            case pe_gen:oracle_optimal_sym(Sym, ?SQ, PageWidth) of
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
