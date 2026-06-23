%%% @doc PropEr properties for {@link pe_doc}.
-module(prop_pe_doc).

-include_lib("proper/include/proper.hrl").

-export([prop_topo_ids/0]).

%% A1S1-4: ids are dense and assigned bottom-up, so every child id is strictly
%% less than its parent id (a free topological order).
prop_topo_ids() ->
    ?FORALL(
        Sym,
        pe_gen:doc_sym(),
        begin
            {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
            Dag = pe_doc:freeze(B, Root),
            lists:all(
                fun(Id) ->
                    lists:all(fun(Child) -> Child < Id end, pe_doc:children(Dag, Id))
                end,
                lists:seq(0, pe_doc:size(Dag) - 1)
            )
        end
    ).
