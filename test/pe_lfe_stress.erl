%%% @doc Test-only pathological LFE/S-expression stress corpus for slice4.
%%%
%%% The corpus is deterministic and deliberately broad rather than huge. Most
%%% samples lower through {@link pe_lfe:to_doc/1}; a few direct-document samples
%%% isolate engine behaviour such as shared DAGs and forced no-fit text.
%%%
%%% `size/1' is the nominal generator size (items, bindings, depth, or text
%%% width). `dag_size' in the benchmark is `pe_doc:size/1', the number of
%%% hash-consed reachable document nodes in the frozen DAG.
-module(pe_lfe_stress).

-export([all/0, by_id/1, build/1, id/1, label/1, category/1, size/1, form/1]).

-export_type([sample/0]).

-record(sample, {
    id :: binary(),
    label :: binary(),
    category :: binary(),
    size :: non_neg_integer(),
    payload :: payload()
}).

-opaque sample() :: #sample{}.

-type payload() :: {lfe, pe_lfe:form()} | {doc, doc_kind()}.
-type doc_kind() ::
    {long_text, pos_integer()}
    | {shared_concat, non_neg_integer()}
    | {shared_choice, non_neg_integer()}
    | {tiny_call, pos_integer()}.

-spec all() -> [sample()].
all() ->
    samples().

-spec by_id(binary()) -> sample().
by_id(Id) when is_binary(Id) ->
    case lists:filter(fun(#sample{id = I}) -> I =:= Id end, samples()) of
        [S] -> S;
        [] -> error({unknown_stress_sample, Id})
    end.

-spec build(sample()) -> pe_doc:dag().
build(#sample{payload = {lfe, Form}}) ->
    pe_lfe:to_doc(Form);
build(#sample{payload = {doc, Kind}}) ->
    build_doc(Kind).

-spec form(sample()) -> pe_lfe:form() | undefined.
form(#sample{payload = {lfe, Form}}) -> Form;
form(#sample{payload = {doc, _}}) -> undefined.

-spec id(sample()) -> binary().
id(#sample{id = Id}) -> Id.

-spec label(sample()) -> binary().
label(#sample{label = Label}) -> Label.

-spec category(sample()) -> binary().
category(#sample{category = Category}) -> Category.

-spec size(sample()) -> non_neg_integer().
size(#sample{size = Size}) -> Size.

%%%-------------------------------------------------------------------
%%% Corpus
%%%-------------------------------------------------------------------

samples() ->
    [
        s(
            <<"proper_list_24">>,
            <<"proper list, 24 items">>,
            <<"proper-list">>,
            24,
            {lfe, lst(symbols(<<"p">>, 24))}
        ),
        s(
            <<"proper_list_48">>,
            <<"proper list, 48 items">>,
            <<"proper-list">>,
            48,
            {lfe, lst(symbols(<<"p">>, 48))}
        ),
        s(
            <<"dotted_list_16">>,
            <<"dotted list, 16 prefixes">>,
            <<"dotted-list">>,
            16,
            {lfe, dl(symbols(<<"d">>, 16), sym(<<"tail">>))}
        ),
        s(
            <<"dotted_list_32">>,
            <<"dotted list, 32 prefixes">>,
            <<"dotted-list">>,
            32,
            {lfe, dl(symbols(<<"d">>, 32), sym(<<"tail">>))}
        ),
        s(
            <<"generic_call_24">>,
            <<"generic call, 24 args">>,
            <<"generic-call">>,
            24,
            {lfe, call([sym(<<"unknown-fn">>) | symbols(<<"arg">>, 24)])}
        ),
        s(
            <<"generic_call_48">>,
            <<"generic call, 48 args">>,
            <<"generic-call">>,
            48,
            {lfe, call([sym(<<"unknown-fn">>) | symbols(<<"arg">>, 48)])}
        ),
        s(
            <<"deep_sexp_8">>,
            <<"deep generic S-expression, depth 8">>,
            <<"deep-sexp">>,
            8,
            {lfe, deep_sexp(8)}
        ),
        s(
            <<"deep_sexp_12">>,
            <<"deep generic S-expression, depth 12">>,
            <<"deep-sexp">>,
            12,
            {lfe, deep_sexp(12)}
        ),
        s(
            <<"shared_concat_10">>,
            <<"direct shared concat DAG, depth 10">>,
            <<"shared-dag">>,
            10,
            {doc, {shared_concat, 10}}
        ),
        s(
            <<"shared_choice_8">>,
            <<"direct shared choice DAG, depth 8">>,
            <<"shared-dag">>,
            8,
            {doc, {shared_choice, 8}}
        ),
        s(
            <<"quote_tower_12">>,
            <<"quote/backquote/unquote tower, depth 12">>,
            <<"quote-tower">>,
            12,
            {lfe, quote_tower(12)}
        ),
        s(
            <<"quote_tower_18">>,
            <<"quote/backquote/unquote tower, depth 18">>,
            <<"quote-tower">>,
            18,
            {lfe, quote_tower(18)}
        ),
        s(
            <<"let_bindings_16">>,
            <<"let with 16 bindings">>,
            <<"binding-list">>,
            16,
            {lfe, let_like(<<"let">>, 16)}
        ),
        s(
            <<"letstar_bindings_24">>,
            <<"let* with 24 bindings">>,
            <<"binding-list">>,
            24,
            {lfe, let_like(<<"let*">>, 24)}
        ),
        s(
            <<"fletrec_bindings_12">>,
            <<"fletrec with 12 local functions">>,
            <<"binding-list">>,
            12,
            {lfe, fletrec_like(12)}
        ),
        s(
            <<"nested_case_8">>,
            <<"nested case clauses, depth 8">>,
            <<"clause-form">>,
            8,
            {lfe, nested_case(8)}
        ),
        s(
            <<"nested_receive_6">>,
            <<"nested receive clauses, depth 6">>,
            <<"clause-form">>,
            6,
            {lfe, nested_receive(6)}
        ),
        s(
            <<"nested_cond_12">>,
            <<"cond with 12 clauses">>,
            <<"clause-form">>,
            12,
            {lfe, cond_like(12)}
        ),
        s(
            <<"block_arg_match_lambda">>,
            <<"match-lambda as call argument">>,
            <<"block-argument">>,
            8,
            {lfe, block_arg(<<"match-lambda">>)}
        ),
        s(
            <<"block_arg_lambda">>,
            <<"lambda as call argument">>,
            <<"block-argument">>,
            8,
            {lfe, block_arg(<<"lambda">>)}
        ),
        s(
            <<"block_arg_case">>,
            <<"case as call argument">>,
            <<"block-argument">>,
            8,
            {lfe, block_arg(<<"case">>)}
        ),
        s(
            <<"block_arg_receive">>,
            <<"receive as call argument">>,
            <<"block-argument">>,
            8,
            {lfe, block_arg(<<"receive">>)}
        ),
        s(
            <<"nofit_text_80">>,
            <<"direct text wider than narrow limits">>,
            <<"forced-nofit">>,
            80,
            {doc, {long_text, 80}}
        ),
        s(
            <<"nofit_text_180">>,
            <<"direct text much wider than normal width">>,
            <<"forced-nofit">>,
            180,
            {doc, {long_text, 180}}
        ),
        s(
            <<"tiny_width_call_30">>,
            <<"generic call with 30 long atoms">>,
            <<"forced-nofit">>,
            30,
            {doc, {tiny_call, 30}}
        )
    ].

s(Id, Label, Category, Size, Payload) ->
    #sample{id = Id, label = Label, category = Category, size = Size, payload = Payload}.

%%%-------------------------------------------------------------------
%%% LFE form builders
%%%-------------------------------------------------------------------

sym(Bin) -> {sym, Bin}.
int(N) -> {int, N}.
lst(Fs) -> {list, Fs}.
dl(Fs, Tail) -> {dotted_list, Fs, Tail}.
call(Fs) -> {call, Fs}.
q(F) -> {quote, F}.
bq(F) -> {bquote, F}.
uq(F) -> {unquote, F}.
tup(Fs) -> {tuple, Fs}.

symbols(Prefix, N) ->
    [sym(label(Prefix, I)) || I <- lists:seq(1, N)].

label(Prefix, I) ->
    IOBin = integer_to_binary(I),
    <<Prefix/binary, "_", IOBin/binary>>.

deep_sexp(0) ->
    sym(<<"leaf">>);
deep_sexp(N) ->
    call([sym(label(<<"g">>, N)), deep_sexp(N - 1), lst(symbols(label(<<"xs">>, N), 3))]).

quote_tower(0) ->
    call([sym(<<"compute">>), sym(<<"x">>), lst(symbols(<<"q">>, 4))]);
quote_tower(N) when N rem 3 =:= 0 ->
    q(quote_tower(N - 1));
quote_tower(N) when N rem 3 =:= 1 ->
    bq(quote_tower(N - 1));
quote_tower(N) ->
    uq(quote_tower(N - 1)).

let_like(Kw, N) ->
    Bindings = [
        lst([sym(label(<<"v">>, I)), call([sym(<<"+">>), int(I), int(I + 1)])])
     || I <- lists:seq(1, N)
    ],
    call([sym(Kw), lst(Bindings), call([sym(<<"list">>) | symbols(<<"v">>, min(N, 12))])]).

fletrec_like(N) ->
    Bindings = [local_fun(I) || I <- lists:seq(1, N)],
    call([sym(<<"fletrec">>), lst(Bindings), call([sym(<<"f1">>), int(N)])]).

local_fun(I) ->
    Name = sym(label(<<"f">>, I)),
    Arg = sym(label(<<"x">>, I)),
    lst([Name, lst([Arg]), call([sym(<<"+">>), Arg, int(I)])]).

nested_case(0) ->
    sym(<<"done">>);
nested_case(N) ->
    call([
        sym(<<"case">>),
        sym(label(<<"value">>, N)),
        lst([q(sym(<<"stop">>)), sym(<<"done">>)]),
        lst([sym(label(<<"x">>, N)), nested_case(N - 1)])
    ]).

nested_receive(0) ->
    call([sym(<<"receive">>), lst([sym(<<"msg">>), sym(<<"msg">>)])]);
nested_receive(N) ->
    call([
        sym(<<"receive">>),
        lst([tup([q(sym(<<"next">>)), sym(label(<<"m">>, N))]), nested_receive(N - 1)]),
        lst([sym(<<"after">>), int(N), sym(<<"timeout">>)])
    ]).

cond_like(N) ->
    Clauses = [
        lst([call([sym(<<">">>), sym(<<"x">>), int(I)]), call([sym(<<"handle">>), int(I)])])
     || I <- lists:seq(1, N)
    ],
    call([sym(<<"cond">>) | Clauses]).

block_arg(<<"match-lambda">>) ->
    call([
        sym(<<"lists:foreach">>),
        call([
            sym(<<"match-lambda">>),
            lst([lst([sym(<<"x">>)]), call([sym(<<"handle">>), sym(<<"x">>)])]),
            lst([lst([sym(<<"y">>)]), call([sym(<<"handle-other">>), sym(<<"y">>)])])
        ]),
        call([sym(<<"items">>)])
    ]);
block_arg(<<"lambda">>) ->
    call([
        sym(<<"lists:map">>),
        call([sym(<<"lambda">>), lst([sym(<<"x">>)]), call([sym(<<"transform">>), sym(<<"x">>)])]),
        call([sym(<<"items">>)])
    ]);
block_arg(<<"case">>) ->
    call([
        sym(<<"consume">>),
        call([
            sym(<<"case">>),
            sym(<<"event">>),
            lst([q(sym(<<"ok">>)), call([sym(<<"handle-ok">>)])]),
            lst([sym(<<"x">>), call([sym(<<"handle-error">>), sym(<<"x">>)])])
        ])
    ]);
block_arg(<<"receive">>) ->
    call([
        sym(<<"with-timeout">>),
        call([
            sym(<<"receive">>),
            lst([sym(<<"msg">>), call([sym(<<"handle">>), sym(<<"msg">>)])]),
            lst([sym(<<"after">>), int(10), sym(<<"timeout">>)])
        ])
    ]).

%%%-------------------------------------------------------------------
%%% Direct document builders
%%%-------------------------------------------------------------------

build_doc({long_text, N}) ->
    {Root, B} = pe_doc:text(binary:copy(<<"x">>, N), pe_doc:new()),
    pe_doc:freeze(B, Root);
build_doc({shared_concat, N}) ->
    {Root, B} = shared_concat(N, pe_doc:new()),
    pe_doc:freeze(B, Root);
build_doc({shared_choice, N}) ->
    {Root, B} = shared_choice(N, pe_doc:new()),
    pe_doc:freeze(B, Root);
build_doc({tiny_call, N}) ->
    Form = call([sym(<<"very-long-generic-head-name">>) | symbols(<<"very_long_argument_name">>, N)]),
    pe_lfe:to_doc(Form).

shared_concat(0, B) ->
    pe_doc:text(<<"shared-leaf">>, B);
shared_concat(N, B0) ->
    {Id, B1} = shared_concat(N - 1, B0),
    pe_doc:concat(Id, Id, B1).

shared_choice(0, B) ->
    pe_doc:text(<<"choice-leaf">>, B);
shared_choice(N, B0) ->
    {Id, B1} = shared_choice(N - 1, B0),
    {Break, B2} = pe_doc:vconcat(Id, Id, B1),
    {Flat, B3} = pe_doc:concat(Id, Id, B2),
    pe_doc:choice(Flat, Break, B3).
