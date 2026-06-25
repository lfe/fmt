%%% @doc Test-only <b>faithful</b> reader bridge: real `.lfe' source ->
%%% `pe_lfe:form()' (arc2/slice1; evolved from slice6's lossy benchmark bridge).
%%%
%%% It reuses <b>LFE's own reader</b> (`lfe_io', a test-profile dependency —
%%% deliberately not flipped to a runtime dep; that is a later operator-gated
%%% decision per the arc2 plan) and converts the parsed s-expressions to an exact
%%% `pe_lfe:form()'. Every non-comment construct in real LFE source is modeled:
%%% atoms, integers, floats, binaries (`#"…"'/`#B(…)'), maps (`#M(…)'), tuples,
%%% strings, proper/improper lists, and the quote family incl. splicing
%%% comma-at. There is <b>no fallback and no genericisation</b> in the reader: an
%%% unmodeled term raises `{unmodeled_construct, _}'. The corpus AST round-trip
%%% (`pe_lfe_roundtrip_tests') proves the modeled set is complete for real LFE.
%%%
%%% What it does <em>not</em> preserve: comments and intra-form source spans
%%% (LFE's reader drops comments and gives line-only positions) — that is the
%%% slice2 boundary. `read_forms/1' captures the top-level form line (from
%%% `lfe_io:parse_file/1' `{Sexpr, Line}') and no deeper. Two constructs are
%%% value-faithful but lose surface syntax, because in LFE they are not distinct
%%% objects: a character `#\x' reads as its integer, and a string `"…"' reads as
%%% a char-list (so it is recovered via a printable-list heuristic). Restoring
%%% the `#\'/`"' surface syntax needs the slice2 token/span layer.
%%%
%%% Atom handling: `lfe_io' interns atoms — that is the reader's behaviour on the
%%% source we format. This module adds <em>no</em> `list_to_atom/1'; it only
%%% converts atom -> binary via `atom_to_binary/2', honouring the knowledge
%%% layer's binary-symbol contract.
%%%
%%% Quote-family head atoms are confirmed against LFE's grammar
%%% (`lfe_parse.erl' reductions 7–10): `'X' -> [quote, X]', `` `X `` ->
%%% `[backquote, X]', `,X -> [comma, X]', `,@X -> ['comma-at', X]'.
%%%
%%% Shape adaptation: a generic converter emits every code list as `{call}', but
%%% {@link pe_lfe}'s clause-bearing rules (`defun'/`defmacro' multi-clause,
%%% `case', `receive', `cond', `match-lambda') require clauses as `{list, [...]}'.
%%% So the reader emits clauses for those heads as `{list}' (structural mapping,
%%% not layout). The round-trip gate verifies this is a fixed point of
%%% `read ∘ format'. {@link safe_format_binary/2} (genericise + retry) is retained
%%% as <em>latency-bench</em> tooling for the slice6 harness only; the faithful
%%% round-trip path does not use it.
%%% @end
-module(pe_lfe_read).

-export([read_file/1, read_forms/1, convert/1, genericize/1, safe_format_binary/2]).

-type ctx() :: code | data.

-doc """
Read every top-level form of an `.lfe' file with its source line, via
`lfe_io:parse_file/1' (`{Sexpr, Line}'). Line is the top-level form's line only
(intra-form spans are slice2). Conversion is faithful and total-or-crash: an
unmodeled construct raises `{unmodeled_construct, _}'.
""".
-spec read_forms(file:name_all()) ->
    {ok, [{pe_lfe:form(), pos_integer()}]} | {error, term()}.
read_forms(Path) ->
    case lfe_io:parse_file(Path) of
        {ok, SexprLines} -> {ok, [{convert(S), Line} || {S, Line} <- SexprLines]};
        {error, _} = Error -> Error
    end.

-doc "Read and convert every top-level form of an `.lfe' file (lines dropped).".
-spec read_file(file:name_all()) -> {ok, [pe_lfe:form()]} | {error, term()}.
read_file(Path) ->
    case read_forms(Path) of
        {ok, FormLines} -> {ok, [Form || {Form, _Line} <- FormLines]};
        {error, _} = Error -> Error
    end.

-doc "Convert one read s-expression to a `pe_lfe:form()' (top level is code).".
-spec convert(term()) -> pe_lfe:form().
convert(Term) ->
    convert(Term, code).

%% Quote-family reader abbreviations (lfe_parse.erl reductions 7–10). The reader
%% produces these for both `'X' and the equivalent `(quote X)', so — like LFE's
%% own printer — we always render them abbreviated. The quoted body is data; an
%% unquote re-enters code.
-spec convert(term(), ctx()) -> pe_lfe:form().
convert([quote, X], _Ctx) ->
    {quote, convert(X, data)};
convert([backquote, X], _Ctx) ->
    {bquote, convert(X, data)};
convert([comma, X], _Ctx) ->
    {unquote, convert(X, code)};
convert(['comma-at', X], _Ctx) ->
    %% splicing unquote (,@) is faithfully its own node (slice6 dropped the @).
    {splice, convert(X, code)};
convert([], _Ctx) ->
    %% () and the empty list are indistinguishable to the reader.
    {list, []};
convert(A, _Ctx) when is_atom(A) ->
    {sym, atom_to_binary(A, utf8)};
convert(N, _Ctx) when is_integer(N) ->
    {int, N};
convert(F, _Ctx) when is_float(F) ->
    {float, F};
convert(B, _Ctx) when is_binary(B) ->
    %% `#"…"' and `#B(…)' both read as a binary; the literal node carries it.
    {binary, B};
convert(M, _Ctx) when is_map(M) ->
    %% `#M(…)' — a literal map; keys and values are data. `maps:to_list/1' is
    %% deterministic per map value, so both reads of a round-trip agree on order.
    {map, [{convert(K, data), convert(V, data)} || {K, V} <- maps:to_list(M)]};
convert(L, Ctx) when is_list(L) ->
    %% A non-empty printable char list is a string (in LFE a string *is* a
    %% char-list — same object, so `"abc"' and `(97 98 99)' are indistinguishable
    %% post-read). Carry it as a faithful `{str}' leaf; everything else is a
    %% code/data list.
    case io_lib:printable_unicode_list(L) of
        %% `lfe_io' yields a string as its raw bytes (UTF-8 already encoded), so
        %% `list_to_binary/1' preserves them — `characters_to_binary/1' would
        %% double-encode. A char in LFE *is* its integer, so this also covers
        %% `#\x' (it arrives as an int; only a printable *list* becomes a `{str}').
        true -> {str, list_to_binary(L)};
        false -> convert_list(L, Ctx)
    end;
convert(T, _Ctx) when is_tuple(T) ->
    {tuple, [convert(E, data) || E <- tuple_to_list(T)]};
convert(Other, _Ctx) ->
    %% No fallback: an unmodeled construct (fun, pid, ref, port, …) crashes with
    %% a clear error. The corpus round-trip proves the modeled set is complete
    %% for real LFE source (A2S1-5/9).
    error({unmodeled_construct, Other}).

%% A code list is a call (with shape adaptation for clause-bearing heads); a
%% data list (under quote/backquote) is a literal list. Improper lists become
%% dotted lists.
-spec convert_list([term()], ctx()) -> pe_lfe:form().
convert_list(L, Ctx) ->
    case split_improper(L, []) of
        {proper, Elems} ->
            case Ctx of
                code -> convert_code(Elems);
                data -> {list, [convert(E, data) || E <- Elems]}
            end;
        {improper, Heads, Tail} ->
            {dotted_list, [convert(H, Ctx) || H <- Heads], convert(Tail, Ctx)}
    end.

%%%-------------------------------------------------------------------
%%% Code-position lists: clause-bearing special forms get {list} clauses
%%%-------------------------------------------------------------------

convert_code([Head | Rest]) when is_atom(Head) ->
    case special_form(Head) of
        {defun, Kw} -> def_convert(Kw, Rest);
        {clauses, Kw} -> {call, [{sym, Kw} | [clause(C) || C <- Rest]]};
        {subject, Kw} -> subject_convert(Kw, Rest);
        none -> generic_call([Head | Rest])
    end;
convert_code(Elems) ->
    generic_call(Elems).

generic_call(Elems) ->
    {call, [convert(E, code) || E <- Elems]}.

special_form(defun) -> {defun, <<"defun">>};
special_form(defmacro) -> {defun, <<"defmacro">>};
special_form('match-lambda') -> {clauses, <<"match-lambda">>};
special_form('cond') -> {clauses, <<"cond">>};
%% receive's after branch is a `(after …)' clause; pe_lfe's lower_clause matches
%% it once it is a {list}, so receive uses the same generic-clause path.
special_form('receive') -> {clauses, <<"receive">>};
special_form('case') -> {subject, <<"case">>};
special_form(_) -> none.

%% (case subject clause…) — subject is code, the rest are clauses.
subject_convert(Kw, [Subject | Clauses]) ->
    {call, [{sym, Kw}, convert(Subject, code) | [clause(C) || C <- Clauses]]};
subject_convert(Kw, []) ->
    {call, [{sym, Kw}]}.

%% A clause `(pattern body…)' -> {list, [pattern, body…]}: the outer list is what
%% pe_lfe's lower_clause requires; the pattern and body stay code-shaped.
clause(C) when is_list(C) ->
    case split_improper(C, []) of
        {proper, [_, _ | _] = Elems} -> {list, [convert(E, code) || E <- Elems]};
        _ -> convert(C, code)
    end;
clause(C) ->
    convert(C, code).

%% (defun name (args) body…) single-clause, or (defun name ((args) body…) …)
%% multi-clause. Multi is detected exactly as pe_lfe does: the first remaining
%% element is a clause whose head is itself a list (the argument pattern).
def_convert(Kw, [Name | Rest]) ->
    NameForm = convert(Name, code),
    case Rest of
        [First | _] ->
            case arglist_pattern_clause(First) of
                true -> {call, [{sym, Kw}, NameForm | [defun_clause(C) || C <- Rest]]};
                false -> def_single(Kw, NameForm, Rest)
            end;
        [] ->
            {call, [{sym, Kw}, NameForm]}
    end;
def_convert(Kw, []) ->
    {call, [{sym, Kw}]}.

def_single(Kw, NameForm, [ArgList | Body]) ->
    {call, [{sym, Kw}, NameForm, arglist(ArgList) | [convert(B, code) || B <- Body]]};
def_single(Kw, NameForm, []) ->
    {call, [{sym, Kw}, NameForm]}.

%% A defun multi-clause: ((arg…) body…) -> {list, [{list, args}, body…]} so the
%% clause's first element is a {list}, which is how pe_lfe detects multi-clause.
defun_clause(C) when is_list(C) ->
    case split_improper(C, []) of
        %% A multi-clause arm: at least a pattern plus one body form. Written as
        %% `[Pattern | [_|_] = Body]' (not `[Pattern, _ | _] = [Pattern | Body]')
        %% to avoid OTP 29's match-alias-where-both-sides-are-constructors
        %% warning, which `warnings_as_errors' would turn into a compile error.
        {proper, [Pattern | [_ | _] = Body]} ->
            {list, [arglist(Pattern) | [convert(B, code) || B <- Body]]};
        _ ->
            clause(C)
    end;
defun_clause(C) ->
    convert(C, code).

%% A defun argument list -> {list, …} (so it is data-shaped, not a call).
arglist(A) when is_list(A) ->
    case split_improper(A, []) of
        {proper, Elems} -> {list, [convert(E, code) || E <- Elems]};
        _ -> convert(A, code)
    end;
arglist(A) ->
    convert(A, code).

%% True when X is a defun clause `((args…) body…)' — a proper, non-empty list
%% whose head is itself a list (the argument pattern). Distinguishes a
%% multi-clause head from a single-clause `(args)' whose head is a symbol.
arglist_pattern_clause(L) when is_list(L) ->
    case split_improper(L, []) of
        {proper, [H | _]} -> is_list(H);
        _ -> false
    end;
arglist_pattern_clause(_) ->
    false.

-spec split_improper(term(), [term()]) ->
    {proper, [term()]} | {improper, [term()], term()}.
split_improper([H | T], Acc) -> split_improper(T, [H | Acc]);
split_improper([], Acc) -> {proper, lists:reverse(Acc)};
split_improper(Tail, Acc) -> {improper, lists:reverse(Acc), Tail}.

%%%-------------------------------------------------------------------
%%% Crash-proof formatting: genericise + retry on any lowering crash
%%%-------------------------------------------------------------------

-doc """
Force a form to its generic data shape: every `{call}' becomes a `{list}', so no
`pe_lfe' special-form rule fires and lowering cannot crash. Used as the fallback
when a shape-adapted form still trips a clause rule (malformed/edge input).
""".
-spec genericize(pe_lfe:form()) -> pe_lfe:form().
genericize({call, Fs}) -> {list, [genericize(F) || F <- Fs]};
genericize({list, Fs}) -> {list, [genericize(F) || F <- Fs]};
genericize({tuple, Fs}) -> {tuple, [genericize(F) || F <- Fs]};
genericize({dotted_list, Fs, T}) -> {dotted_list, [genericize(F) || F <- Fs], genericize(T)};
genericize({quote, F}) -> {quote, genericize(F)};
genericize({bquote, F}) -> {bquote, genericize(F)};
genericize({unquote, F}) -> {unquote, genericize(F)};
genericize(Leaf) -> Leaf.

-doc """
Format a converted form, never crashing. Returns the rendered binary, its
measure and resolver stats, and a boolean that is `true' when the form had to
be genericised because the knowledge-layer lowering raised.
""".
-spec safe_format_binary(pe_lfe:form(), map()) ->
    {binary(), pe_measure:measure(), pe_resolve:stats(), boolean()}.
safe_format_binary(Form, Opts) ->
    try pe_lfe:format_binary(Form, Opts) of
        {Bin, Measure, Stats} -> {Bin, Measure, Stats, false}
    catch
        _Class:_Reason ->
            {Bin, Measure, Stats} = pe_lfe:format_binary(genericize(Form), Opts),
            {Bin, Measure, Stats, true}
    end.
