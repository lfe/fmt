%%% @doc Test-only minimal reader bridge: real `.lfe' source -> `pe_lfe:form()'.
%%%
%%% This exists only to get whole-file latency numbers (slice6). It reuses
%%% <b>LFE's own reader</b> (`lfe_io', a test-profile dependency) rather than a
%%% bespoke front end, then converts the read s-expressions into the
%%% `pe_lfe:form()' term model. It is <em>not</em> a faithful formatter front
%%% end: it does not preserve comments or source spans (LFE's reader drops
%%% comments), and several leaf kinds are approximated (see `convert/2'). That
%%% faithful reader is the deferred A1-R015.
%%%
%%% Atom handling: `lfe_io:read_file/1' interns atoms — that is the reader's
%%% behaviour on the (semi-trusted) source we are formatting. This module adds
%%% <em>no</em> `list_to_atom/1' of its own; it only converts atom -> binary via
%%% `atom_to_binary/2', staying consistent with the knowledge layer's
%%% binary-symbol contract.
%%%
%%% Quote-family head atoms are confirmed against LFE's grammar
%%% (`lfe_parse.erl' reductions 7–10): `'X' -> [quote, X]', `` `X `` ->
%%% `[backquote, X]', `,X -> [comma, X]', `,@X -> ['comma-at', X]'.
%%%
%%% Shape adaptation: a generic converter would emit every code list as
%%% `{call}', but {@link pe_lfe}'s clause-bearing rules (`defun'/`defmacro'
%%% multi-clause, `case', `receive', `cond', `match-lambda') require clauses as
%%% `{list, [...]}'. So the bridge emits clauses for those heads as `{list}'
%%% (structural mapping, not layout — the layout still lives entirely in
%%% `pe_lfe'). As a belt-and-suspenders guard, {@link safe_format_binary/2}
%%% genericises (forces `{call}` -> `{list}`) and retries on any residual
%%% lowering crash, so formatting a converted form never throws.
%%% @end
-module(pe_lfe_read).

-export([read_file/1, convert/1, genericize/1, safe_format_binary/2]).

-type ctx() :: code | data.

-doc "Read and convert every top-level form of an `.lfe' file.".
-spec read_file(file:name_all()) -> {ok, [pe_lfe:form()]} | {error, term()}.
read_file(Path) ->
    case lfe_io:read_file(Path) of
        {ok, Sexprs} -> {ok, [convert(S) || S <- Sexprs]};
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
    %% comma-at is splicing unquote (,@); pe_lfe:form() has no splice node, so
    %% it is approximated as a plain unquote (drops the @). Latency, not fidelity.
    {unquote, convert(X, code)};
convert([], _Ctx) ->
    %% () and the empty list are indistinguishable to the reader.
    {list, []};
convert(A, _Ctx) when is_atom(A) ->
    {sym, atom_to_binary(A, utf8)};
convert(N, _Ctx) when is_integer(N) ->
    {int, N};
convert(L, Ctx) when is_list(L) ->
    %% A printable char list is (ambiguously) a string; carry it as one printed
    %% leaf rather than exploding it into per-character integer nodes — closer
    %% to a real formatter's node count and avoids inflating latency.
    case io_lib:printable_unicode_list(L) of
        true -> fallback(L);
        false -> convert_list(L, Ctx)
    end;
convert(T, Ctx) when is_tuple(T) ->
    {tuple, [convert(E, Ctx) || E <- tuple_to_list(T)]};
convert(Other, _Ctx) ->
    %% float, binary (#"..."), map, fun, pid, ... — anything unmodeled. The
    %% printed-text fallback guarantees a structurally representative leaf and
    %% never crashes.
    fallback(Other).

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

-spec fallback(term()) -> pe_lfe:form().
fallback(Term) ->
    {sym, iolist_to_binary(lfe_io:print1(Term))}.

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
