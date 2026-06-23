%%% @doc The first LFE knowledge layer: an explicit LFE term model plus
%%% form-aware lowering into the {@link pe_doc} engine.
%%%
%%% This is <em>not</em> a parser and does not preserve comments or source
%%% spans. It takes an explicit {@link form/0} term (symbols are binaries — no
%%% atoms are minted from source-like input) and lowers it to a document whose
%%% layout follows LFE conventions: special forms (`defun', `case', `receive',
%%% `let', `eval-when-compile', …) lay their bodies out as vertically-nested
%%% blocks, so a nested definition starts near block indentation rather than
%%% drifting far to the right. Ordinary calls fall back to generic
%%% S-expression layout (arguments aligned under the first argument).
%%%
%%% Layout rules are selected by matching the binary symbol at the head of a
%%% `{call, …}'; generic S-expression layout is the fallback, not the strategy.
%%% @end
-module(pe_lfe).

-moduledoc "The first LFE knowledge layer: LFE term model + form-aware lowering.".

-export([to_doc/1, to_doc/2, format/2, format_binary/2]).

-export_type([form/0]).

-doc """
An explicit LFE term. Source-like symbols and strings are binaries (never
atoms), so nothing is minted from input. Quote-family forms are explicit, and
call/special-form heads are inspectable without parsing text.
""".
-type form() ::
    {sym, binary()}
    | {str, binary()}
    | {int, integer()}
    | {quote, form()}
    | {bquote, form()}
    | {unquote, form()}
    | {list, [form()]}
    | {dotted_list, [form()], form()}
    | {tuple, [form()]}
    | {call, [form()]}.

%% Lowering context: the body indentation step.
-type ctx() :: #{indent := pos_integer()}.

-define(DEFAULT_INDENT, 2).

%%%-------------------------------------------------------------------
%%% Public surface
%%%-------------------------------------------------------------------

-doc "Lower a form to a frozen document with default options.".
-spec to_doc(form()) -> pe_doc:dag().
to_doc(Form) ->
    to_doc(Form, #{}).

-doc "Lower a form to a frozen document. Options: `indent' (body step, default 2).".
-spec to_doc(form(), map()) -> pe_doc:dag().
to_doc(Form, Opts) ->
    Ctx = #{indent => maps:get(indent, Opts, ?DEFAULT_INDENT)},
    {Root, Builder} = lower(Form, Ctx, pe_doc:new()),
    pe_doc:freeze(Builder, Root).

-doc "Lower then resolve+render via the {@link pe} facade (resolver options pass through).".
-spec format(form(), map()) ->
    {iolist(), pe_measure:measure(), pe_resolve:stats()}.
format(Form, Opts) ->
    pe:format(to_doc(Form), Opts).

-doc "Lower then resolve+render to a binary via the {@link pe} facade.".
-spec format_binary(form(), map()) ->
    {binary(), pe_measure:measure(), pe_resolve:stats()}.
format_binary(Form, Opts) ->
    pe:format_binary(to_doc(Form), Opts).

%%%-------------------------------------------------------------------
%%% Lowering: form -> {id, builder}
%%%-------------------------------------------------------------------

-spec lower(form(), ctx(), pe_doc:builder()) -> {pe_doc:id(), pe_doc:builder()}.
lower({sym, Bin}, _Ctx, B) when is_binary(Bin) ->
    pe_doc:text(Bin, B);
lower({str, S}, _Ctx, B) when is_binary(S) ->
    pe_doc:text(<<$", S/binary, $">>, B);
lower({int, N}, _Ctx, B) when is_integer(N) ->
    pe_doc:text(integer_to_binary(N), B);
lower({quote, F}, Ctx, B) ->
    prefix(<<"'">>, F, Ctx, B);
lower({bquote, F}, Ctx, B) ->
    prefix(<<"`">>, F, Ctx, B);
lower({unquote, F}, Ctx, B) ->
    prefix(<<",">>, F, Ctx, B);
lower({tuple, Fs}, Ctx, B) ->
    aligned_brackets(<<"#(">>, <<")">>, Fs, Ctx, B);
lower({list, Fs}, Ctx, B) ->
    aligned_brackets(<<"(">>, <<")">>, Fs, Ctx, B);
lower({dotted_list, Fs, Tail}, Ctx, B) ->
    dotted(Fs, Tail, Ctx, B);
lower({call, Forms}, Ctx, B) ->
    call_form(Forms, Ctx, B).

%%%-------------------------------------------------------------------
%%% Call dispatch: match the head symbol; generic S-expression is fallback
%%%-------------------------------------------------------------------

-spec call_form([form()], ctx(), pe_doc:builder()) -> {pe_doc:id(), pe_doc:builder()}.
call_form([{sym, Head} | Args] = Forms, Ctx, B) ->
    case Head of
        <<"defun">> -> def_form(Head, Args, Ctx, B);
        <<"defmacro">> -> def_form(Head, Args, Ctx, B);
        <<"lambda">> -> lambda_form(Head, Args, Ctx, B);
        <<"match-lambda">> -> clauses_block([{sym, Head}], Args, Ctx, B);
        <<"let">> -> let_form(Head, Args, Ctx, B);
        <<"let*">> -> let_form(Head, Args, Ctx, B);
        <<"flet">> -> let_form(Head, Args, Ctx, B);
        <<"fletrec">> -> let_form(Head, Args, Ctx, B);
        <<"case">> -> subject_block(Head, Args, Ctx, B);
        <<"receive">> -> receive_form(Head, Args, Ctx, B);
        <<"cond">> -> clauses_block([{sym, Head}], Args, Ctx, B);
        <<"progn">> -> body_block([{sym, Head}], Args, Ctx, B);
        <<"eval-when-compile">> -> body_block([{sym, Head}], Args, Ctx, B);
        _ -> generic_call(Forms, Ctx, B)
    end;
call_form(Forms, Ctx, B) ->
    %% head is not a plain symbol (e.g. a lambda in head position)
    generic_call(Forms, Ctx, B).

%% (defun name clause…) / (defun name (args) body…)
def_form(Kw, [Name | Rest], Ctx, B) ->
    case Rest of
        [{list, [{list, _} | _]} | _] ->
            %% multi-clause: each Rest element is a clause ((pat…) body…)
            clauses_block([{sym, Kw}, Name], Rest, Ctx, B);
        [ArgList | Body] ->
            %% single-clause: ArgList is the argument list, rest is the body
            body_block([{sym, Kw}, Name, ArgList], Body, Ctx, B)
    end.

%% (lambda (args) body…)
lambda_form(Kw, [ArgList | Body], Ctx, B) ->
    body_block([{sym, Kw}, ArgList], Body, Ctx, B).

%% (let (binding…) body…) and the flet/fletrec/let* family.
let_form(Kw, [Bindings | Body], Ctx, B) ->
    body_block([{sym, Kw}, Bindings], Body, Ctx, B).

%% (case subject clause…)
subject_block(Kw, [Subject | Clauses], Ctx, B) ->
    clauses_block([{sym, Kw}, Subject], Clauses, Ctx, B).

%% (receive clause… [(after timeout body…)])
receive_form(Kw, Clauses, Ctx, B0) ->
    {ClauseIds, B1} = lower_clauses(Clauses, Ctx, B0),
    block([{sym, Kw}], ClauseIds, Ctx, B1).

%%%-------------------------------------------------------------------
%%% Block builders
%%%-------------------------------------------------------------------

%% A block whose body forms are lowered generically (progn, eval-when-compile,
%% single-clause defun/lambda bodies).
body_block(HeadForms, BodyForms, Ctx, B0) ->
    {BodyIds, B1} = lower_list(BodyForms, Ctx, B0),
    block(HeadForms, BodyIds, Ctx, B1).

%% A block whose body forms are clauses ((pattern body…)), each laid out as a
%% nested clause (defun/defmacro multi-clause, match-lambda, case, cond).
clauses_block(HeadForms, ClauseForms, Ctx, B0) ->
    {ClauseIds, B1} = lower_clauses(ClauseForms, Ctx, B0),
    block(HeadForms, ClauseIds, Ctx, B1).

%% Assemble "(" head <nest(nl body…)> ")" as a group: a head line, then a
%% vertically-broken body indented by the context step.
block(HeadForms, BodyIds, #{indent := Indent} = Ctx, B0) ->
    {HeadIds, B1} = lower_list(HeadForms, Ctx, B0),
    {HeadDoc, B2} = join_space(HeadIds, B1),
    {BodyDoc, B3} = join_nl(BodyIds, B2),
    {Nl, B4} = pe_doc:nl(B3),
    {NlBody, B5} = pe_doc:concat(Nl, BodyDoc, B4),
    {Nested, B6} = pe_doc:nest(Indent, NlBody, B5),
    {HeadNested, B7} = pe_doc:concat(HeadDoc, Nested, B6),
    group_parens(HeadNested, B7).

%% Lower a clause form ((pattern body…) / (after timeout body…)) to a nested
%% clause document.
lower_clause({list, [{sym, <<"after">>} = After, Timeout | Body]}, Ctx, B0) ->
    %% receive's after branch: keep the timeout on the head line.
    {HeadIds, B1} = lower_list([After, Timeout], Ctx, B0),
    {HeadDoc, B2} = join_space(HeadIds, B1),
    {BodyIds, B3} = lower_list(Body, Ctx, B2),
    block_doc(HeadDoc, BodyIds, Ctx, B3);
lower_clause({list, [Pattern | Body]}, Ctx, B0) ->
    {PatId, B1} = lower(Pattern, Ctx, B0),
    {BodyIds, B2} = lower_list(Body, Ctx, B1),
    block_doc(PatId, BodyIds, Ctx, B2).

%% Like block/4 but the head is an already-built doc id.
block_doc(HeadId, BodyIds, #{indent := Indent}, B0) ->
    {BodyDoc, B1} = join_nl(BodyIds, B0),
    {Nl, B2} = pe_doc:nl(B1),
    {NlBody, B3} = pe_doc:concat(Nl, BodyDoc, B2),
    {Nested, B4} = pe_doc:nest(Indent, NlBody, B3),
    {HeadNested, B5} = pe_doc:concat(HeadId, Nested, B4),
    group_parens(HeadNested, B5).

%%%-------------------------------------------------------------------
%%% Generic S-expression fallback and data forms
%%%-------------------------------------------------------------------

%% (head arg…) — head, a space, then args aligned under the first arg; a group.
generic_call([Single], Ctx, B0) ->
    {Id, B1} = lower(Single, Ctx, B0),
    wrap_parens(Id, B1);
generic_call([Head | Args], Ctx, B0) ->
    {HeadId, B1} = lower(Head, Ctx, B0),
    {ArgIds, B2} = lower_list(Args, Ctx, B1),
    {Body, B3} = join_nl(ArgIds, B2),
    {Aligned, B4} = pe_doc:align(Body, B3),
    {Sp, B5} = pe_doc:text(<<" ">>, B4),
    {HeadSp, B6} = pe_doc:concat(HeadId, Sp, B5),
    {Inner, B7} = pe_doc:concat(HeadSp, Aligned, B6),
    group_parens(Inner, B7).

%% Bracketed data: "(item…)" / "#(item…)" with elements aligned; a group.
aligned_brackets(Open, Close, [], _Ctx, B0) ->
    {O, B1} = pe_doc:text(Open, B0),
    {C, B2} = pe_doc:text(Close, B1),
    pe_doc:concat(O, C, B2);
aligned_brackets(Open, Close, Fs, Ctx, B0) ->
    {Ids, B1} = lower_list(Fs, Ctx, B0),
    {Body, B2} = join_nl(Ids, B1),
    {Aligned, B3} = pe_doc:align(Body, B2),
    {O, B4} = pe_doc:text(Open, B3),
    {C, B5} = pe_doc:text(Close, B4),
    {OBody, B6} = pe_doc:concat(O, Aligned, B5),
    {Full, B7} = pe_doc:concat(OBody, C, B6),
    pe_doc:group(Full, B7).

%% (item… . tail)
dotted(Fs, Tail, Ctx, B0) ->
    {Ids, B1} = lower_list(Fs, Ctx, B0),
    {TailId, B2} = lower(Tail, Ctx, B1),
    {Dot, B3} = pe_doc:text(<<". ">>, B2),
    {DotTail, B4} = pe_doc:concat(Dot, TailId, B3),
    {Body, B5} = join_nl(Ids ++ [DotTail], B4),
    {Aligned, B6} = pe_doc:align(Body, B5),
    {O, B7} = pe_doc:text(<<"(">>, B6),
    {C, B8} = pe_doc:text(<<")">>, B7),
    {OBody, B9} = pe_doc:concat(O, Aligned, B8),
    {Full, B10} = pe_doc:concat(OBody, C, B9),
    pe_doc:group(Full, B10).

%%%-------------------------------------------------------------------
%%% Lowering helpers
%%%-------------------------------------------------------------------

prefix(Prefix, Form, Ctx, B0) ->
    {T, B1} = pe_doc:text(Prefix, B0),
    {Id, B2} = lower(Form, Ctx, B1),
    pe_doc:concat(T, Id, B2).

-spec lower_list([form()], ctx(), pe_doc:builder()) -> {[pe_doc:id()], pe_doc:builder()}.
lower_list([], _Ctx, B) ->
    {[], B};
lower_list([F | Fs], Ctx, B0) ->
    {Id, B1} = lower(F, Ctx, B0),
    {Ids, B2} = lower_list(Fs, Ctx, B1),
    {[Id | Ids], B2}.

-spec lower_clauses([form()], ctx(), pe_doc:builder()) -> {[pe_doc:id()], pe_doc:builder()}.
lower_clauses([], _Ctx, B) ->
    {[], B};
lower_clauses([C | Cs], Ctx, B0) ->
    {Id, B1} = lower_clause(C, Ctx, B0),
    {Ids, B2} = lower_clauses(Cs, Ctx, B1),
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
