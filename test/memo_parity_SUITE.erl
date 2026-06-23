%%% @doc CT suite (A1S1-13): the three memo backends produce the identical
%%% optimal measure (last, cost, and choiceless document) on the same inputs.
-module(memo_parity_SUITE).

-include_lib("eunit/include/eunit.hrl").

-export([all/0, parity/1]).

all() ->
    [parity].

parity(_Config) ->
    Widths = [1, 2, 3, 6, 10, 40, 80],
    [parity_one(Dag, Width) || Dag <- docs(), Width <- Widths],
    ok.

parity_one(Dag, Width) ->
    Opts = fun(Memo) ->
        #{cost => pe_cost_squared, memo => Memo, width => Width, limit => 1000}
    end,
    {Map, _} = pe_resolve:resolve(Dag, Opts(pe_memo_map)),
    {Ets, _} = pe_resolve:resolve(Dag, Opts(pe_memo_ets)),
    {Pd, _} = pe_resolve:resolve(Dag, Opts(pe_memo_pd)),
    %% full-measure equality, not just cost.
    ?assertEqual(Map, Ets),
    ?assertEqual(Map, Pd).

%% A spread of documents exercising every construct, built via the shared
%% symbolic interpreter.
docs() ->
    Syms = [
        {group, {vconcat, {text, <<"aaa">>}, {text, <<"bbb">>}}},
        {choice, {concat, {text, <<"xx">>}, {text, <<"yy">>}},
            {vconcat, {text, <<"xx">>}, {text, <<"yy">>}}},
        {nest, 2, {group, {vconcat, {text, <<"a">>}, {vconcat, {text, <<"b">>}, {text, <<"c">>}}}}},
        {align, {group, {vconcat, {text, <<"foo">>}, {text, <<"bar">>}}}},
        %% an S-expression-like document: (define (f x) body)
        {concat, {text, <<"(define ">>},
            {group,
                {nest, 2,
                    {vconcat, {text, <<"(f x)">>}, {concat, {text, <<"body">>}, {text, <<")">>}}}}}}
    ],
    [
        begin
            {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
            pe_doc:freeze(B, Root)
        end
     || Sym <- Syms
    ].
