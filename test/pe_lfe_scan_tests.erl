%%% @doc EUnit for the positioned, comment-preserving scanner `pe_lfe_scan':
%%% positions (A2S2-3), comment trivia + `#;' (A2S2-4), string/char awareness
%%% (A2S2-13), and the token differential vs `lfe_scan' over the corpus (A2S2-5).
-module(pe_lfe_scan_tests).

-include_lib("eunit/include/eunit.hrl").

scan(S) -> pe_lfe_scan:scan(list_to_binary(S)).

%% non-trivia tokens only
values(S) -> [T || T <- scan(S), element(1, T) =/= comment].

%%%-------------------------------------------------------------------
%%% A2S2-3: every token carries {line, col}
%%%-------------------------------------------------------------------

positions_test() ->
    %% "(a\n  bb)" — ( at 1:1, a at 1:2, bb at 2:3, ) at 2:5
    ?assertEqual(
        [
            {'(', none, {1, 1}},
            {symbol, a, {1, 2}},
            {symbol, bb, {2, 3}},
            {')', none, {2, 5}}
        ],
        scan("(a\n  bb)")
    ).

%%%-------------------------------------------------------------------
%%% A2S2-4: comments emitted as trivia; #; datum token
%%%-------------------------------------------------------------------

line_comment_test() ->
    ?assertEqual(
        [
            {symbol, a, {1, 1}},
            {comment, {line, <<" a comment">>}, {1, 3}}
        ],
        scan("a ; a comment")
    ).

block_comment_test() ->
    ?assertEqual(
        [
            {comment, {block, <<" hi ">>}, {1, 1}},
            {symbol, x, {1, 9}}
        ],
        scan("#| hi |#x")
    ).

block_comment_multiline_test() ->
    [{comment, {block, Text}, {1, 1}}, {symbol, y, {3, 3}}] = scan("#|a\nb\n|#y"),
    ?assertEqual(<<"a\nb\n">>, Text).

datum_comment_is_token_test() ->
    %% #; is a token the parser consumes (comments out the next datum).
    ?assertEqual([{'#;', none, {1, 1}}, {symbol, x, {1, 4}}], scan("#; x")).

%%%-------------------------------------------------------------------
%%% A2S2-13: a ; or #| inside a string/char is NOT a comment
%%%-------------------------------------------------------------------

semicolon_in_string_test() ->
    ?assertEqual([{string, "a;b", {1, 1}}], values("\"a;b\"")).

hashpipe_in_string_test() ->
    ?assertEqual([{string, "x#|y", {1, 1}}], values("\"x#|y\"")).

semicolon_char_is_not_comment_test() ->
    %% #\; is the semicolon character (codepoint 59), tagged number like lfe_scan.
    ?assertEqual([{number, $;, {1, 1}}, {symbol, ok, {1, 5}}], scan("#\\; ok")).

%%%-------------------------------------------------------------------
%%% Token kinds (sanity, matching lfe_scan value shapes)
%%%-------------------------------------------------------------------

token_kinds_test() ->
    ?assertEqual([{number, 1.5, {1, 1}}], values("1.5")),
    ?assertEqual([{number, 31, {1, 1}}], values("#x1f")),
    ?assertEqual([{number, 5, {1, 1}}], values("#b101")),
    ?assertEqual([{binary, <<"hi">>, {1, 1}}], values("#\"hi\"")),
    ?assertEqual([{'#\'', "nm/2", {1, 1}}], values("#'nm/2")),
    ?assertEqual([{'#(', none, {1, 1}}, {number, 1, {1, 3}}, {')', none, {1, 4}}], values("#(1)")),
    ?assertEqual([{'\'', none, {1, 1}}, {symbol, a, {1, 2}}], values("'a")),
    ?assertEqual([{',@', none, {1, 1}}, {symbol, x, {1, 3}}], values(",@x")).

triple_quote_test() ->
    %% leading line blank; closing-line indentation is stripped from content.
    ?assertEqual([{string, "abc\ndef", {1, 1}}], values("\"\"\"\n  abc\n  def\n  \"\"\"")).

%%%-------------------------------------------------------------------
%%% A2S2-5: token differential vs lfe_scan over the corpus
%%%-------------------------------------------------------------------

corpus_token_differential_test_() ->
    {timeout, 120, fun() ->
        Bad = [F || F <- corpus_files(), not tokens_match(F)],
        ?assertEqual([], [filename:basename(F) || F <- Bad])
    end}.

tokens_match(File) ->
    {ok, Bin} = file:read_file(File),
    Mine = [mine_core(T) || T <- pe_lfe_scan:scan(Bin), element(1, T) =/= comment],
    {ok, Lfe0, _} = lfe_scan:string(unicode:characters_to_list(Bin)),
    Mine =:= [lfe_core(T) || T <- Lfe0].

mine_core({Type, Val, _Pos}) when
    Type =:= symbol; Type =:= number; Type =:= string; Type =:= binary; Type =:= '#\''
->
    {Type, Val};
mine_core({Atom, none, _Pos}) ->
    Atom.

lfe_core({Type, _L, Val}) -> {Type, Val};
lfe_core({Atom, _L}) -> Atom.

corpus_files() ->
    Dir = code:lib_dir(lfe),
    Examples = filelib:wildcard(filename:join([Dir, "examples", "*.lfe"])),
    Tests = filelib:wildcard(filename:join([Dir, "test", "*.lfe"])),
    Core = [filename:join([Dir, "src", F]) || F <- ["cl.lfe", "clj.lfe"]],
    [P || P <- Examples ++ Tests ++ Core, filelib:is_regular(P)].
