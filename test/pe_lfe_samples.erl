%%% @doc Test-only fixture corpus: 20 real-LFE-shaped forms as {@link pe_lfe}
%%% terms, lowered through the LFE knowledge layer.
%%%
%%% Slice3 migrated these from slice2's fixture-specific document specs to
%%% explicit `pe_lfe:form()` terms: `build/1' now calls `pe_lfe:to_doc/1', so
%%% layout is decided entirely by the knowledge layer, not by per-sample
%%% builders. The only local sugar (`sym/1', `call/1', …) constructs `form()'
%%% terms — there is no competing layout layer here.
%%%
%%% Symbols are binaries; nothing is minted into atoms. Source references and
%%% labels are unchanged from slice2 for corpus continuity.
-module(pe_lfe_samples).

-export([all/0, by_id/1, build/1, id/1, label/1, source/1, tags/1, form/1]).

-export_type([sample/0]).

-record(sample, {
    id :: atom(),
    label :: binary(),
    source :: binary(),
    tags :: [atom()],
    form :: pe_lfe:form()
}).

-opaque sample() :: #sample{}.

%%%-------------------------------------------------------------------
%%% Accessors (stable surface; build/1 lowers through pe_lfe)
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
build(#sample{form = Form}) ->
    pe_lfe:to_doc(Form).

-spec form(sample()) -> pe_lfe:form().
form(#sample{form = Form}) -> Form.

-spec id(sample()) -> atom().
id(#sample{id = Id}) -> Id.

-spec label(sample()) -> binary().
label(#sample{label = L}) -> L.

-spec source(sample()) -> binary().
source(#sample{source = S}) -> S.

-spec tags(sample()) -> [atom()].
tags(#sample{tags = T}) -> T.

%%%-------------------------------------------------------------------
%%% Local form() sugar (constructs pe_lfe:form() terms only)
%%%-------------------------------------------------------------------

sym(Bin) -> {sym, Bin}.
str(Bin) -> {str, Bin}.
int(N) -> {int, N}.
q(F) -> {quote, F}.
bq(F) -> {bquote, F}.
uq(F) -> {unquote, F}.
lst(Fs) -> {list, Fs}.
dl(Fs, Tail) -> {dotted_list, Fs, Tail}.
tup(Fs) -> {tuple, Fs}.
call(Fs) -> {call, Fs}.

%%%-------------------------------------------------------------------
%%% The 20 samples (ids/labels/sources/tags stable from slice2)
%%%-------------------------------------------------------------------

samples() ->
    [
        sample(
            lfe_01_ackermann,
            <<"ackermann/2 multi-clause defun">>,
            <<"synthetic (Duncan's prompt) ackermann/2">>,
            [defun, pattern_match, recursion],
            call([
                sym(<<"defun">>),
                sym(<<"ackermann">>),
                lst([lst([int(0), sym(<<"n">>)]), call([sym(<<"+">>), sym(<<"n">>), int(1)])]),
                lst([
                    lst([sym(<<"m">>), int(0)]),
                    call([sym(<<"ackermann">>), call([sym(<<"-">>), sym(<<"m">>), int(1)]), int(1)])
                ]),
                lst([
                    lst([sym(<<"m">>), sym(<<"n">>)]),
                    call([
                        sym(<<"ackermann">>),
                        call([sym(<<"-">>), sym(<<"m">>), int(1)]),
                        call([sym(<<"ackermann">>), sym(<<"m">>), call([sym(<<"-">>), sym(<<"n">>), int(1)])])
                    ])
                ])
            ])
        ),
        sample(
            lfe_02_fizz,
            <<"fizz/3 string clauses">>,
            <<"examples/fizzbuzz.lfe:53 fizz/3">>,
            [defun, pattern_match, strings],
            call([
                sym(<<"defun">>),
                sym(<<"fizz">>),
                lst([lst([int(0), int(0), sym(<<"_">>)]), str(<<"fizzbuzz">>)]),
                lst([lst([int(0), sym(<<"_">>), sym(<<"_">>)]), str(<<"fizz">>)]),
                lst([lst([sym(<<"_">>), int(0), sym(<<"_">>)]), str(<<"buzz">>)]),
                lst([lst([sym(<<"_">>), sym(<<"_">>), sym(<<"n">>)]), sym(<<"n">>)])
            ])
        ),
        sample(
            lfe_03_buzz1,
            <<"buzz1/1 guarded head">>,
            <<"examples/fizzbuzz.lfe:72 buzz1/1">>,
            [defun, guard],
            call([
                sym(<<"defun">>),
                sym(<<"buzz1">>),
                lst([
                    lst([sym(<<"n">>)]),
                    call([sym(<<"when">>), call([sym(<<"==">>), int(0), call([sym(<<"rem">>), sym(<<"n">>), int(5)])])]),
                    str(<<"buzz">>)
                ]),
                lst([lst([sym(<<"_">>)]), str(<<"">>)])
            ])
        ),
        sample(
            lfe_04_tail_buzz,
            <<"tail-buzz/2 tail recursion">>,
            <<"examples/fizzbuzz.lfe:116 tail-buzz/2">>,
            [defun, guard, recursion],
            call([
                sym(<<"defun">>),
                sym(<<"tail-buzz">>),
                lst([
                    lst([sym(<<"n">>), sym(<<"acc">>)]),
                    call([sym(<<"when">>), call([sym(<<"=<">>), sym(<<"n">>), int(0)])]),
                    call([sym(<<"lists:reverse">>), sym(<<"acc">>)])
                ]),
                lst([
                    lst([sym(<<"n">>), sym(<<"acc">>)]),
                    call([
                        sym(<<"tail-buzz">>),
                        call([sym(<<"-">>), sym(<<"n">>), int(1)]),
                        call([sym(<<"cons">>), call([sym(<<"buzz1">>), sym(<<"n">>)]), sym(<<"acc">>)])
                    ])
                ])
            ])
        ),
        sample(
            lfe_05_plusplus,
            <<"++ macro with quasiquote/rest">>,
            <<"examples/core-macros.lfe:55 ++">>,
            [defmacro, quasiquote, rest_args],
            call([
                sym(<<"defmacro">>),
                sym(<<"++">>),
                lst([lst([]), q(lst([]))]),
                lst([lst([sym(<<"l">>)]), sym(<<"l">>)]),
                lst([
                    dl([sym(<<"l">>)], sym(<<"ls">>)),
                    bq(call([sym(<<"lists:append">>), uq(sym(<<"l">>)), dl([sym(<<"++">>)], uq(sym(<<"ls">>)))]))
                ])
            ])
        ),
        sample(
            lfe_06_cond,
            <<"cond macro expanding to if">>,
            <<"examples/core-macros.lfe:100 cond">>,
            [defmacro, quasiquote, alternatives],
            call([
                sym(<<"defmacro">>),
                sym(<<"cond">>),
                lst([lst([sym(<<"c">>)]), sym(<<"c">>)]),
                lst([
                    dl([dl([q(sym(<<"else">>))], sym(<<"body">>))], sym(<<"_">>)),
                    bq(dl([sym(<<"progn">>)], uq(sym(<<"body">>))))
                ]),
                lst([
                    dl([dl([sym(<<"test">>)], sym(<<"body">>))], sym(<<"clauses">>)),
                    bq(call([
                        sym(<<"if">>),
                        uq(sym(<<"test">>)),
                        dl([sym(<<"progn">>)], uq(sym(<<"body">>))),
                        dl([sym(<<"cond">>)], uq(sym(<<"clauses">>)))
                    ]))
                ])
            ])
        ),
        sample(
            lfe_07_bq_expand,
            <<"bq-expand inside eval-when-compile">>,
            <<"examples/core-macros.lfe:125 backquote/bq-expand">>,
            [defmacro, quasiquote, nested, case_form],
            call([
                sym(<<"eval-when-compile">>),
                call([
                    sym(<<"defun">>),
                    sym(<<"bq-expand">>),
                    lst([
                        lst([sym(<<"exp">>), sym(<<"n">>)]),
                        call([
                            sym(<<"case">>),
                            sym(<<"exp">>),
                            lst([
                                call([sym(<<"tuple">>), q(sym(<<"unquote">>)), sym(<<"e">>)]),
                                call([sym(<<"when">>), call([sym(<<">">>), sym(<<"n">>), int(0)])]),
                                call([sym(<<"tuple">>), q(sym(<<"unquote">>)), call([sym(<<"bq-expand">>), sym(<<"e">>), call([sym(<<"-">>), sym(<<"n">>), int(1)])])])
                            ]),
                            lst([call([sym(<<"tuple">>), q(sym(<<"unquote">>)), sym(<<"e">>)]), sym(<<"e">>)]),
                            lst([
                                call([sym(<<"cons">>), q(sym(<<"backquote">>)), sym(<<"x">>)]),
                                call([sym(<<"bq-expand-list">>), sym(<<"exp">>), call([sym(<<"+">>), sym(<<"n">>), int(1)])])
                            ]),
                            lst([sym(<<"x">>), call([sym(<<"bq-expand-list">>), sym(<<"x">>), sym(<<"n">>)])])
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
            call([
                sym(<<"defun">>),
                sym(<<"new">>),
                lst([]),
                call([
                    sym(<<"let">>),
                    lst([
                        lst([
                            sym(<<"tab">>),
                            call([sym(<<"ets:new">>), q(sym(<<"places">>)), call([sym(<<"list">>), q(sym(<<"named_table">>)), q(sym(<<"public">>))])])
                        ])
                    ]),
                    call([
                        sym(<<"lists:foreach">>),
                        call([
                            sym(<<"match-lambda">>),
                            lst([
                                lst([bq(tup([uq(sym(<<"name">>)), uq(sym(<<"desc">>))]))]),
                                call([sym(<<"ets:insert">>), sym(<<"tab">>), call([sym(<<"make-place">>), sym(<<"name">>), sym(<<"name">>), sym(<<"desc">>), sym(<<"desc">>)])])
                            ])
                        ]),
                        call([sym(<<"default-places">>)])
                    ]),
                    sym(<<"tab">>)
                ])
            ])
        ),
        sample(
            lfe_09_by_place_ms,
            <<"by_place_ms/2 match-spec">>,
            <<"examples/ets-demo.lfe:86 by_place_ms/2">>,
            [defun, match_spec, records, guard],
            call([
                sym(<<"defun">>),
                sym(<<"by_place_ms">>),
                lst([sym(<<"place">>), sym(<<"min">>)]),
                bq(lst([
                    tup([
                        call([sym(<<"match-place">>), q(sym(<<"_">>)), uq(sym(<<"place">>)), q(sym(<<"$1">>))]),
                        lst([call([sym(<<">=">>), q(sym(<<"$1">>)), uq(sym(<<"min">>))])]),
                        lst([q(sym(<<"$1">>))])
                    ])
                ]))
            ])
        ),
        sample(
            lfe_10_mnesia_new,
            <<"mnesia-demo new/0 transaction">>,
            <<"examples/mnesia-demo.lfe:50 new/0">>,
            [defun, records, backquote, otp],
            call([
                sym(<<"defun">>),
                sym(<<"new">>),
                lst([]),
                call([
                    sym(<<"mnesia:create_table">>),
                    q(sym(<<"place">>)),
                    bq(lst([
                        tup([sym(<<"attributes">>), uq(call([sym(<<"fields">>), q(sym(<<"place">>))]))]),
                        tup([sym(<<"disc_copies">>), lst([call([sym(<<"node">>)])])]),
                        tup([sym(<<"type">>), q(sym(<<"set">>))])
                    ]))
                ])
            ])
        ),
        sample(
            lfe_11_guess_server,
            <<"guess-server/1 receive loop">>,
            <<"examples/guessing-game2.lfe:61 guess-server/1">>,
            [defun, receive_form, records, recursion],
            call([
                sym(<<"defun">>),
                sym(<<"guess-server">>),
                lst([sym(<<"state">>)]),
                call([
                    sym(<<"receive">>),
                    lst([
                        tup([q(sym(<<"guess">>)), sym(<<"from">>), sym(<<"n">>)]),
                        call([sym(<<"when">>), call([sym(<<"is_integer">>), sym(<<"n">>)])]),
                        call([sym(<<"!">>), sym(<<"from">>), call([sym(<<"check">>), sym(<<"state">>), sym(<<"n">>)])]),
                        call([sym(<<"guess-server">>), sym(<<"state">>)])
                    ]),
                    lst([q(sym(<<"stop">>)), q(sym(<<"ok">>))])
                ])
            ])
        ),
        sample(
            lfe_12_ping_pong,
            <<"ping-pong gen_server callbacks">>,
            <<"examples/ping-pong.lfe:73 handle_call/handle_cast">>,
            [progn, otp, records, pattern_match],
            call([
                sym(<<"progn">>),
                call([
                    sym(<<"defun">>),
                    sym(<<"handle_call">>),
                    lst([
                        lst([q(sym(<<"ping">>)), sym(<<"_from">>), sym(<<"state">>)]),
                        tup([
                            q(sym(<<"reply">>)),
                            q(sym(<<"pong">>)),
                            call([sym(<<"set-state-pings">>), sym(<<"state">>), call([sym(<<"+">>), call([sym(<<"state-pings">>), sym(<<"state">>)]), int(1)])])
                        ])
                    ])
                ]),
                call([
                    sym(<<"defun">>),
                    sym(<<"handle_cast">>),
                    lst([lst([q(sym(<<"pong">>)), sym(<<"state">>)]), tup([q(sym(<<"noreply">>)), sym(<<"state">>)])])
                ])
            ])
        ),
        sample(
            lfe_13_get_page,
            <<"get-page/1 async httpc">>,
            <<"examples/http-async.lfe:124 get-page/1">>,
            [defun, receive_form, otp, let_form],
            call([
                sym(<<"defun">>),
                sym(<<"get-page">>),
                lst([sym(<<"url">>)]),
                call([
                    sym(<<"let">>),
                    lst([
                        lst([
                            tup([q(sym(<<"ok">>)), sym(<<"id">>)]),
                            call([sym(<<"httpc:request">>), q(sym(<<"get">>)), tup([sym(<<"url">>), lst([])]), lst([]), lst([tup([sym(<<"sync">>), q(sym(<<"false">>))])])])
                        ])
                    ]),
                    call([
                        sym(<<"receive">>),
                        lst([tup([q(sym(<<"http">>)), tup([sym(<<"id">>), q(sym(<<"result">>)), sym(<<"body">>)])]), tup([q(sym(<<"ok">>)), sym(<<"body">>)])]),
                        lst([tup([q(sym(<<"http">>)), tup([sym(<<"id">>), q(sym(<<"error">>)), sym(<<"reason">>)])]), tup([q(sym(<<"error">>)), sym(<<"reason">>)])])
                    ])
                ])
            ])
        ),
        sample(
            lfe_14_fish_closure,
            <<"fish-class/3 closure object">>,
            <<"examples/object-via-closure.lfe:92 fish-class/3">>,
            [defun, lambda, case_form],
            call([
                sym(<<"defun">>),
                sym(<<"fish-class">>),
                lst([sym(<<"species">>), sym(<<"weight">>), sym(<<"children">>)]),
                call([
                    sym(<<"lambda">>),
                    lst([sym(<<"method">>), sym(<<"args">>)]),
                    call([
                        sym(<<"case">>),
                        sym(<<"method">>),
                        lst([q(sym(<<"species">>)), sym(<<"species">>)]),
                        lst([q(sym(<<"weight">>)), sym(<<"weight">>)]),
                        lst([
                            q(sym(<<"grow">>)),
                            call([sym(<<"fish-class">>), sym(<<"species">>), call([sym(<<"+">>), sym(<<"weight">>), call([sym(<<"car">>), sym(<<"args">>)])]), sym(<<"children">>)])
                        ])
                    ])
                ])
            ])
        ),
        sample(
            lfe_15_fish_process,
            <<"fish-class/3 process loop">>,
            <<"examples/object-via-process.lfe:88 fish-class/3">>,
            [defun, receive_form, recursion],
            call([
                sym(<<"defun">>),
                sym(<<"fish-class">>),
                lst([sym(<<"species">>), sym(<<"weight">>), sym(<<"children">>)]),
                call([
                    sym(<<"receive">>),
                    lst([
                        tup([q(sym(<<"weight">>)), sym(<<"from">>)]),
                        call([sym(<<"!">>), sym(<<"from">>), sym(<<"weight">>)]),
                        call([sym(<<"fish-class">>), sym(<<"species">>), sym(<<"weight">>), sym(<<"children">>)])
                    ]),
                    lst([
                        tup([q(sym(<<"feed">>)), sym(<<"amount">>)]),
                        call([sym(<<"fish-class">>), sym(<<"species">>), call([sym(<<"+">>), sym(<<"weight">>), sym(<<"amount">>)]), sym(<<"children">>)])
                    ])
                ])
            ])
        ),
        sample(
            lfe_16_account,
            <<"account-class/3 cond receive">>,
            <<"examples/internal-state.lfe:112 account-class/3">>,
            [defun, receive_form, cond_form, recursion],
            call([
                sym(<<"defun">>),
                sym(<<"account-class">>),
                lst([sym(<<"balance">>), sym(<<"history">>), sym(<<"owner">>)]),
                call([
                    sym(<<"receive">>),
                    lst([
                        tup([q(sym(<<"deposit">>)), sym(<<"amount">>), sym(<<"from">>)]),
                        call([
                            sym(<<"cond">>),
                            lst([
                                call([sym(<<">">>), sym(<<"amount">>), int(0)]),
                                call([sym(<<"account-class">>), call([sym(<<"+">>), sym(<<"balance">>), sym(<<"amount">>)]), call([sym(<<"cons">>), sym(<<"amount">>), sym(<<"history">>)]), sym(<<"owner">>)])
                            ]),
                            lst([
                                q(sym(<<"true">>)),
                                call([sym(<<"!">>), sym(<<"from">>), q(sym(<<"invalid">>))]),
                                call([sym(<<"account-class">>), sym(<<"balance">>), sym(<<"history">>), sym(<<"owner">>)])
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
            call([
                sym(<<"defun">>),
                sym(<<"eval-expr">>),
                lst([sym(<<"e">>), sym(<<"env">>)]),
                call([
                    sym(<<"case">>),
                    sym(<<"e">>),
                    lst([tup([q(sym(<<"quote">>)), sym(<<"x">>)]), sym(<<"x">>)]),
                    lst([
                        tup([q(sym(<<"cons">>)), sym(<<"h">>), sym(<<"t">>)]),
                        call([sym(<<"cons">>), call([sym(<<"eval-expr">>), sym(<<"h">>), sym(<<"env">>)]), call([sym(<<"eval-expr">>), sym(<<"t">>), sym(<<"env">>)])])
                    ]),
                    lst([
                        tup([q(sym(<<"if">>)), sym(<<"test">>), sym(<<"then">>), sym(<<"else">>)]),
                        call([sym(<<"eval-if">>), sym(<<"test">>), sym(<<"then">>), sym(<<"else">>), sym(<<"env">>)])
                    ]),
                    lst([
                        tup([q(sym(<<"lambda">>)), sym(<<"args">>), sym(<<"body">>)]),
                        call([sym(<<"make-lambda">>), sym(<<"args">>), sym(<<"body">>), sym(<<"env">>)])
                    ]),
                    lst([sym(<<"x">>), call([sym(<<"eval-application">>), sym(<<"x">>), sym(<<"env">>)])])
                ])
            ])
        ),
        sample(
            lfe_18_parse_bitspecs,
            <<"parse-bitspecs/3 let/case nesting">>,
            <<"examples/lfe-eval.lfe:227 parse-bitspecs/3">>,
            [defun, let_form, case_form, bit_syntax],
            call([
                sym(<<"defun">>),
                sym(<<"parse-bitspecs">>),
                lst([sym(<<"specs">>), sym(<<"val">>), sym(<<"env">>)]),
                call([
                    sym(<<"let">>),
                    lst([lst([tup([sym(<<"size">>), sym(<<"type">>)]), call([sym(<<"parse-type">>), sym(<<"specs">>), sym(<<"env">>)])])]),
                    call([
                        sym(<<"case">>),
                        sym(<<"type">>),
                        lst([
                            q(sym(<<"integer">>)),
                            call([sym(<<"binary">>), lst([sym(<<"val">>), call([sym(<<"size">>), sym(<<"size">>)]), call([sym(<<"unit">>), int(1)])])])
                        ]),
                        lst([
                            q(sym(<<"binary">>)),
                            call([sym(<<"binary">>), lst([sym(<<"val">>), call([sym(<<"size">>), sym(<<"size">>)]), q(sym(<<"binary">>))])])
                        ])
                    ])
                ])
            ])
        ),
        sample(
            lfe_19_eval_lambda,
            <<"eval-lambda/2 arity dispatch">>,
            <<"examples/lfe-eval.lfe:337 eval-lambda/2">>,
            [defun, pattern_match, alternatives, recursion],
            call([
                sym(<<"defun">>),
                sym(<<"eval-lambda">>),
                lst([lst([lst([]), sym(<<"_env">>)]), q(lst([]))]),
                lst([
                    lst([lst([sym(<<"a1">>)]), sym(<<"env">>)]),
                    call([sym(<<"list">>), call([sym(<<"eval-expr">>), sym(<<"a1">>), sym(<<"env">>)])])
                ]),
                lst([
                    lst([lst([sym(<<"a1">>), sym(<<"a2">>)]), sym(<<"env">>)]),
                    call([sym(<<"list">>), call([sym(<<"eval-expr">>), sym(<<"a1">>), sym(<<"env">>)]), call([sym(<<"eval-expr">>), sym(<<"a2">>), sym(<<"env">>)])])
                ]),
                lst([
                    lst([call([sym(<<"cons">>), sym(<<"a">>), sym(<<"as">>)]), sym(<<"env">>)]),
                    call([sym(<<"cons">>), call([sym(<<"eval-expr">>), sym(<<"a">>), sym(<<"env">>)]), call([sym(<<"eval-lambda">>), sym(<<"as">>), sym(<<"env">>)])])
                ])
            ])
        ),
        sample(
            lfe_20_eval_receive,
            <<"eval-receive/2 fletrec + after">>,
            <<"examples/lfe-eval.lfe:569 eval-receive/2 + helpers">>,
            [defun, fletrec, receive_form, after_form, nested],
            call([
                sym(<<"defun">>),
                sym(<<"eval-receive">>),
                lst([sym(<<"clauses">>), sym(<<"env">>)]),
                call([
                    sym(<<"fletrec">>),
                    lst([
                        lst([
                            sym(<<"loop">>),
                            lst([sym(<<"q">>)]),
                            call([
                                sym(<<"receive">>),
                                lst([
                                    sym(<<"msg">>),
                                    call([sym(<<"when">>), call([sym(<<"match-clauses">>), sym(<<"msg">>), sym(<<"clauses">>)])]),
                                    call([sym(<<"apply-clause">>), sym(<<"msg">>), sym(<<"clauses">>), sym(<<"env">>)])
                                ]),
                                lst([sym(<<"after">>), sym(<<"timeout">>), call([sym(<<"loop">>), call([sym(<<"merge-queue">>), sym(<<"q">>)])])])
                            ])
                        ])
                    ]),
                    call([sym(<<"loop">>), lst([])])
                ])
            ])
        )
    ].

sample(Id, Label, Source, Tags, Form) ->
    #sample{id = Id, label = Label, source = Source, tags = Tags, form = Form}.
