%%% @doc EUnit for the positioned, comment-bearing reader `pe_lfe_cst':
%%% cst_to_sexpr leaves/aggregates (A2S2-6/8), Roslyn trivia classification
%%% (A2S2-7/11), positions (A2S2-12), the AST differential vs `lfe_io' (the 739
%%% gate, A2S2-9), and the comment-capture gate (A2S2-10).
-module(pe_lfe_cst_tests).

-include_lib("eunit/include/eunit.hrl").

%% Read the single top-level form of a snippet.
read1(S) ->
    [C] = pe_lfe_cst:read(list_to_binary(S)),
    C.

sexpr(S) -> pe_lfe_cst:cst_to_sexpr(read1(S)).

%%%-------------------------------------------------------------------
%%% A2S2-6/8: cst_to_sexpr matches lfe_io's read AST per construct
%%%-------------------------------------------------------------------

leaves_test() ->
    ?assertEqual(foo, sexpr("foo")),
    ?assertEqual(42, sexpr("42")),
    ?assertEqual(1.5, sexpr("1.5")),
    ?assertEqual("abc", sexpr("\"abc\"")),
    ?assertEqual(<<"bin">>, sexpr("#\"bin\"")),
    ?assertEqual($a, sexpr("#\\a")).

aggregates_test() ->
    ?assertEqual([foo, a, 1], sexpr("(foo a 1)")),
    ?assertEqual({1, 2}, sexpr("#(1 2)")),
    ?assertEqual(#{a => 1, b => 2}, sexpr("#M(a 1 b 2)")),
    ?assertEqual([a, b | c], sexpr("(a b . c)")),
    ?assertEqual([quote, x], sexpr("'x")),
    ?assertEqual([backquote, [a, [comma, b], ['comma-at', c]]], sexpr("`(a ,b ,@c)")).

reader_constructors_test() ->
    %% #B(...) evaluated like (binary ...); #' fun refs; module-qualified.
    ?assertEqual(<<1, 2, 3>>, sexpr("#b(1 2 3)")),
    ?assertEqual(<<"AB">>, sexpr("#b(\"AB\")")),
    ?assertEqual(<<5.0:64/float>>, sexpr("#b((5.0 float))")),
    ?assertEqual([function, sin, 1], sexpr("#'sin/1")),
    ?assertEqual([function, math, sin, 1], sexpr("#'math:sin/1")),
    ?assertEqual([function, '=:=', 2], sexpr("#'=:=/2")).

%%%-------------------------------------------------------------------
%%% A2S2-7/11: Roslyn trivia — leading vs trailing classification
%%%-------------------------------------------------------------------

leading_and_trailing_test() ->
    %% "; lead\n(foo) ; trail" — the form leads with the first comment and
    %% trails with the same-line one.
    C = read1("; lead\n(foo) ; trail"),
    ?assertEqual([{line, <<" lead">>, {1, 1}}], pe_lfe_cst:lead(C)),
    ?assertEqual([{line, <<" trail">>, {2, 7}}], pe_lfe_cst:trail(C)).

inner_comment_leads_next_element_test() ->
    %% a comment on its own line before an element leads that element.
    C = read1("(a\n  ; mid\n  b)"),
    [_A, B] = children(C),
    ?assertEqual([{line, <<" mid">>, {2, 3}}], pe_lfe_cst:lead(B)).

comment_trailing_open_paren_leads_first_test() ->
    %% "(flet (; c\n  (x))" — the comment trailing `(' leads the first element.
    C = read1("(flet (; c\n  (x)))"),
    [_Flet, Binds] = children(C),
    [First | _] = children(Binds),
    ?assertEqual([{line, <<" c">>, {1, 8}}], pe_lfe_cst:lead(First)).

children(C) -> pe_lfe_cst:children(C).

%%%-------------------------------------------------------------------
%%% A2S2-12: a position on every node
%%%-------------------------------------------------------------------

every_node_has_position_test() ->
    Cs = pe_lfe_cst:read(<<"(defun f (x)\n  (+ x #(1 2) \"s\"))">>),
    Ps = pe_lfe_cst:positions(Cs),
    ?assert(length(Ps) > 5),
    ?assert(lists:all(fun valid_pos/1, Ps)).

valid_pos({L, C}) -> is_integer(L) andalso is_integer(C) andalso L >= 1 andalso C >= 1;
valid_pos(eof) -> true.

%%%-------------------------------------------------------------------
%%% A2S2-9: AST differential vs lfe_io over the corpus (739)
%%%-------------------------------------------------------------------

corpus_ast_differential_test_() ->
    {timeout, 300, fun() ->
        {Forms, Bad} = lists:foldl(
            fun(File, {N, B}) ->
                {ok, Bin} = file:read_file(File),
                Mine = [pe_lfe_cst:cst_to_sexpr(C) || C <- pe_lfe_cst:read(Bin)],
                {ok, LL} = lfe_io:parse_file(File),
                Lfe = [S || {S, _L} <- LL],
                {
                    N + length(Lfe),
                    case Mine =:= Lfe of
                        true -> B;
                        false -> [filename:basename(File) | B]
                    end
                }
            end,
            {0, []},
            corpus_files()
        ),
        ?assertEqual([], Bad),
        ?assert(Forms >= 739)
    end}.

%%%-------------------------------------------------------------------
%%% A2S2-10: comment capture — 0 lost vs the scanner's comment count
%%%-------------------------------------------------------------------

corpus_comment_capture_test_() ->
    {timeout, 300, fun() ->
        {Scanned, Captured, Bad} = lists:foldl(
            fun(File, {S, C, B}) ->
                {ok, Bin} = file:read_file(File),
                NS = length([T || T <- pe_lfe_scan:scan(Bin), element(1, T) =:= comment]),
                NC = length(pe_lfe_cst:comments(pe_lfe_cst:read(Bin))),
                {
                    S + NS,
                    C + NC,
                    case NS =:= NC of
                        true -> B;
                        false -> [{filename:basename(File), NS, NC} | B]
                    end
                }
            end,
            {0, 0, []},
            corpus_files()
        ),
        ?assertEqual([], Bad),
        ?assertEqual(Scanned, Captured),
        ?assert(Captured > 1000),
        %% every captured comment carries a position
        ?assert(
            lists:all(
                fun({_K, _T, P}) -> valid_pos(P) end,
                pe_lfe_cst:comments(pe_lfe_cst:read(element(2, file:read_file(hd(corpus_files())))))
            )
        )
    end}.

corpus_files() ->
    Dir = code:lib_dir(lfe),
    Examples = filelib:wildcard(filename:join([Dir, "examples", "*.lfe"])),
    Tests = filelib:wildcard(filename:join([Dir, "test", "*.lfe"])),
    Core = [filename:join([Dir, "src", F]) || F <- ["cl.lfe", "clj.lfe"]],
    [P || P <- Examples ++ Tests ++ Core, filelib:is_regular(P)].
