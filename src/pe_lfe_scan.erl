%%% @doc A positioned, comment-preserving LFE scanner (arc2/slice2).
%%%
%%% Derived from LFE's `lfe_scan.erl' (Apache License 2.0, © Robert Virding) —
%%% see the repo-root `NOTICE'. Three surgical changes vs the original:
%%%
%%%   1. **Binary-based.** It scans the source `binary()' with binary
%%%      pattern-matching and sub-binaries (no `binary_to_list/1' of the whole
%%%      source), the modern BEAM idiom. The original is a continuation-passing
%%%      char-list scanner; because we always have the full source up front, the
%%%      streaming `{more, Continuation}' machinery is dropped — a malformed
%%%      token raises `{scan_error, _}' (let it crash; this is a faithful reader).
%%%   2. **Positions.** Every token carries its `{Line, Col}' start (the original
%%%      computes columns but discards them). Each scan helper is given the
%%%      token's start position and threads the live cursor separately.
%%%   3. **Comments emitted.** `;' line comments and `#|…|#' block comments are
%%%      emitted as `comment' trivia tokens instead of being skipped; `#;' (datum
%%%      comment) is a token the parser consumes.
%%%
%%% Each non-obvious clause cites the `lfe_scan' function it derives from. Token
%%% *values* match `lfe_scan' exactly (proven by the token differential in
%%% `pe_lfe_scan_tests'); only positions and comment trivia are additions.
%%% @end
-module(pe_lfe_scan).

-export([scan/1]).

-export_type([token/0, pos/0]).

-doc "A 1-based `{Line, Column}' source position.".
-type pos() :: {pos_integer(), pos_integer()}.

-doc """
A scanned token `{Type, Value, Pos}'. Value tokens use `Type ∈ {symbol, number,
string, binary, '#\\''}`; punctuation tokens use the punctuation atom as `Type'
with `Value = none'; comment trivia use `Type = comment' with
`Value = {line | block, binary()}' (the raw comment text).
""".
-type token() :: {atom(), term(), pos()}.

%% lfe_scan macros.
-define(IS_WHITE(C), (C >= 0 andalso C =< $\s)).
-define(IS_DIGIT(C), (C >= $0 andalso C =< $9)).

-doc "Scan a source binary into a token list (with comment trivia).".
-spec scan(binary()) -> [token()].
scan(Bin) when is_binary(Bin) ->
    scan(Bin, 1, 1, []).

%%%-------------------------------------------------------------------
%%% Main dispatch — derived from lfe_scan:scan1/4 (clause order preserved).
%%% Each token-starting char is at column Col; that is the token's start, passed
%%% to the sub-scanner which advances the cursor from there.
%%%-------------------------------------------------------------------

-spec scan(binary(), pos_integer(), pos_integer(), [token()]) -> [token()].
scan(<<>>, _L, _C, Acc) ->
    lists:reverse(Acc);
%% Strings (scan1 `[$"|Cs]').
scan(<<$", Rest/binary>>, L, C, Acc) ->
    {Tok, Rest1, L1, C1} = scan_string(Rest, L, C + 1, {L, C}, string),
    scan(Rest1, L1, C1, [Tok | Acc]);
%% Newline / whitespace.
scan(<<$\n, Rest/binary>>, L, _C, Acc) ->
    scan(Rest, L + 1, 1, Acc);
scan(<<C, Rest/binary>>, L, Col, Acc) when ?IS_WHITE(C) ->
    scan(Rest, L, Col + 1, Acc);
%% Comments — emitted as trivia (scan1 `[$;|Cs]').
scan(<<$;, Rest/binary>>, L, Col, Acc) ->
    {Text, Rest1, L1, C1} = scan_line_comment(Rest, L, Col + 1),
    scan(Rest1, L1, C1, [{comment, {line, Text}, {L, Col}} | Acc]);
%% Quoted symbol `|…|' (scan1 `[$||Cs]').
scan(<<$|, Rest/binary>>, L, Col, Acc) ->
    {Tok, Rest1, L1, C1} = scan_qsymbol(Rest, L, Col + 1, {L, Col}, <<>>),
    scan(Rest1, L1, C1, [Tok | Acc]);
%% Hash forms (scan1 `[$#|Cs]') — start is the `#'; cursor begins after it.
scan(<<$#, Rest/binary>>, L, Col, Acc) ->
    {Tok, Rest1, L1, C1} = scan_hash(Rest, L, Col + 1, {L, Col}),
    scan(Rest1, L1, C1, [Tok | Acc]);
%% Single-char separators that are also start-symbol chars (scan1).
scan(<<$', Rest/binary>>, L, Col, Acc) ->
    scan(Rest, L, Col + 1, [{'\'', none, {L, Col}} | Acc]);
scan(<<$`, Rest/binary>>, L, Col, Acc) ->
    scan(Rest, L, Col + 1, [{'`', none, {L, Col}} | Acc]);
scan(<<$., Rest/binary>>, L, Col, Acc) ->
    scan(Rest, L, Col + 1, [{'.', none, {L, Col}} | Acc]);
scan(<<$,, $@, Rest/binary>>, L, Col, Acc) ->
    scan(Rest, L, Col + 2, [{',@', none, {L, Col}} | Acc]);
scan(<<$,, Rest/binary>>, L, Col, Acc) ->
    scan(Rest, L, Col + 1, [{',', none, {L, Col}} | Acc]);
%% Everything else: a start-symbol char begins a symbol/number, otherwise it is
%% a one-character punctuation token (scan1 final clause / `list_to_atom([C])').
scan(<<C, _/binary>> = Bin, L, Col, Acc) ->
    case start_symbol_char(C) of
        true ->
            {Tok, Rest1, L1, C1} = scan_symbol(Bin, L, Col),
            scan(Rest1, L1, C1, [Tok | Acc]);
        false ->
            <<_, Rest/binary>> = Bin,
            scan(Rest, L, Col + 1, [{punct_atom(C), none, {L, Col}} | Acc])
    end.

%% The one-character punctuation atoms (the non-start-symbol chars that reach
%% scan1's final clause): `( ) [ ] { }'.
punct_atom($() -> '(';
punct_atom($)) -> ')';
punct_atom($[) -> '[';
punct_atom($]) -> ']';
punct_atom(${) -> '{';
punct_atom($}) -> '}';
punct_atom(C) -> erlang:list_to_atom([C]).

%%%-------------------------------------------------------------------
%%% Comments — lfe_scan:scan_line_comment/4, scan_block_comment/4
%%%-------------------------------------------------------------------

%% Length-then-slice: scan to end-of-line, take the text as one sub-binary (no
%% per-char copy — the hot path; comments dominate real source).
scan_line_comment(Bin, L, Col) ->
    N = line_comment_len(Bin, 0),
    <<Text:N/binary, Rest0/binary>> = Bin,
    case Rest0 of
        <<$\n, Rest/binary>> -> {Text, Rest, L + 1, 1};
        <<>> -> {Text, <<>>, L, Col + N}
    end.

line_comment_len(<<$\n, _/binary>>, N) -> N;
line_comment_len(<<>>, N) -> N;
line_comment_len(<<_, R/binary>>, N) -> line_comment_len(R, N + 1).

%% Block comment `#|…|#'. The leading `#|' has been consumed; nesting is an error
%% (matching lfe_scan).
scan_block_comment(<<$|, $#, Rest/binary>>, L, Col, Acc) ->
    {Acc, Rest, L, Col + 2};
scan_block_comment(<<$#, $|, _/binary>>, L, Col, _Acc) ->
    error({scan_error, {nested_block_comment, {L, Col}}});
scan_block_comment(<<$\n, Rest/binary>>, L, _Col, Acc) ->
    scan_block_comment(Rest, L + 1, 1, <<Acc/binary, $\n>>);
scan_block_comment(<<C, Rest/binary>>, L, Col, Acc) ->
    scan_block_comment(Rest, L, Col + 1, <<Acc/binary, C>>);
scan_block_comment(<<>>, L, Col, _Acc) ->
    error({scan_error, {unterminated_block_comment, {L, Col}}}).

%%%-------------------------------------------------------------------
%%% Hash forms — lfe_scan:scan_hash1/5, scan_hash2/5. `Start' is the `#' pos;
%%% `Col' is the live cursor (already past the `#').
%%%-------------------------------------------------------------------

scan_hash(Bin, L, Col, Start) ->
    {Digits, Rest, DCol} = take_digits(Bin, Col),
    scan_hash1(Rest, L, DCol, Digits, Start).

%% Length-then-slice (sub-binary, no per-char copy).
take_digits(Bin, Col) ->
    N = digit_len(Bin, 0),
    <<Digits:N/binary, Rest/binary>> = Bin,
    {Digits, Rest, Col + N}.

digit_len(<<C, R/binary>>, N) when ?IS_DIGIT(C) -> digit_len(R, N + 1);
digit_len(_, N) -> N.

%% scan_hash1 — single-character hash tokens (only when no base digits).
scan_hash1(<<$(, Rest/binary>>, L, Col, <<>>, Start) ->
    {{'#(', none, Start}, Rest, L, Col + 1};
scan_hash1(<<$., Rest/binary>>, L, Col, <<>>, Start) ->
    {{'#.', none, Start}, Rest, L, Col + 1};
scan_hash1(<<$`, Rest/binary>>, L, Col, <<>>, Start) ->
    {{'#`', none, Start}, Rest, L, Col + 1};
scan_hash1(<<$;, Rest/binary>>, L, Col, <<>>, Start) ->
    {{'#;', none, Start}, Rest, L, Col + 1};
scan_hash1(<<$|, Rest/binary>>, L, Col, <<>>, Start) ->
    {Text, Rest1, L1, C1} = scan_block_comment(Rest, L, Col + 1, <<>>),
    {{comment, {block, Text}, Start}, Rest1, L1, C1};
scan_hash1(<<$", Rest/binary>>, L, Col, <<>>, Start) ->
    scan_string(Rest, L, Col + 1, Start, binary);
scan_hash1(<<$', Rest/binary>>, L, Col, <<>>, Start) ->
    scan_fun(Rest, L, Col + 1, Start);
scan_hash1(<<$*, Rest/binary>>, L, Col, <<>>, Start) ->
    scan_bnumber(Rest, 2, L, Col + 1, Start);
scan_hash1(<<C, Rest/binary>>, L, Col, <<>>, Start) when C =:= $o; C =:= $O ->
    scan_bnumber(Rest, 8, L, Col + 1, Start);
scan_hash1(<<C, Rest/binary>>, L, Col, <<>>, Start) when C =:= $d; C =:= $D ->
    scan_bnumber(Rest, 10, L, Col + 1, Start);
scan_hash1(<<C, Rest/binary>>, L, Col, <<>>, Start) when C =:= $x; C =:= $X ->
    scan_bnumber(Rest, 16, L, Col + 1, Start);
scan_hash1(<<C, Rest/binary>>, L, Col, Digits, Start) when
    (C =:= $r orelse C =:= $R), Digits =/= <<>>
->
    Base = binary_to_integer(<<$0, Digits/binary>>),
    (Base >= 2 andalso Base =< 36) orelse error({scan_error, {bad_base, Base, Start}}),
    scan_bnumber(Rest, Base, L, Col + 1, Start);
scan_hash1(Bin, L, Col, Digits, Start) ->
    scan_hash2(Bin, L, Col, Digits, Start).

%% scan_hash2 — two-character hash tokens.
scan_hash2(<<$\\, C, Rest/binary>>, L, Col, <<>>, Start) ->
    %% `#\C' character literal — value is the codepoint, tagged `number' as in
    %% lfe_scan.
    {{number, C, Start}, Rest, L, Col + 2};
scan_hash2(<<$,, $@, Rest/binary>>, L, Col, <<>>, Start) ->
    {{'#,@', none, Start}, Rest, L, Col + 2};
scan_hash2(<<$,, Rest/binary>>, L, Col, <<>>, Start) ->
    {{'#,', none, Start}, Rest, L, Col + 1};
scan_hash2(<<C, $(, Rest/binary>>, L, Col, <<>>, Start) when C =:= $m; C =:= $M ->
    {{'#M(', none, Start}, Rest, L, Col + 2};
scan_hash2(<<C, $(, Rest/binary>>, L, Col, <<>>, Start) when C =:= $s; C =:= $S ->
    {{'#S(', none, Start}, Rest, L, Col + 2};
%% `#B(' binary constructor — must precede the `#b…' based number.
scan_hash2(<<C, $(, Rest/binary>>, L, Col, <<>>, Start) when C =:= $b; C =:= $B ->
    {{'#B(', none, Start}, Rest, L, Col + 2};
scan_hash2(<<C, C1, Rest/binary>>, L, Col, <<>>, Start) when
    (C =:= $b orelse C =:= $B), C1 =/= $(
->
    scan_bnumber(<<C1, Rest/binary>>, 2, L, Col + 1, Start);
scan_hash2(<<C, _/binary>>, _L, _Col, _Digits, Start) ->
    error({scan_error, {illegal_token, <<$#, C>>, Start}}).

%%%-------------------------------------------------------------------
%%% Fun reference `#'name/arity' — lfe_scan:scan_fun1/5, scan_fun_ret/5
%%%-------------------------------------------------------------------

scan_fun(Bin, L, Col, Start) ->
    {Syms, Rest, NCol} = take_symbol(Bin, Col),
    case binary:split(Syms, <<$/>>) of
        [_Name, Arity] when Arity =/= <<>> ->
            is_all_digits(Arity) orelse error({scan_error, {bad_fun_ref, Syms, Start}}),
            {{'#\'', binary_to_list(Syms), Start}, Rest, L, NCol};
        _ ->
            error({scan_error, {bad_fun_ref, Syms, Start}})
    end.

is_all_digits(<<>>) -> true;
is_all_digits(<<C, R/binary>>) when ?IS_DIGIT(C) -> is_all_digits(R);
is_all_digits(_) -> false.

%%%-------------------------------------------------------------------
%%% Symbols and numbers — lfe_scan:scan_symbol1/5, make_symbol_token/2
%%%-------------------------------------------------------------------

scan_symbol(Bin, L, Col) ->
    {Syms, Rest, NCol} = take_symbol(Bin, Col),
    {make_symbol_token(Syms, {L, Col}), Rest, L, NCol}.

%% Length-then-slice (sub-binary): the hottest path — every symbol and number.
take_symbol(Bin, Col) ->
    N = symbol_len(Bin, 0),
    <<Syms:N/binary, Rest/binary>> = Bin,
    {Syms, Rest, Col + N}.

symbol_len(<<C, R/binary>>, N) ->
    case symbol_char(C) of
        true -> symbol_len(R, N + 1);
        false -> N
    end;
symbol_len(<<>>, N) ->
    N.

%% An integer, else a float, else a symbol (lfe_scan:make_symbol_token/2).
make_symbol_token(Bin, Pos) ->
    Chars = binary_to_list(Bin),
    try
        {number, list_to_integer(Chars), Pos}
    catch
        _:_ ->
            try
                {number, list_to_float(Chars), Pos}
            catch
                _:_ -> {symbol, binary_to_atom(Bin, utf8), Pos}
            end
    end.

%% Quoted symbol `|…|' (lfe_scan:scan_qsymbol1/7). The leading `|' is consumed;
%% `Start' is its position.
scan_qsymbol(<<$\\, C, Rest/binary>>, L, Col, Start, Acc) ->
    scan_qsymbol(Rest, L, Col + 2, Start, <<Acc/binary, C>>);
scan_qsymbol(<<$|, Rest/binary>>, L, Col, Start, Acc) ->
    {{symbol, binary_to_atom(Acc, utf8), Start}, Rest, L, Col + 1};
scan_qsymbol(<<$\n, Rest/binary>>, L, _Col, Start, Acc) ->
    scan_qsymbol(Rest, L + 1, 1, Start, <<Acc/binary, $\n>>);
scan_qsymbol(<<C, Rest/binary>>, L, Col, Start, Acc) ->
    scan_qsymbol(Rest, L, Col + 1, Start, <<Acc/binary, C>>);
scan_qsymbol(<<>>, _L, _Col, Start, _Acc) ->
    error({scan_error, {unterminated_symbol, Start}}).

%%%-------------------------------------------------------------------
%%% Based numbers — lfe_scan:scan_bnumber/5 .. base_collect_chars/3
%%%-------------------------------------------------------------------

scan_bnumber(<<$+, Rest/binary>>, Base, L, Col, Start) ->
    scan_bnumber_digits(Rest, Base, 1, L, Col + 1, Start);
scan_bnumber(<<$-, Rest/binary>>, Base, L, Col, Start) ->
    scan_bnumber_digits(Rest, Base, -1, L, Col + 1, Start);
scan_bnumber(Bin, Base, L, Col, Start) ->
    scan_bnumber_digits(Bin, Base, 1, L, Col, Start).

scan_bnumber_digits(Bin, Base, Sign, L, Col, Start) ->
    {Digits, Rest, NCol} = take_symbol(Bin, Col),
    Digits =/= <<>> orelse error({scan_error, {bad_based_number, Start}}),
    case base_collect(binary_to_list(Digits), Base, 0) of
        {ok, N} -> {{number, Sign * N, Start}, Rest, L, NCol};
        error -> error({scan_error, {bad_based_number, Start}})
    end.

base_collect([C | Cs], Base, Acc) when C >= $0, C =< $9, C < Base + $0 ->
    base_collect(Cs, Base, Acc * Base + (C - $0));
base_collect([C | Cs], Base, Acc) when C >= $a, C =< $z, C < Base + $a - 10 ->
    base_collect(Cs, Base, Acc * Base + (C - $a + 10));
base_collect([C | Cs], Base, Acc) when C >= $A, C =< $Z, C < Base + $A - 10 ->
    base_collect(Cs, Base, Acc * Base + (C - $A + 10));
base_collect([], _Base, Acc) ->
    {ok, Acc};
base_collect(_, _Base, _Acc) ->
    error.

%%%-------------------------------------------------------------------
%%% Strings — lfe_scan:scan_string1/5, scan_sq_string1/8, scan_tq_string*.
%%% `Bin' is past the opening `"'; `Col' is the body's start column; `Start' is
%%% the token's start (the `"' or `#').
%%%-------------------------------------------------------------------

scan_string(<<$", $", Rest/binary>>, L, Col, Start, Type) ->
    scan_tq_string(Rest, L, Col + 2, Start, Type);
scan_string(Bin, L, Col, Start, Type) ->
    scan_sq_string(Bin, L, Col, Start, <<>>, Type).

%% Single-quote "normal" string (lfe_scan:scan_sq_string1/8).
scan_sq_string(<<$\\, C, Rest/binary>>, L, Col, Start, Acc, Type) ->
    scan_sq_string(Rest, L, Col + 2, Start, <<Acc/binary, (escape_char(C))>>, Type);
scan_sq_string(<<$", Rest/binary>>, L, Col, Start, Acc, Type) ->
    {string_token(Acc, Start, Type), Rest, L, Col + 1};
scan_sq_string(<<$\n, Rest/binary>>, L, _Col, Start, Acc, Type) ->
    scan_sq_string(Rest, L + 1, 1, Start, <<Acc/binary, $\n>>, Type);
scan_sq_string(<<C, Rest/binary>>, L, Col, Start, Acc, Type) ->
    scan_sq_string(Rest, L, Col + 1, Start, <<Acc/binary, C>>, Type);
scan_sq_string(<<>>, _L, _Col, Start, _Acc, _Type) ->
    error({scan_error, {unterminated_string, Start}}).

%% lfe_scan:escape_char/1
escape_char($b) -> $\b;
escape_char($t) -> $\t;
escape_char($n) -> $\n;
escape_char($v) -> $\v;
escape_char($f) -> $\f;
escape_char($r) -> $\r;
escape_char($e) -> $\e;
escape_char($s) -> $\s;
escape_char($d) -> $\d;
escape_char(C) -> C.

%% lfe_scan:string_token/3 — `string' is a codepoint list, `binary' a utf8 binary.
string_token(BodyBin, Pos, string) ->
    {string, unicode:characters_to_list(BodyBin), Pos};
string_token(BodyBin, Pos, binary) ->
    {binary, unicode:characters_to_binary(BodyBin, utf8, utf8), Pos}.

%% Triple-quoted string (lfe_scan:scan_tq_string_1/7 .. scan_tq_string_end/9):
%% the opening line after `"""' must be blank; the closing `"""' line's
%% indentation is the prefix stripped from every content line.
scan_tq_string(Bin, L, Col, Start, Type) ->
    {Rest, L1, C1} = tq_skip_first_line(Bin, L, Col, Start),
    tq_lines(Rest, L1, C1, Start, <<>>, [], Type).

tq_skip_first_line(<<$\s, Rest/binary>>, L, Col, Start) ->
    tq_skip_first_line(Rest, L, Col + 1, Start);
tq_skip_first_line(<<$\n, Rest/binary>>, L, _Col, _Start) ->
    {Rest, L + 1, 1};
tq_skip_first_line(_Bin, _L, _Col, Start) ->
    error({scan_error, {bad_triple_quote, Start}}).

%% Collect content lines until a `"""' that begins a blank (indent-only) line.
tq_lines(<<$\n, Rest/binary>>, L, _Col, Start, Lcs, Lines, Type) ->
    tq_lines(Rest, L + 1, 1, Start, <<>>, Lines ++ [Lcs], Type);
tq_lines(<<$", $", $", Rest/binary>>, L, Col, Start, Lcs, Lines, Type) ->
    case is_blank(Lcs) of
        true -> tq_end(Rest, L, Col + 3, Start, Lcs, Lines, Type);
        false -> tq_lines(Rest, L, Col + 3, Start, <<Lcs/binary, "\"\"\"">>, Lines, Type)
    end;
tq_lines(<<C, Rest/binary>>, L, Col, Start, Lcs, Lines, Type) ->
    tq_lines(Rest, L, Col + 1, Start, <<Lcs/binary, C>>, Lines, Type);
tq_lines(<<>>, _L, _Col, Start, _Lcs, _Lines, _Type) ->
    error({scan_error, {bad_triple_quote, Start}}).

tq_end(Rest, L, Col, Start, _Prefix, [], Type) ->
    {string_token(<<>>, Start, Type), Rest, L, Col};
tq_end(Rest, L, Col, Start, Prefix, Lines, Type) ->
    Stripped = [strip_prefix(Prefix, Line, Start) || Line <- Lines],
    Body = lists:join(<<$\n>>, Stripped),
    {string_token(iolist_to_binary(Body), Start, Type), Rest, L, Col}.

is_blank(<<>>) -> true;
is_blank(<<$\s, R/binary>>) -> is_blank(R);
is_blank(_) -> false.

%% Each content line must start with the closing-line indentation prefix
%% (lfe_scan:check_tqstring_prefix/2).
strip_prefix(<<>>, Line, _Start) -> Line;
strip_prefix(<<P, Ps/binary>>, <<P, Ls/binary>>, Start) -> strip_prefix(Ps, Ls, Start);
strip_prefix(_Prefix, _Line, Start) -> error({scan_error, {bad_triple_quote, Start}}).

%%%-------------------------------------------------------------------
%%% Character classes — lfe_scan:{start_,}symbol_char/1 (verbatim)
%%%-------------------------------------------------------------------

start_symbol_char($#) -> false;
start_symbol_char($`) -> false;
start_symbol_char($') -> false;
start_symbol_char($,) -> false;
start_symbol_char($|) -> false;
start_symbol_char(C) -> symbol_char(C).

symbol_char($() -> false;
symbol_char($)) -> false;
symbol_char($[) -> false;
symbol_char($]) -> false;
symbol_char(${) -> false;
symbol_char($}) -> false;
symbol_char($") -> false;
symbol_char($;) -> false;
symbol_char(C) -> ((C > $\s) andalso (C =< $~)) orelse (C > 16#A0).
