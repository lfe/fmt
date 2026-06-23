%%% @doc Memo backend: a private ETS table, owned and disposed per resolve call.
%%%
%%% `new/0' creates a `private' table owned by the calling (resolver) process;
%%% `put/3' mutates it and returns the same tid (a constant handle). The
%%% resolver calls `dispose/1' in a `try … after', so the table is deleted
%%% before `resolve/2' returns — no leak across calls, even on a crash.
%%% @end
-module(pe_memo_ets).

-moduledoc "Memo backend: a private ETS table, owned and disposed per resolve call.".

-behaviour(pe_memo).

-export([new/0, find/2, put/3, dispose/1]).

-spec new() -> ets:tid().
new() ->
    ets:new(pe_memo, [private, set]).

-spec find(pe_memo:key(), ets:tid()) -> {ok, pe_mset:mset()} | error.
find(Key, Tid) ->
    case ets:lookup(Tid, Key) of
        [{_Key, Value}] -> {ok, Value};
        [] -> error
    end.

-spec put(pe_memo:key(), pe_mset:mset(), ets:tid()) -> ets:tid().
put(Key, Value, Tid) ->
    true = ets:insert(Tid, {Key, Value}),
    Tid.

-spec dispose(ets:tid()) -> ok.
dispose(Tid) ->
    true = ets:delete(Tid),
    ok.
