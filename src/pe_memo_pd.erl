%%% @doc Memo backend: the process dictionary, namespaced by a per-call ref.
%%%
%%% `new/0' returns a fresh `reference()' used to namespace this call's keys, so
%%% nested or sequential resolves on the same process never collide. `put/3'
%%% mutates the process dictionary and returns the same ref (a constant handle);
%%% `dispose/1' erases exactly this call's keys.
%%%
%%% The process dictionary is hostile to testing and to the let-it-crash
%%% posture; this backend exists only to <em>measure</em> it against the map and
%%% ETS backends, not as a recommendation.
%%% @end
-module(pe_memo_pd).

-moduledoc "Memo backend: the process dictionary, namespaced by a per-call ref.".

-behaviour(pe_memo).

-export([new/0, find/2, put/3, dispose/1]).

-spec new() -> reference().
new() ->
    make_ref().

-spec find(pe_memo:key(), reference()) -> {ok, pe_mset:mset()} | error.
find(Key, Ref) ->
    case erlang:get({Ref, Key}) of
        undefined -> error;
        Value -> {ok, Value}
    end.

-spec put(pe_memo:key(), pe_mset:mset(), reference()) -> reference().
put(Key, Value, Ref) ->
    _ = erlang:put({Ref, Key}, Value),
    Ref.

-spec dispose(reference()) -> ok.
dispose(Ref) ->
    _ = [
        erlang:erase(StoredKey)
     || {{R, _Key} = StoredKey, _Value} <- erlang:get(), R =:= Ref
    ],
    ok.
