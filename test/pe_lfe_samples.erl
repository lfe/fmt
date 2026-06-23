%%% @doc Test-only fixture corpus: 20 hand-built, real-LFE-shaped documents.
%%%
%%% Each sample is a plain "spec" tree (data) that {@link build/1} interprets
%%% into a frozen {@link pe_doc} DAG. This is <em>not</em> the LFE knowledge
%%% layer: there is no parser and no general per-form rules — the specs are
%%% written by hand to resemble the source forms' layout choices, enough to
%%% stress the engine and exercise rendering. Expected output is a canonicalised
%%% shape, not byte-for-byte source.
%%%
%%% A small spec vocabulary models S-expression layout:
%%% <ul>
%%%   <li>`a/1' atom/symbol, `str/1' string, `q/1'/`bq/1'/`uq/1'
%%%       quote/backquote/unquote;</li>
%%%   <li>`sx/1' a call form `(head arg…)' with args aligned under the first
%%%       arg; `lst/1' a plain list, `tup/1' a tuple `#(…)';</li>
%%%   <li>`hs/1' an always-inline space-joined run (form headers);</li>
%%%   <li>`blk/2' / `cl/2' a head line with a vertically-indented body
%%%       (special forms and clauses).</li>
%%% </ul>
%%% Every shaped form is wrapped in a `group', so the resolver chooses flat vs
%%% broken by cost.
-module(pe_lfe_samples).

-export([all/0, by_id/1, build/1, id/1, label/1, source/1, tags/1]).

-export_type([sample/0]).

-record(sample, {
    id :: atom(),
    label :: binary(),
    source :: binary(),
    tags :: [atom()],
    spec :: spec()
}).

-opaque sample() :: #sample{}.

-type spec() ::
    {txt, binary()}
    | {str, binary()}
    | {quote, spec()}
    | {bq, spec()}
    | {uq, spec()}
    | {hsep, [spec()]}
    | {sexp, [spec()]}
    | {list, [spec()]}
    | {tuple, [spec()]}
    | {indent, spec(), [spec()]}.

%%%-------------------------------------------------------------------
%%% Accessors (the stable surface)
%%%-------------------------------------------------------------------

-spec all() -> [sample()].
all() -> samples().

-spec by_id(atom()) -> sample().
by_id(Id) ->
    case lists:keyfind(Id, #sample.id, samples()) of
        #sample{} = S -> S;
        false -> error({unknown_sample, Id})
    end.

-spec build(sample()) -> pe_doc:dag().
build(#sample{spec = Spec}) ->
    {Root, B} = build_spec(Spec, pe_doc:new()),
    pe_doc:freeze(B, Root).

-spec id(sample()) -> atom().
id(#sample{id = Id}) -> Id.

-spec label(sample()) -> binary().
label(#sample{label = L}) -> L.

-spec source(sample()) -> binary().
source(#sample{source = S}) -> S.

-spec tags(sample()) -> [atom()].
tags(#sample{tags = T}) -> T.

%%%-------------------------------------------------------------------
%%% Spec constructors (readable, local sugar)
%%%-------------------------------------------------------------------

a(Bin) -> {txt, Bin}.
str(Bin) -> {str, Bin}.
q(Spec) -> {quote, Spec}.
bq(Spec) -> {bq, Spec}.
uq(Spec) -> {uq, Spec}.
hs(Specs) -> {hsep, Specs}.
sx(Specs) -> {sexp, Specs}.
lst(Specs) -> {list, Specs}.
tup(Specs) -> {tuple, Specs}.
blk(Head, Body) -> {indent, Head, Body}.
cl(Pat, Body) -> {indent, Pat, Body}.

%% Common headers.
defun(Name, Clauses) -> blk(hs([a(<<"defun">>), a(Name)]), Clauses).
defmacro(Name, Clauses) -> blk(hs([a(<<"defmacro">>), a(Name)]), Clauses).
caseof(Subject, Clauses) -> blk(hs([a(<<"case">>), Subject]), Clauses).

%%%-------------------------------------------------------------------
%%% Interpreter: spec -> pe_doc DAG (threading the builder)
%%%-------------------------------------------------------------------

-spec build_spec(spec(), pe_doc:builder()) -> {pe_doc:id(), pe_doc:builder()}.
build_spec({txt, Bin}, B) ->
    pe_doc:text(Bin, B);
build_spec({str, S}, B) ->
    pe_doc:text(<<$", S/binary, $">>, B);
build_spec({quote, S}, B) ->
    prefixed(<<"'">>, S, B);
build_spec({bq, S}, B) ->
    prefixed(<<"`">>, S, B);
build_spec({uq, S}, B) ->
    prefixed(<<",">>, S, B);
build_spec({hsep, Specs}, B0) ->
    {Ids, B1} = build_list(Specs, B0),
    join_space(Ids, B1);
build_spec({sexp, Specs}, B0) ->
    build_sexp(Specs, B0);
build_spec({list, Specs}, B0) ->
    build_bracket(<<"(">>, <<")">>, Specs, B0);
build_spec({tuple, Specs}, B0) ->
    build_bracket(<<"#(">>, <<")">>, Specs, B0);
build_spec({indent, Head, Body}, B0) ->
    build_indent(Head, Body, B0).

%% "head arg…" — a call form: head, a space, then args aligned and softly
%% broken under the first arg. The whole thing is a group.
build_sexp([HeadSpec], B0) ->
    {H, B1} = build_spec(HeadSpec, B0),
    wrap_parens(H, B1);
build_sexp([HeadSpec | ArgSpecs], B0) ->
    {H, B1} = build_spec(HeadSpec, B0),
    {ArgIds, B2} = build_list(ArgSpecs, B1),
    {Body, B3} = join_nl(ArgIds, B2),
    {Aligned, B4} = pe_doc:align(Body, B3),
    {Sp, B5} = pe_doc:text(<<" ">>, B4),
    {HeadSp, B6} = pe_doc:concat(H, Sp, B5),
    {Inner, B7} = pe_doc:concat(HeadSp, Aligned, B6),
    {Grouped, B8} = group_parens(Inner, B7),
    {Grouped, B8}.

%% "(item… )" — bracketed, all items aligned and softly broken; a group.
build_bracket(Open, Close, [], B0) ->
    {O, B1} = pe_doc:text(Open, B0),
    {C, B2} = pe_doc:text(Close, B1),
    pe_doc:concat(O, C, B2);
build_bracket(Open, Close, Specs, B0) ->
    {Ids, B1} = build_list(Specs, B0),
    {Body, B2} = join_nl(Ids, B1),
    {Aligned, B3} = pe_doc:align(Body, B2),
    {O, B4} = pe_doc:text(Open, B3),
    {C, B5} = pe_doc:text(Close, B4),
    {OBody, B6} = pe_doc:concat(O, Aligned, B5),
    {Full, B7} = pe_doc:concat(OBody, C, B6),
    pe_doc:group(Full, B7).

%% "(head <newline+2 body…>)" — a head line then a vertically-indented body;
%% a group, so short forms still flatten.
build_indent(HeadSpec, BodySpecs, B0) ->
    {H, B1} = build_spec(HeadSpec, B0),
    {BodyIds, B2} = build_list(BodySpecs, B1),
    {BodyDoc, B3} = join_nl(BodyIds, B2),
    {Nl, B4} = pe_doc:nl(B3),
    {NlBody, B5} = pe_doc:concat(Nl, BodyDoc, B4),
    {Nested, B6} = pe_doc:nest(2, NlBody, B5),
    {HNested, B7} = pe_doc:concat(H, Nested, B6),
    group_parens(HNested, B7).

%%%-------------------------------------------------------------------
%%% Interpreter helpers
%%%-------------------------------------------------------------------

prefixed(Prefix, Spec, B0) ->
    {T, B1} = pe_doc:text(Prefix, B0),
    {Id, B2} = build_spec(Spec, B1),
    pe_doc:concat(T, Id, B2).

build_list([], B) ->
    {[], B};
build_list([S | Ss], B0) ->
    {Id, B1} = build_spec(S, B0),
    {Ids, B2} = build_list(Ss, B1),
    {[Id | Ids], B2}.

%% Join ids with a literal space (always inline).
join_space([Id], B) ->
    {Id, B};
join_space([Id | Rest], B0) ->
    {RestId, B1} = join_space(Rest, B0),
    {Sp, B2} = pe_doc:text(<<" ">>, B1),
    {SpRest, B3} = pe_doc:concat(Sp, RestId, B2),
    pe_doc:concat(Id, SpRest, B3).

%% Join ids with a soft newline (a space when flattened, a break otherwise).
join_nl([Id], B) ->
    {Id, B};
join_nl([Id | Rest], B0) ->
    {RestId, B1} = join_nl(Rest, B0),
    {Nl, B2} = pe_doc:nl(B1),
    {NlRest, B3} = pe_doc:concat(Nl, RestId, B2),
    pe_doc:concat(Id, NlRest, B3).

wrap_parens(Id, B0) ->
    {O, B1} = pe_doc:text(<<"(">>, B0),
    {C, B2} = pe_doc:text(<<")">>, B1),
    {OId, B3} = pe_doc:concat(O, Id, B2),
    pe_doc:concat(OId, C, B3).

group_parens(Inner, B0) ->
    {O, B1} = pe_doc:text(<<"(">>, B0),
    {C, B2} = pe_doc:text(<<")">>, B1),
    {OInner, B3} = pe_doc:concat(O, Inner, B2),
    {Full, B4} = pe_doc:concat(OInner, C, B3),
    pe_doc:group(Full, B4).

%%%-------------------------------------------------------------------
%%% The 20 samples
%%%-------------------------------------------------------------------

samples() ->
    [
        sample(
            lfe_01_ackermann,
            <<"ackermann/2 multi-clause defun">>,
            <<"synthetic (Duncan's prompt) ackermann/2">>,
            [defun, pattern_match, recursion],
            defun(<<"ackermann">>, [
                cl(lst([a(<<"0">>), a(<<"n">>)]), [sx([a(<<"+">>), a(<<"n">>), a(<<"1">>)])]),
                cl(lst([a(<<"m">>), a(<<"0">>)]), [
                    sx([a(<<"ackermann">>), sx([a(<<"-">>), a(<<"m">>), a(<<"1">>)]), a(<<"1">>)])
                ]),
                cl(lst([a(<<"m">>), a(<<"n">>)]), [
                    sx([
                        a(<<"ackermann">>),
                        sx([a(<<"-">>), a(<<"m">>), a(<<"1">>)]),
                        sx([a(<<"ackermann">>), a(<<"m">>), sx([a(<<"-">>), a(<<"n">>), a(<<"1">>)])])
                    ])
                ])
            ])
        ),
        sample(
            lfe_02_fizz,
            <<"fizz/3 string clauses">>,
            <<"examples/fizzbuzz.lfe:53 fizz/3">>,
            [defun, pattern_match, strings],
            defun(<<"fizz">>, [
                cl(lst([a(<<"0">>), a(<<"0">>), a(<<"_">>)]), [str(<<"fizzbuzz">>)]),
                cl(lst([a(<<"0">>), a(<<"_">>), a(<<"_">>)]), [str(<<"fizz">>)]),
                cl(lst([a(<<"_">>), a(<<"0">>), a(<<"_">>)]), [str(<<"buzz">>)]),
                cl(lst([a(<<"_">>), a(<<"_">>), a(<<"n">>)]), [a(<<"n">>)])
            ])
        ),
        sample(
            lfe_03_buzz1,
            <<"buzz1/1 guarded head">>,
            <<"examples/fizzbuzz.lfe:72 buzz1/1">>,
            [defun, guard],
            defun(<<"buzz1">>, [
                cl(lst([a(<<"n">>)]), [
                    sx([a(<<"when">>), sx([a(<<"==">>), a(<<"0">>), sx([a(<<"rem">>), a(<<"n">>), a(<<"5">>)])])]),
                    str(<<"buzz">>)
                ]),
                cl(lst([a(<<"_">>)]), [str(<<"">>)])
            ])
        ),
        sample(
            lfe_04_tail_buzz,
            <<"tail-buzz/2 tail recursion">>,
            <<"examples/fizzbuzz.lfe:116 tail-buzz/2">>,
            [defun, guard, recursion],
            defun(<<"tail-buzz">>, [
                cl(lst([a(<<"n">>), a(<<"acc">>)]), [
                    sx([a(<<"when">>), sx([a(<<"=<">>), a(<<"n">>), a(<<"0">>)])]),
                    sx([a(<<"lists:reverse">>), a(<<"acc">>)])
                ]),
                cl(lst([a(<<"n">>), a(<<"acc">>)]), [
                    sx([
                        a(<<"tail-buzz">>),
                        sx([a(<<"-">>), a(<<"n">>), a(<<"1">>)]),
                        sx([a(<<"cons">>), sx([a(<<"buzz1">>), a(<<"n">>)]), a(<<"acc">>)])
                    ])
                ])
            ])
        ),
        sample(
            lfe_05_plusplus,
            <<"++ macro with quasiquote/rest">>,
            <<"examples/core-macros.lfe:55 ++">>,
            [defmacro, quasiquote, rest_args],
            defmacro(<<"++">>, [
                cl(lst([]), [q(lst([]))]),
                cl(lst([a(<<"l">>)]), [a(<<"l">>)]),
                cl(lst([a(<<"l">>), a(<<".">>), a(<<"ls">>)]), [
                    bq(sx([
                        a(<<"lists:append">>),
                        uq(a(<<"l">>)),
                        sx([a(<<"++">>), a(<<".">>), uq(a(<<"ls">>))])
                    ]))
                ])
            ])
        ),
        sample(
            lfe_06_cond,
            <<"cond macro expanding to if">>,
            <<"examples/core-macros.lfe:100 cond">>,
            [defmacro, quasiquote, alternatives],
            defmacro(<<"cond">>, [
                cl(lst([a(<<"c">>)]), [a(<<"c">>)]),
                cl(lst([lst([q(a(<<"else">>)), a(<<".">>), a(<<"body">>)]), a(<<".">>), a(<<"_">>)]), [
                    bq(sx([a(<<"progn">>), a(<<".">>), uq(a(<<"body">>))]))
                ]),
                cl(lst([lst([a(<<"test">>), a(<<".">>), a(<<"body">>)]), a(<<".">>), a(<<"clauses">>)]), [
                    bq(sx([
                        a(<<"if">>),
                        uq(a(<<"test">>)),
                        sx([a(<<"progn">>), a(<<".">>), uq(a(<<"body">>))]),
                        sx([a(<<"cond">>), a(<<".">>), uq(a(<<"clauses">>))])
                    ]))
                ])
            ])
        ),
        sample(
            lfe_07_bq_expand,
            <<"bq-expand inside eval-when-compile">>,
            <<"examples/core-macros.lfe:125 backquote/bq-expand">>,
            [defmacro, quasiquote, nested, case_form],
            sx([
                a(<<"eval-when-compile">>),
                defun(<<"bq-expand">>, [
                    cl(lst([a(<<"exp">>), a(<<"n">>)]), [
                        caseof(a(<<"exp">>), [
                            cl(tup([q(a(<<"unquote">>)), a(<<"e">>)]), [
                                sx([a(<<"when">>), sx([a(<<">">>), a(<<"n">>), a(<<"0">>)])]),
                                tup([q(a(<<"unquote">>)), sx([a(<<"bq-expand">>), a(<<"e">>), sx([a(<<"-">>), a(<<"n">>), a(<<"1">>)])])])
                            ]),
                            cl(tup([q(a(<<"unquote">>)), a(<<"e">>)]), [a(<<"e">>)]),
                            cl(sx([a(<<"cons">>), q(a(<<"backquote">>)), a(<<"x">>)]), [
                                sx([a(<<"bq-expand-list">>), a(<<"exp">>), sx([a(<<"+">>), a(<<"n">>), a(<<"1">>)])])
                            ]),
                            cl(a(<<"x">>), [sx([a(<<"bq-expand-list">>), a(<<"x">>), a(<<"n">>)])])
                        ])
                    ])
                ])
            ])
        ),
        sample(
            lfe_08_ets_new,
            <<"ets-demo new/0 with match-lambda">>,
            <<"examples/ets-demo.lfe:50 new/0">>,
            [defun, records, lambda, side_effects],
            defun(<<"new">>, [
                cl(lst([]), [
                    blk(
                        hs([
                            a(<<"let">>),
                            lst([
                                lst([
                                    a(<<"tab">>),
                                    sx([a(<<"ets:new">>), q(a(<<"places">>)), sx([a(<<"list">>), q(a(<<"named_table">>)), q(a(<<"public">>))])])
                                ])
                            ])
                        ]),
                        [
                            sx([
                                a(<<"lists:foreach">>),
                                blk(hs([a(<<"match-lambda">>)]), [
                                    cl(lst([bq(tup([uq(a(<<"name">>)), uq(a(<<"desc">>))]))]), [
                                        sx([a(<<"ets:insert">>), a(<<"tab">>), sx([a(<<"make-place">>), a(<<"name">>), a(<<"name">>), a(<<"desc">>), a(<<"desc">>)])])
                                    ])
                                ]),
                                sx([a(<<"default-places">>)])
                            ]),
                            a(<<"tab">>)
                        ]
                    )
                ])
            ])
        ),
        sample(
            lfe_09_by_place_ms,
            <<"by_place_ms/2 match-spec">>,
            <<"examples/ets-demo.lfe:86 by_place_ms/2">>,
            [defun, match_spec, records, guard],
            defun(<<"by_place_ms">>, [
                cl(lst([a(<<"place">>), a(<<"min">>)]), [
                    bq(lst([
                        tup([
                            sx([a(<<"match-place">>), q(a(<<"_">>)), uq(a(<<"place">>)), q(a(<<"$1">>))]),
                            lst([sx([a(<<">=">>), q(a(<<"$1">>)), uq(a(<<"min">>))])]),
                            lst([q(a(<<"$1">>))])
                        ])
                    ]))
                ])
            ])
        ),
        sample(
            lfe_10_mnesia_new,
            <<"mnesia-demo new/0 transaction">>,
            <<"examples/mnesia-demo.lfe:50 new/0">>,
            [defun, records, lambda, backquote, otp],
            defun(<<"new">>, [
                cl(lst([]), [
                    sx([
                        a(<<"mnesia:create_table">>),
                        q(a(<<"place">>)),
                        bq(lst([
                            tup([a(<<"attributes">>), uq(sx([a(<<"fields">>), q(a(<<"place">>))]))]),
                            tup([a(<<"disc_copies">>), lst([sx([a(<<"node">>)])])]),
                            tup([a(<<"type">>), q(a(<<"set">>))])
                        ]))
                    ])
                ])
            ])
        ),
        sample(
            lfe_11_guess_server,
            <<"guess-server/1 receive loop">>,
            <<"examples/guessing-game2.lfe:61 guess-server/1">>,
            [defun, receive_form, records, recursion],
            defun(<<"guess-server">>, [
                cl(lst([a(<<"state">>)]), [
                    blk(hs([a(<<"receive">>)]), [
                        cl(tup([q(a(<<"guess">>)), a(<<"from">>), a(<<"n">>)]), [
                            sx([a(<<"when">>), sx([a(<<"is_integer">>), a(<<"n">>)])]),
                            sx([a(<<"!">>), a(<<"from">>), sx([a(<<"check">>), a(<<"state">>), a(<<"n">>)])]),
                            sx([a(<<"guess-server">>), a(<<"state">>)])
                        ]),
                        cl(q(a(<<"stop">>)), [q(a(<<"ok">>))])
                    ])
                ])
            ])
        ),
        sample(
            lfe_12_ping_pong,
            <<"ping-pong gen_server callbacks">>,
            <<"examples/ping-pong.lfe:73 handle_call/handle_cast">>,
            [defun, otp, records, backquote],
            blk(hs([a(<<"progn">>)]), [
                defun(<<"handle_call">>, [
                    cl(lst([q(a(<<"ping">>)), a(<<"_from">>), a(<<"state">>)]), [
                        tup([
                            q(a(<<"reply">>)),
                            q(a(<<"pong">>)),
                            sx([a(<<"set-state-pings">>), a(<<"state">>), sx([a(<<"+">>), sx([a(<<"state-pings">>), a(<<"state">>)]), a(<<"1">>)])])
                        ])
                    ])
                ]),
                defun(<<"handle_cast">>, [
                    cl(lst([q(a(<<"pong">>)), a(<<"state">>)]), [
                        tup([q(a(<<"noreply">>)), a(<<"state">>)])
                    ])
                ])
            ])
        ),
        sample(
            lfe_13_get_page,
            <<"get-page/1 async httpc">>,
            <<"examples/http-async.lfe:124 get-page/1">>,
            [defun, receive_form, otp, alternatives],
            defun(<<"get-page">>, [
                cl(lst([a(<<"url">>)]), [
                    blk(
                        hs([
                            a(<<"let">>),
                            lst([
                                lst([
                                    tup([q(a(<<"ok">>)), a(<<"id">>)]),
                                    sx([a(<<"httpc:request">>), q(a(<<"get">>)), tup([a(<<"url">>), lst([])]), lst([]), lst([tup([a(<<"sync">>), q(a(<<"false">>))])])])
                                ])
                            ])
                        ]),
                        [
                            blk(hs([a(<<"receive">>)]), [
                                cl(tup([q(a(<<"http">>)), tup([a(<<"id">>), q(a(<<"result">>)), a(<<"body">>)])]), [
                                    tup([q(a(<<"ok">>)), a(<<"body">>)])
                                ]),
                                cl(tup([q(a(<<"http">>)), tup([a(<<"id">>), q(a(<<"error">>)), a(<<"reason">>)])]), [
                                    tup([q(a(<<"error">>)), a(<<"reason">>)])
                                ])
                            ])
                        ]
                    )
                ])
            ])
        ),
        sample(
            lfe_14_fish_closure,
            <<"fish-class/3 closure object">>,
            <<"examples/object-via-closure.lfe:92 fish-class/3">>,
            [defun, lambda, case_form, backquote],
            defun(<<"fish-class">>, [
                cl(lst([a(<<"species">>), a(<<"weight">>), a(<<"children">>)]), [
                    blk(hs([a(<<"lambda">>), lst([a(<<"method">>), a(<<"args">>)])]), [
                        caseof(a(<<"method">>), [
                            cl(q(a(<<"species">>)), [a(<<"species">>)]),
                            cl(q(a(<<"weight">>)), [a(<<"weight">>)]),
                            cl(q(a(<<"grow">>)), [
                                sx([a(<<"fish-class">>), a(<<"species">>), sx([a(<<"+">>), a(<<"weight">>), sx([a(<<"car">>), a(<<"args">>)])]), a(<<"children">>)])
                            ])
                        ])
                    ])
                ])
            ])
        ),
        sample(
            lfe_15_fish_process,
            <<"fish-class/3 process loop">>,
            <<"examples/object-via-process.lfe:88 fish-class/3">>,
            [defun, receive_form, recursion, backquote],
            defun(<<"fish-class">>, [
                cl(lst([a(<<"species">>), a(<<"weight">>), a(<<"children">>)]), [
                    blk(hs([a(<<"receive">>)]), [
                        cl(tup([q(a(<<"weight">>)), a(<<"from">>)]), [
                            sx([a(<<"!">>), a(<<"from">>), a(<<"weight">>)]),
                            sx([a(<<"fish-class">>), a(<<"species">>), a(<<"weight">>), a(<<"children">>)])
                        ]),
                        cl(tup([q(a(<<"feed">>)), a(<<"amount">>)]), [
                            sx([a(<<"fish-class">>), a(<<"species">>), sx([a(<<"+">>), a(<<"weight">>), a(<<"amount">>)]), a(<<"children">>)])
                        ])
                    ])
                ])
            ])
        ),
        sample(
            lfe_16_account,
            <<"account-class/3 cond receive">>,
            <<"examples/internal-state.lfe:112 account-class/3">>,
            [defun, receive_form, cond_form, recursion],
            defun(<<"account-class">>, [
                cl(lst([a(<<"balance">>), a(<<"history">>), a(<<"owner">>)]), [
                    blk(hs([a(<<"receive">>)]), [
                        cl(tup([q(a(<<"deposit">>)), a(<<"amount">>), a(<<"from">>)]), [
                            blk(hs([a(<<"cond">>)]), [
                                cl(lst([sx([a(<<">">>), a(<<"amount">>), a(<<"0">>)])]), [
                                    sx([a(<<"account-class">>), sx([a(<<"+">>), a(<<"balance">>), a(<<"amount">>)]), sx([a(<<"cons">>), a(<<"amount">>), a(<<"history">>)]), a(<<"owner">>)])
                                ]),
                                cl(lst([q(a(<<"true">>))]), [
                                    sx([a(<<"!">>), a(<<"from">>), q(a(<<"invalid">>))]),
                                    sx([a(<<"account-class">>), a(<<"balance">>), a(<<"history">>), a(<<"owner">>)])
                                ])
                            ])
                        ])
                    ])
                ])
            ])
        ),
        sample(
            lfe_17_eval_expr,
            <<"eval-expr/2 central case">>,
            <<"examples/lfe-eval.lfe:109 eval-expr/2">>,
            [defun, case_form, alternatives, large],
            defun(<<"eval-expr">>, [
                cl(lst([a(<<"e">>), a(<<"env">>)]), [
                    caseof(a(<<"e">>), [
                        cl(tup([q(a(<<"quote">>)), a(<<"x">>)]), [a(<<"x">>)]),
                        cl(tup([q(a(<<"cons">>)), a(<<"h">>), a(<<"t">>)]), [
                            sx([a(<<"cons">>), sx([a(<<"eval-expr">>), a(<<"h">>), a(<<"env">>)]), sx([a(<<"eval-expr">>), a(<<"t">>), a(<<"env">>)])])
                        ]),
                        cl(tup([q(a(<<"if">>)), a(<<"test">>), a(<<"then">>), a(<<"else">>)]), [
                            sx([a(<<"eval-if">>), a(<<"test">>), a(<<"then">>), a(<<"else">>), a(<<"env">>)])
                        ]),
                        cl(tup([q(a(<<"lambda">>)), a(<<"args">>), a(<<"body">>)]), [
                            sx([a(<<"make-lambda">>), a(<<"args">>), a(<<"body">>), a(<<"env">>)])
                        ]),
                        cl(a(<<"x">>), [sx([a(<<"eval-application">>), a(<<"x">>), a(<<"env">>)])])
                    ])
                ])
            ])
        ),
        sample(
            lfe_18_parse_bitspecs,
            <<"parse-bitspecs/3 let/case nesting">>,
            <<"examples/lfe-eval.lfe:227 parse-bitspecs/3">>,
            [defun, let_form, case_form, bit_syntax],
            defun(<<"parse-bitspecs">>, [
                cl(lst([a(<<"specs">>), a(<<"val">>), a(<<"env">>)]), [
                    blk(
                        hs([
                            a(<<"let">>),
                            lst([
                                lst([tup([a(<<"size">>), a(<<"type">>)]), sx([a(<<"parse-type">>), a(<<"specs">>), a(<<"env">>)])])
                            ])
                        ]),
                        [
                            caseof(a(<<"type">>), [
                                cl(q(a(<<"integer">>)), [
                                    sx([a(<<"binary">>), lst([a(<<"val">>), sx([a(<<"size">>), a(<<"size">>)]), sx([a(<<"unit">>), a(<<"1">>)])])])
                                ]),
                                cl(q(a(<<"binary">>)), [
                                    sx([a(<<"binary">>), lst([a(<<"val">>), sx([a(<<"size">>), a(<<"size">>)]), q(a(<<"binary">>))])])
                                ])
                            ])
                        ]
                    )
                ])
            ])
        ),
        sample(
            lfe_19_eval_lambda,
            <<"eval-lambda/2 arity dispatch">>,
            <<"examples/lfe-eval.lfe:337 eval-lambda/2">>,
            [defun, pattern_match, alternatives, recursion],
            defun(<<"eval-lambda">>, [
                cl(lst([lst([]), a(<<"_env">>)]), [q(lst([]))]),
                cl(lst([lst([a(<<"a1">>)]), a(<<"env">>)]), [
                    sx([a(<<"list">>), sx([a(<<"eval-expr">>), a(<<"a1">>), a(<<"env">>)])])
                ]),
                cl(lst([lst([a(<<"a1">>), a(<<"a2">>)]), a(<<"env">>)]), [
                    sx([a(<<"list">>), sx([a(<<"eval-expr">>), a(<<"a1">>), a(<<"env">>)]), sx([a(<<"eval-expr">>), a(<<"a2">>), a(<<"env">>)])])
                ]),
                cl(lst([sx([a(<<"cons">>), a(<<"a">>), a(<<"as">>)]), a(<<"env">>)]), [
                    sx([a(<<"cons">>), sx([a(<<"eval-expr">>), a(<<"a">>), a(<<"env">>)]), sx([a(<<"eval-lambda">>), a(<<"as">>), a(<<"env">>)])])
                ])
            ])
        ),
        sample(
            lfe_20_eval_receive,
            <<"eval-receive/2 fletrec + after">>,
            <<"examples/lfe-eval.lfe:569 eval-receive/2 + helpers">>,
            [defun, fletrec, receive_form, after_form, nested],
            defun(<<"eval-receive">>, [
                cl(lst([a(<<"clauses">>), a(<<"env">>)]), [
                    blk(
                        hs([
                            a(<<"fletrec">>),
                            lst([
                                cl(hs([a(<<"loop">>), lst([a(<<"q">>)])]), [
                                    blk(hs([a(<<"receive">>)]), [
                                        cl(a(<<"msg">>), [
                                            sx([a(<<"when">>), sx([a(<<"match-clauses">>), a(<<"msg">>), a(<<"clauses">>)])]),
                                            sx([a(<<"apply-clause">>), a(<<"msg">>), a(<<"clauses">>), a(<<"env">>)])
                                        ]),
                                        blk(hs([a(<<"after">>), a(<<"timeout">>)]), [
                                            sx([a(<<"loop">>), sx([a(<<"merge-queue">>), a(<<"q">>)])])
                                        ])
                                    ])
                                ])
                            ])
                        ]),
                        [sx([a(<<"loop">>), lst([])])]
                    )
                ])
            ])
        )
    ].

sample(Id, Label, Source, Tags, Spec) ->
    #sample{id = Id, label = Label, source = Source, tags = Tags, spec = Spec}.
