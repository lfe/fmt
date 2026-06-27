%%%% lfmt_SUITE: the public multi-engine API (lfmt:new/1 + format/1,2 dispatch).
%%%% Covers validation, dispatch, the no-silent-ignore guarantee, and parity
%%%% (the API layer changes no output vs lfmt_fezzik:format/1).
-module(lfmt_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).
-export([
    new_defaults_fezzik/1,
    new_fezzik_ok/1,
    new_pe_unavailable/1,
    new_pc_unavailable/1,
    new_unknown_engine/1,
    new_unknown_option/1,
    format2_dispatch/1,
    format1_default/1,
    parity/1
]).

all() ->
    [
        new_defaults_fezzik,
        new_fezzik_ok,
        new_pe_unavailable,
        new_pc_unavailable,
        new_unknown_engine,
        new_unknown_option,
        format2_dispatch,
        format1_default,
        parity
    ].

%% new(#{}) defaults to fezzik — verified behaviourally (opts() is opaque):
%% the default handle formats exactly like lfmt_fezzik.
new_defaults_fezzik(_Config) ->
    H = lfmt:new(#{}),
    ?assertEqual(lfmt_fezzik:format(<<"(a b)">>), lfmt:format(H, <<"(a b)">>)).

new_fezzik_ok(_Config) ->
    _ = lfmt:new(#{engine => fezzik}),
    ok.

%% reserved engines error clearly (not silently) — engine is named in the type
%% but not yet available.
new_pe_unavailable(_Config) ->
    ?assertError({engine_not_available, pe}, lfmt:new(#{engine => pe})).

new_pc_unavailable(_Config) ->
    ?assertError({engine_not_available, pc}, lfmt:new(#{engine => pc})).

new_unknown_engine(_Config) ->
    ?assertError({unknown_engine, bogus}, lfmt:new(#{engine => bogus})).

%% the no-hollow-options guarantee: an unknown key is rejected, never dropped.
new_unknown_option(_Config) ->
    ?assertError({unknown_option, width}, lfmt:new(#{width => 100})).

format2_dispatch(_Config) ->
    H = lfmt:new(#{engine => fezzik}),
    ?assertEqual(lfmt_fezzik:format(<<"(foo)">>), lfmt:format(H, <<"(foo)">>)).

format1_default(_Config) ->
    ?assertEqual(lfmt_fezzik:format(<<"(foo bar)">>), lfmt:format(<<"(foo bar)">>)).

%% Parity: the API layer changes no output. Over a sample of inputs,
%% lfmt:format(lfmt:new(#{engine=>fezzik}), S) === lfmt_fezzik:format(S).
parity(_Config) ->
    H = lfmt:new(#{engine => fezzik}),
    Inputs = [
        <<"(defun f (x) (+ x 1))">>,
        <<"(a (b c) d)">>,
        <<"'foo">>,
        <<"#m(k v)">>,
        <<"(let ((x 1)) (+ x 1))">>,
        <<";;; section\n(defun g () ok)">>,
        <<"(foo bar) ; trailing">>,
        <<>>
    ],
    lists:foreach(
        fun(S) ->
            ?assertEqual(lfmt_fezzik:format(S), lfmt:format(H, S))
        end,
        Inputs
    ).
