%%% @doc EUnit reproductions of mjl's `pretty-expressive' doctests for the
%%% slice8 algebra additions (`fail', `brk'/`hard_nl', `reset', `cost') and the
%%% smart-constructor normalisation. Built through {@link pe_gen:build_sym/2} and
%%% rendered through the {@link pe} facade.
-module(pe_algebra_tests).

-include_lib("eunit/include/eunit.hrl").

t(S) -> {text, list_to_binary(S)}.

cat(A, B) -> {concat, A, B}.

build(Sym) ->
    {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
    pe_doc:freeze(B, Root).

fmt(Sym, W) ->
    {Bin, _M, _S} = pe:format_binary(build(Sym), #{width => W}),
    Bin.

%%%-------------------------------------------------------------------
%%% A1S8-2/3: fail
%%%-------------------------------------------------------------------

%% mjl: `fail().validate(80)` is `Err`.
fail_alone_is_unprintable_test() ->
    ?assertError(no_valid_layout, pe:format_binary(build(fail), #{width => 80})).

%% mjl: `fail() | text("not a fail")` => "not a fail" (choice eliminates fail).
choice_fail_eliminated_test() ->
    {Ch, B} = pe_gen:build_sym({choice, fail, t("not a fail")}, pe_doc:new()),
    {T, _} = pe_doc:text(<<"not a fail">>, B),
    %% the smart constructor returns the rhs directly.
    ?assertEqual(T, Ch),
    ?assertEqual(<<"not a fail">>, fmt({choice, fail, t("not a fail")}, 80)).

%% mjl: `(Fail, _) | (_, Fail) => fail()` for concat.
concat_with_fail_fails_test() ->
    ?assertError(no_valid_layout, pe:format_binary(build(cat(fail, t("x"))), #{width => 80})),
    ?assertError(no_valid_layout, pe:format_binary(build(cat(t("x"), fail)), #{width => 80})).

%%%-------------------------------------------------------------------
%%% A1S8-4: newline variants (more_checks doctest)
%%%-------------------------------------------------------------------

%% mjl: `flatten(text"abc" & nl & text"def") | text"something"` => "abc def".
flatten_nl_is_space_test() ->
    Doc = {choice, {flatten, cat(t("abc"), cat(nl, t("def")))}, t("something")},
    ?assertEqual(<<"abc def">>, fmt(Doc, 80)).

%% mjl: `flatten(text"abc" & brk & text"def")` => "abcdef" (brk flattens to "").
flatten_brk_is_empty_test() ->
    Doc = {choice, {flatten, cat(t("abc"), cat(brk, t("def")))}, t("something")},
    ?assertEqual(<<"abcdef">>, fmt(Doc, 80)).

%% mjl: `flatten(text"abc" & hard_nl & text"def") | text"something"` => "something".
flatten_hard_nl_fails_test() ->
    Doc = {choice, {flatten, cat(t("abc"), cat(hard_nl, t("def")))}, t("something")},
    ?assertEqual(<<"something">>, fmt(Doc, 80)).

%% A broken newline of any variant renders a real `\n` plus indentation.
broken_newline_test() ->
    ?assertEqual(<<"a\nb">>, fmt(cat(t("a"), cat(nl, t("b"))), 1)),
    ?assertEqual(<<"a\nb">>, fmt(cat(t("a"), cat(brk, t("b"))), 1)),
    ?assertEqual(<<"a\nb">>, fmt(cat(t("a"), cat(hard_nl, t("b"))), 1)).

%%%-------------------------------------------------------------------
%%% A1S8-5: reset (more_checks doctest)
%%%-------------------------------------------------------------------

%% mjl: `nest(4, reset(text"abc" & hard_nl & text"def"))` => "abc\ndef".
reset_zeroes_indent_test() ->
    Doc = {nest, 4, {reset, cat(t("abc"), cat(hard_nl, t("def")))}},
    ?assertEqual(<<"abc\ndef">>, fmt(Doc, 80)).

%% mjl: `nest(4, text"abc" & hard_nl & text"def")` => "abc\n    def".
nest_indents_newline_test() ->
    Doc = {nest, 4, cat(t("abc"), cat(hard_nl, t("def")))},
    ?assertEqual(<<"abc\n    def">>, fmt(Doc, 80)).

%%%-------------------------------------------------------------------
%%% A1S8-6: cost (cost doctest)
%%%-------------------------------------------------------------------

%% mjl: `cost(DefaultCost(0,2), text"hello world") | (text"hello" & hard_nl &
%% text"world")` => "hello\nworld" — the cost penalty makes the flat layout lose.
cost_forces_taller_test() ->
    Flat = {cost, {0, 2}, t("hello world")},
    Tall = cat(t("hello"), cat(hard_nl, t("world"))),
    ?assertEqual(<<"hello\nworld">>, fmt({choice, Flat, Tall}, 80)),
    %% without the cost penalty the flat layout wins.
    ?assertEqual(<<"hello world">>, fmt({choice, t("hello world"), Tall}, 80)).

%% mjl: `cost(c, fail) = fail`.
cost_of_fail_is_fail_test() ->
    {Id, B} = pe_gen:build_sym({cost, {0, 5}, fail}, pe_doc:new()),
    ?assertEqual(fail, pe_doc:get(pe_doc:freeze(B, Id), Id)).

%%%-------------------------------------------------------------------
%%% A1S8-1: merge identity (failed mset)
%%%-------------------------------------------------------------------

merge_failed_identity_test() ->
    M = {3, {0, 0}, {text, <<"x">>}},
    Set = pe_mset:singleton(M),
    Tnt = pe_mset:tainted(M),
    ?assertEqual(Set, pe_mset:merge(pe_mset:failed(), Set, pe_cost_squared)),
    ?assertEqual(Set, pe_mset:merge(Set, pe_mset:failed(), pe_cost_squared)),
    ?assertEqual(Tnt, pe_mset:merge(pe_mset:failed(), Tnt, pe_cost_squared)),
    ?assertEqual(failed, pe_mset:merge(pe_mset:failed(), pe_mset:failed(), pe_cost_squared)),
    ?assertError(no_valid_layout, pe_mset:optimal(pe_mset:failed())).
