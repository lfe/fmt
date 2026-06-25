%%% @doc Small public facade over the resolver and renderer.
%%%
%%% A convenience surface for tests and harnesses — not the final library API.
%%% `resolve/2' is a thin pass-through to {@link pe_resolve:resolve/2} (full
%%% opts). `format/2' and `format_binary/2' take a partial options map, fill in
%%% defaults, resolve the optimal layout, and render it.
%%%
%%% Defaults: `cost => pe_cost_squared', `memo => pe_memo_map', `width => 80',
%%% `limit => width'.
%%% @end
-module(pe).

-moduledoc "Small public facade over the resolver and renderer.".

-export([resolve/2, format/2, format_binary/2]).

-doc "Resolve a document to its optimal measure (pass-through, full opts).".
-spec resolve(pe_doc:dag(), pe_resolve:opts()) ->
    {pe_measure:measure(), pe_resolve:stats()}.
resolve(Dag, Opts) ->
    pe_resolve:resolve(Dag, Opts).

-doc "Resolve and render to an iolist, applying defaults to a partial options map.".
-spec format(pe_doc:dag(), map()) ->
    {iolist(), pe_measure:measure(), pe_resolve:stats()}.
format(Dag, Opts) ->
    {Measure, Stats} = pe_resolve:resolve(Dag, with_defaults(Opts)),
    Iolist = pe_render:render(pe_measure:doc(Measure)),
    {Iolist, Measure, Stats}.

-doc "Resolve and render to a binary, applying defaults to a partial options map.".
-spec format_binary(pe_doc:dag(), map()) ->
    {binary(), pe_measure:measure(), pe_resolve:stats()}.
format_binary(Dag, Opts) ->
    {Iolist, Measure, Stats} = format(Dag, Opts),
    {iolist_to_binary(Iolist), Measure, Stats}.

%% Fill defaults; limit defaults to mjl's `trunc(1.2 * page_width)'.
-spec with_defaults(map()) -> pe_resolve:opts().
with_defaults(Opts) ->
    Width = maps:get(width, Opts, 80),
    #{
        cost => maps:get(cost, Opts, pe_cost_squared),
        memo => maps:get(memo, Opts, pe_memo_map),
        width => Width,
        %% Computation-width limit defaults to mjl's `trunc(1.2 * page_width)'
        %% (cost.rs `limit()`), not the page width. A reviewed default change
        %% (slice8 / operator 2026-06-24), recorded in running-recommendations.
        limit => maps:get(limit, Opts, trunc(1.2 * Width))
    }.
