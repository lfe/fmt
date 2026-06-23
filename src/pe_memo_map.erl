%%% @doc Memo backend: a functionally-threaded immutable map.
%%%
%%% `put/3' returns a <em>new</em> map, which the resolver threads forward. No
%%% mutation, no cleanup obligation — `dispose/1' is a no-op. This is the pure,
%%% testable reference backend.
%%% @end
-module(pe_memo_map).

-moduledoc "Memo backend: a functionally-threaded immutable map.".

-behaviour(pe_memo).

-export([new/0, find/2, put/3, dispose/1]).

-spec new() -> #{pe_memo:key() => pe_mset:mset()}.
new() -> #{}.

-spec find(pe_memo:key(), #{pe_memo:key() => pe_mset:mset()}) -> {ok, pe_mset:mset()} | error.
find(Key, Map) ->
    case Map of
        #{Key := Value} -> {ok, Value};
        _ -> error
    end.

-spec put(pe_memo:key(), pe_mset:mset(), #{pe_memo:key() => pe_mset:mset()}) ->
    #{pe_memo:key() => pe_mset:mset()}.
put(Key, Value, Map) ->
    Map#{Key => Value}.

-spec dispose(#{pe_memo:key() => pe_mset:mset()}) -> ok.
dispose(_Map) -> ok.
