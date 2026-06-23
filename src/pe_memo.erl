%%% @doc The memoization behaviour: one resolver, three interchangeable backends.
%%%
%%% The resolver memoizes measure-set results keyed by `{Id, Column, Indent}'
%%% (only within the computation-width limit `W'). It threads a handle and uses
%%% the result, so the <em>same</em> resolver code runs over all three backends:
%%% {@link pe_memo_map} genuinely threads a new map; {@link pe_memo_ets} and
%%% {@link pe_memo_pd} thread a constant handle and mutate behind it.
%%%
%%% `dispose/1' is the lifecycle hook the resolver calls in a `try … after',
%%% so an ETS table (or process-dictionary keys) is always cleaned up — even
%%% on a crash. This is the apples-to-apples backend comparison.
%%% @end
-module(pe_memo).

-moduledoc "The memoization behaviour: one resolver, three interchangeable backends.".

-export_type([handle/0, key/0]).

-doc "A memo key: a node id under a printing context (column, indentation).".
-type key() :: {pe_doc:id(), non_neg_integer(), non_neg_integer()}.

-doc "Backend-specific handle (a map value, an ETS tid, or a process-dict ref).".
-type handle() :: term().

-callback new() -> handle().
-callback find(key(), handle()) -> {ok, pe_mset:mset()} | error.
-callback put(key(), pe_mset:mset(), handle()) -> handle().
-callback dispose(handle()) -> ok.
