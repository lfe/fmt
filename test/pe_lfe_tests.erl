%%% @doc EUnit tests for the {@link pe_lfe} knowledge layer: lowering, the
%%% no-atom-minting guarantee, facade delegation, and golden/structural layout.
-module(pe_lfe_tests).

-include_lib("eunit/include/eunit.hrl").

%% Render a form to a binary at a given width.
fmt(Form, Width) ->
    {Bin, _M, _S} = pe_lfe:format_binary(Form, #{width => Width}),
    Bin.

sym(B) -> {sym, B}.
lst(Fs) -> {list, Fs}.
call(Fs) -> {call, Fs}.

%%%-------------------------------------------------------------------
%%% A1S3-4: generic fallback for the data/call forms
%%%-------------------------------------------------------------------

leaves_test() ->
    ?assertEqual(<<"foo">>, fmt({sym, <<"foo">>}, 80)),
    ?assertEqual(<<"\"hi\"">>, fmt({str, <<"hi">>}, 80)),
    ?assertEqual(<<"42">>, fmt({int, 42}, 80)),
    ?assertEqual(<<"-7">>, fmt({int, -7}, 80)).

generic_call_test() ->
    ?assertEqual(<<"(foo a b)">>, fmt({call, [sym(<<"foo">>), sym(<<"a">>), sym(<<"b">>)]}, 80)),
    ?assertEqual(<<"(foo)">>, fmt({call, [sym(<<"foo">>)]}, 80)).

list_tuple_test() ->
    ?assertEqual(<<"(1 2)">>, fmt({list, [{int, 1}, {int, 2}]}, 80)),
    ?assertEqual(<<"()">>, fmt({list, []}, 80)),
    ?assertEqual(<<"#(a b)">>, fmt({tuple, [sym(<<"a">>), sym(<<"b">>)]}, 80)).

dotted_list_test() ->
    ?assertEqual(<<"(a . b)">>, fmt({dotted_list, [sym(<<"a">>)], sym(<<"b">>)}, 80)),
    ?assertEqual(
        <<"(a b . c)">>,
        fmt({dotted_list, [sym(<<"a">>), sym(<<"b">>)], sym(<<"c">>)}, 80)
    ).

%%%-------------------------------------------------------------------
%%% A1S3-5: quote/backquote/unquote as prefixes (no unwanted spaces)
%%%-------------------------------------------------------------------

prefix_forms_test() ->
    ?assertEqual(<<"'foo">>, fmt({quote, sym(<<"foo">>)}, 80)),
    ?assertEqual(<<"`foo">>, fmt({bquote, sym(<<"foo">>)}, 80)),
    ?assertEqual(<<",foo">>, fmt({unquote, sym(<<"foo">>)}, 80)),
    ?assertEqual(<<"'(a b)">>, fmt({quote, {list, [sym(<<"a">>), sym(<<"b">>)]}}, 80)),
    ?assertEqual(
        <<"`#(a ,b)">>, fmt({bquote, {tuple, [sym(<<"a">>), {unquote, sym(<<"b">>)}]}}, 80)
    ).

%%%-------------------------------------------------------------------
%%% A1S3-2: symbols are binaries; no atoms are minted from input
%%%-------------------------------------------------------------------

no_atom_minting_test() ->
    %% A symbol name that must not exist as an atom anywhere.
    Name = <<"pe_lfe_never_minted_symbol_9c3f">>,
    %% it does not exist before...
    ?assertError(badarg, binary_to_existing_atom(Name, utf8)),
    %% ...lowering+rendering uses it as text...
    Out = fmt({call, [sym(Name), sym(<<"x">>)]}, 80),
    ?assertEqual(<<"(", Name/binary, " x)">>, Out),
    %% ...and it still does not exist as an atom afterwards.
    ?assertError(badarg, binary_to_existing_atom(Name, utf8)).

%% No source-symbol-to-atom conversion appears in the knowledge-layer source.
no_dynamic_atom_calls_in_source_test() ->
    {ok, Src} = file:read_file("src/pe_lfe.erl"),
    ?assertEqual(nomatch, binary:match(Src, <<"list_to_atom">>)),
    ?assertEqual(nomatch, binary:match(Src, <<"binary_to_atom">>)),
    ?assertEqual(nomatch, binary:match(Src, <<"list_to_existing_atom">>)).

%%%-------------------------------------------------------------------
%%% A1S3-13: facade delegation and option overrides
%%%-------------------------------------------------------------------

facade_delegates_test() ->
    Form = {call, [sym(<<"foo">>), sym(<<"a">>)]},
    {Iolist, M, S} = pe_lfe:format(Form, #{}),
    ?assert(is_list(Iolist)),
    ?assertEqual(<<"(foo a)">>, iolist_to_binary(Iolist)),
    {Bin, M, S} = pe_lfe:format_binary(Form, #{}),
    ?assertEqual(<<"(foo a)">>, Bin),
    ?assertMatch(#{memo_size := _, calls := _, tainted := _}, S),
    ?assertMatch({_Badness, _Height}, pe_measure:cost(M)).

facade_width_override_test() ->
    %% a vertical-friendly form that breaks at a narrow width.
    Form = {call, [sym(<<"progn">>), sym(<<"aaaa">>), sym(<<"bbbb">>), sym(<<"cccc">>)]},
    ?assertEqual(<<"(progn aaaa bbbb cccc)">>, fmt(Form, 80)),
    ?assertEqual(<<"(progn\n  aaaa\n  bbbb\n  cccc)">>, fmt(Form, 8)).

to_doc_returns_dag_test() ->
    Dag = pe_lfe:to_doc({call, [sym(<<"a">>), sym(<<"b">>)]}),
    ?assert(pe_doc:size(Dag) > 0).

%%%-------------------------------------------------------------------
%%% A1S3-6/18: defun golden — Ackermann at width 80
%%%-------------------------------------------------------------------

ackermann_golden_test() ->
    Expected =
        <<
            "(defun ackermann\n"
            "  ((0 n) (+ n 1))\n"
            "  ((m 0) (ackermann (- m 1) 1))\n"
            "  ((m n) (ackermann (- m 1) (ackermann m (- n 1)))))"
        >>,
    ?assertEqual(Expected, render_sample(lfe_01_ackermann, 80)).

%%%-------------------------------------------------------------------
%%% A1S3-11/12: eval-when-compile is a block; nested defun at block indent
%%%-------------------------------------------------------------------

eval_when_compile_block_test() ->
    Bin = render_sample(lfe_07_bq_expand, 80),
    Lines = lines(Bin),
    ?assertEqual(<<"(eval-when-compile">>, hd(Lines)),
    %% the inner defun starts at block indentation (2 spaces), not aligned as a
    %% generic second argument.
    ?assert(lists:member(<<"  (defun bq-expand">>, Lines)),
    %% and nothing drifts pathologically far right.
    ?assert(max_indent(Bin) =< 16).

%%%-------------------------------------------------------------------
%%% A1S3-10/19: case, receive, cond, let produce vertical bodies
%%%-------------------------------------------------------------------

case_vertical_test() ->
    Bin = render_sample(lfe_17_eval_expr, 80),
    Lines = lines(Bin),
    ?assertEqual(<<"(defun eval-expr (e env)">>, hd(Lines)),
    ?assert(lists:member(<<"  (case e">>, Lines)),
    %% each case clause is on its own line, nested under the case.
    ?assert(lists:member(<<"    (#('quote x) x)">>, Lines)).

receive_vertical_test() ->
    Bin = render_sample(lfe_11_guess_server, 80),
    Lines = lines(Bin),
    ?assert(lists:member(<<"  (receive">>, Lines)),
    ?assert(lists:member(<<"    ('stop 'ok)))">>, Lines)).

cond_vertical_test() ->
    Bin = render_sample(lfe_16_account, 80),
    ?assert(contains(Bin, <<"(cond\n">>)),
    ?assert(contains(Bin, <<"((> amount 0)\n">>)).

let_vertical_test() ->
    Bin = render_sample(lfe_18_parse_bitspecs, 80),
    Lines = lines(Bin),
    ?assertEqual(<<"(defun parse-bitspecs (specs val env)">>, hd(Lines)),
    %% the let binding stays compact on the head line; case nests below it.
    ?assert(lists:member(<<"  (let ((#(size type) (parse-type specs env)))">>, Lines)),
    ?assert(lists:member(<<"    (case type">>, Lines)).

%% receive with an after branch keeps the timeout on the head line.
receive_after_test() ->
    Bin = render_sample(lfe_20_eval_receive, 80),
    ?assert(contains(Bin, <<"(after timeout ">>)).

%%%-------------------------------------------------------------------
%%% A1S5: block-valued call arguments and flet/fletrec bindings
%%%-------------------------------------------------------------------

block_valued_call_arguments_test_() ->
    [
        ?_assert(block_arg_has_local_indent(<<"lambda">>)),
        ?_assert(block_arg_has_local_indent(<<"match-lambda">>)),
        ?_assert(block_arg_has_local_indent(<<"case">>)),
        ?_assert(block_arg_has_local_indent(<<"receive">>)),
        ?_assert(block_arg_has_local_indent(<<"cond">>))
    ].

lfe_08_match_lambda_argument_test() ->
    Bin = render_sample(lfe_08_ets_new, 80),
    Lines = lines(Bin),
    ?assert(lists:member(<<"    (lists:foreach">>, Lines)),
    ?assert(lists:member(<<"      (match-lambda">>, Lines)),
    ?assert(max_indent(Bin) =< 10).

top_level_block_forms_stay_readable_test() ->
    ?assertEqual(<<"(lambda (x)\n  (work x))">>, fmt(lambda_arg(), 18)),
    ?assert(contains(fmt(match_lambda_arg(), 24), <<"(match-lambda\n  ((x) (handle x))">>)),
    ?assert(contains(fmt(case_arg(), 24), <<"(case event\n  ('ok (handle-ok))">>)),
    ?assert(contains(fmt(receive_arg(), 24), <<"(receive\n  (msg (handle msg))">>)),
    ?assert(contains(fmt(cond_arg(), 24), <<"(cond\n  ((> x 0) x)">>)).

flet_function_binding_layout_test() ->
    Bin = fmt(
        call([
            sym(<<"flet">>),
            lst([
                lst([
                    sym(<<"twice">>),
                    lst([sym(<<"x">>)]),
                    call([sym(<<"+">>), sym(<<"x">>), sym(<<"x">>)])
                ])
            ]),
            call([sym(<<"twice">>), {int, 21}])
        ]),
        32
    ),
    ?assert(contains(Bin, <<"((twice (x) (+ x x)))">>)).

fletrec_function_binding_body_layout_test() ->
    Bin = fmt(
        call([
            sym(<<"fletrec">>),
            lst([lst([sym(<<"loop">>), lst([sym(<<"q">>)]), receive_arg()])]),
            call([sym(<<"loop">>), lst([])])
        ]),
        48
    ),
    Lines = lines(Bin),
    ?assert(lists:member(<<"  ((loop (q)">>, Lines)),
    ?assert(lists:member(<<"     (receive">>, Lines)).

flet_non_function_binding_fallback_test() ->
    Bin = fmt(
        call([
            sym(<<"flet">>),
            lst([lst([sym(<<"x">>), {int, 1}])]),
            sym(<<"x">>)
        ]),
        80
    ),
    ?assertEqual(<<"(flet ((x 1)) x)">>, Bin).

lfe_20_fletrec_binding_test() ->
    Bin = render_sample(lfe_20_eval_receive, 80),
    Lines = lines(Bin),
    ?assert(lists:member(<<"    ((loop (q)">>, Lines)),
    ?assert(lists:member(<<"       (receive">>, Lines)),
    ?assertNot(contains(Bin, <<"\n      (q)\n">>)).

%%%-------------------------------------------------------------------
%%% Helpers
%%%-------------------------------------------------------------------

render_sample(Id, Width) ->
    Form = pe_lfe_samples:form(pe_lfe_samples:by_id(Id)),
    fmt(Form, Width).

lines(Bin) ->
    binary:split(Bin, <<"\n">>, [global]).

contains(Bin, Needle) ->
    binary:match(Bin, Needle) =/= nomatch.

block_arg_has_local_indent(Kw) ->
    Bin = fmt(call([sym(<<"outer">>), block_arg(Kw), sym(<<"tail">>)]), 24),
    Lines = lines(Bin),
    lists:member(<<"(outer">>, Lines) andalso
        lists:member(<<"  (", Kw/binary>>, [line_head(L, byte_size(Kw) + 3) || L <- Lines]) andalso
        max_indent(Bin) =< 6.

line_head(Line, N) when byte_size(Line) >= N ->
    binary:part(Line, 0, N);
line_head(Line, _N) ->
    Line.

block_arg(<<"lambda">>) -> lambda_arg();
block_arg(<<"match-lambda">>) -> match_lambda_arg();
block_arg(<<"case">>) -> case_arg();
block_arg(<<"receive">>) -> receive_arg();
block_arg(<<"cond">>) -> cond_arg().

lambda_arg() ->
    call([sym(<<"lambda">>), lst([sym(<<"x">>)]), call([sym(<<"work">>), sym(<<"x">>)])]).

match_lambda_arg() ->
    call([
        sym(<<"match-lambda">>), lst([lst([sym(<<"x">>)]), call([sym(<<"handle">>), sym(<<"x">>)])])
    ]).

case_arg() ->
    call([
        sym(<<"case">>),
        sym(<<"event">>),
        lst([{quote, sym(<<"ok">>)}, call([sym(<<"handle-ok">>)])]),
        lst([sym(<<"x">>), call([sym(<<"handle-error">>), sym(<<"x">>)])])
    ]).

receive_arg() ->
    call([
        sym(<<"receive">>),
        lst([sym(<<"msg">>), call([sym(<<"handle">>), sym(<<"msg">>)])]),
        lst([sym(<<"after">>), {int, 10}, sym(<<"timeout">>)])
    ]).

cond_arg() ->
    call([
        sym(<<"cond">>),
        lst([call([sym(<<">">>), sym(<<"x">>), {int, 0}]), sym(<<"x">>)]),
        lst([{quote, sym(<<"true">>)}, {int, 0}])
    ]).

max_indent(Bin) ->
    lists:max([indent(L) || L <- lines(Bin)]).

indent(Line) ->
    indent(Line, 0).

indent(<<$\s, Rest/binary>>, N) -> indent(Rest, N + 1);
indent(_, N) -> N.
