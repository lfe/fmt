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
%%% Layout rules are selected by a data-driven registry (loaded from
%%% `priv/lfe-format-rules.eterm'): the binary symbol at the head of a `{call,
%%% …}' is looked up to a style tag in a fixed palette, dispatched through
%%% {@link apply_style/6}. Generic S-expression layout is the fallback, not the
%%% strategy. Adding a form that fits an existing style is a data-only edit.
%%% @end
-module(pe_lfe).

-moduledoc "The first LFE knowledge layer: LFE term model + form-aware lowering.".

-export([to_doc/1, to_doc/2, format/2, format_binary/2]).
-export([load_rules/0, load_rules/1, read_rules/1]).

-export_type([form/0, registry/0, style_tag/0]).

-doc """
An explicit LFE term. Source-like symbols and strings are binaries (never
atoms), so nothing is minted from input. Quote-family forms are explicit, and
call/special-form heads are inspectable without parsing text.
""".
-type form() ::
    {sym, binary()}
    | {str, binary()}
    | {int, integer()}
    | {float, float()}
    | {binary, binary()}
    | {map, [{form(), form()}]}
    | {quote, form()}
    | {bquote, form()}
    | {unquote, form()}
    | {splice, form()}
    | {list, [form()]}
    | {dotted_list, [form()], form()}
    | {tuple, [form()]}
    | {call, [form()]}.

-doc "A style tag in the fixed layout palette (a closed, developer set).".
-type style_tag() ::
    define | lambda | clauses | 'let-binds' | 'flet-binds' | subject | 'receive' | block.

-doc "A loaded rule registry: form-name binary -> {style tag, params}.".
-type registry() :: #{binary() => {style_tag(), [term()]}}.

%% Lowering context: the body indentation step and the rule registry.
-type ctx() :: #{indent := pos_integer(), registry := registry()}.

-define(DEFAULT_INDENT, 2).

%% Base rules file (in priv/), and the closed palette tag set.
-define(RULES_FILE, "lfe-format-rules.eterm").
-define(RULES_CACHE, {?MODULE, base_rules_v1}).
-define(STYLE_TAGS, [
    define, lambda, clauses, 'let-binds', 'flet-binds', subject, 'receive', block
]).

%%%-------------------------------------------------------------------
%%% Public surface
%%%-------------------------------------------------------------------

-doc "Lower a form to a frozen document with default options.".
-spec to_doc(form()) -> pe_doc:dag().
to_doc(Form) ->
    to_doc(Form, #{}).

-doc """
Lower a form to a frozen document. Options:
- `indent' — body indentation step (default 2);
- `registry' — a caller-supplied {@type registry()} (tests / overlay); defaults
  to the cached base registry from `priv/lfe-format-rules.eterm'.
""".
-spec to_doc(form(), map()) -> pe_doc:dag().
to_doc(Form, Opts) ->
    Ctx = #{
        indent => maps:get(indent, Opts, ?DEFAULT_INDENT),
        registry => maps:get(registry, Opts, load_rules())
    },
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
%%% Rule registry: data-driven head dispatch
%%%
%%% The registry maps a special-form head (binary) to a style tag in the fixed
%%% palette plus params. The base is `priv/lfe-format-rules.eterm', read once via
%%% `file:consult/1' (pure OTP — no lfe runtime dependency) and cached read-only
%%% in `persistent_term' (the cache is never the source of truth: callers can
%%% pass their own `registry'). Form names are strings -> binary keys, so no atom
%%% is minted from a form name; style tags are atoms from this trusted in-repo
%%% config, validated against the closed palette set at load.
%%%-------------------------------------------------------------------

-doc "The cached base registry from `priv/lfe-format-rules.eterm' (read once).".
-spec load_rules() -> registry().
load_rules() ->
    case persistent_term:get(?RULES_CACHE, undefined) of
        undefined ->
            Registry = read_rules(base_rules_path()),
            persistent_term:put(?RULES_CACHE, Registry),
            Registry;
        Registry ->
            Registry
    end.

-doc "The base registry with a user `Overlay' merged over it (overlay wins per form).".
-spec load_rules(registry()) -> registry().
load_rules(Overlay) when is_map(Overlay) ->
    maps:merge(load_rules(), Overlay).

-doc """
Read and validate a rules file into a {@type registry()}. Each `{rule, Name,
Tag, Params}' term contributes `Name' (a string) as a binary key mapped to
`{Tag, Params}'; an unknown style tag is a load error, not a silent skip.
""".
-spec read_rules(file:name_all()) -> registry().
read_rules(Path) ->
    {ok, Terms} = file:consult(Path),
    parse_rules(Terms, #{}).

parse_rules([], Registry) ->
    Registry;
parse_rules([{rules_version, V} | Rest], Registry) when is_integer(V) ->
    parse_rules(Rest, Registry);
parse_rules([{rule, Name, Tag, Params} | Rest], Registry) when
    is_list(Name), is_atom(Tag), is_list(Params)
->
    case lists:member(Tag, ?STYLE_TAGS) of
        true -> parse_rules(Rest, Registry#{list_to_binary(Name) => {Tag, Params}});
        false -> error({unknown_style_tag, Tag, Name})
    end;
parse_rules([Bad | _], _Registry) ->
    error({malformed_rule, Bad}).

base_rules_path() ->
    filename:join(code:priv_dir(lfmt), ?RULES_FILE).

%%%-------------------------------------------------------------------
%%% Lowering: form -> {id, builder}
%%%-------------------------------------------------------------------

-spec lower(form(), ctx(), pe_doc:builder()) -> {pe_doc:id(), pe_doc:builder()}.
lower({sym, Bin}, _Ctx, B) when is_binary(Bin) ->
    pe_doc:text(render_symbol(Bin), B);
lower({str, S}, _Ctx, B) when is_binary(S) ->
    pe_doc:text(<<$", (escape_string(S))/binary, $">>, B);
lower({int, N}, _Ctx, B) when is_integer(N) ->
    pe_doc:text(integer_to_binary(N), B);
lower({float, F}, _Ctx, B) when is_float(F) ->
    %% Shortest round-trippable rendering (re-reads to an equal float).
    pe_doc:text(float_to_binary(F, [short]), B);
lower({binary, Bin}, _Ctx, B) when is_binary(Bin) ->
    pe_doc:text(render_binary(Bin), B);
lower({map, KVs}, Ctx, B) when is_list(KVs) ->
    %% `#M(k v k v …)' — keys and values flattened into one aligned group.
    Flat = lists:flatmap(fun({K, V}) -> [K, V] end, KVs),
    aligned_brackets(<<"#M(">>, <<")">>, Flat, Ctx, B);
lower({quote, F}, Ctx, B) ->
    prefix(<<"'">>, F, Ctx, B);
lower({bquote, F}, Ctx, B) ->
    prefix(<<"`">>, F, Ctx, B);
lower({unquote, F}, Ctx, B) ->
    prefix(<<",">>, F, Ctx, B);
lower({splice, F}, Ctx, B) ->
    prefix(<<",@">>, F, Ctx, B);
lower({tuple, Fs}, Ctx, B) ->
    aligned_brackets(<<"#(">>, <<")">>, Fs, Ctx, B);
lower({list, Fs}, Ctx, B) ->
    aligned_brackets(<<"(">>, <<")">>, Fs, Ctx, B);
lower({dotted_list, Fs, Tail}, Ctx, B) ->
    dotted(Fs, Tail, Ctx, B);
lower({call, Forms}, Ctx, B) ->
    call_form(Forms, Ctx, B).

%%%-------------------------------------------------------------------
%%% Call dispatch: registry lookup -> apply_style; generic S-expression fallback
%%%-------------------------------------------------------------------

-spec call_form([form()], ctx(), pe_doc:builder()) -> {pe_doc:id(), pe_doc:builder()}.
call_form([{sym, Head} | Args] = Forms, #{registry := Registry} = Ctx, B) ->
    case maps:find(Head, Registry) of
        {ok, {Tag, Params}} -> apply_style(Tag, Params, Head, Args, Ctx, B);
        error -> generic_call(Forms, Ctx, B)
    end;
call_form(Forms, Ctx, B) ->
    %% head is not a plain symbol (e.g. a lambda in head position)
    generic_call(Forms, Ctx, B).

%% The fixed style palette, reached through one closed dispatch. Each clause
%% routes to a bespoke layout function (the irreducible code); adding a *form*
%% is a data row in priv/lfe-format-rules.eterm, adding a *style* is one clause
%% here plus a palette function. Params are unused today (the slot is open).
-spec apply_style(style_tag(), [term()], binary(), [form()], ctx(), pe_doc:builder()) ->
    {pe_doc:id(), pe_doc:builder()}.
apply_style(define, _Params, Head, Args, Ctx, B) ->
    def_form(Head, Args, Ctx, B);
apply_style(lambda, _Params, Head, Args, Ctx, B) ->
    lambda_form(Head, Args, Ctx, B);
apply_style(clauses, _Params, Head, Args, Ctx, B) ->
    clauses_block([{sym, Head}], Args, Ctx, B);
apply_style('let-binds', _Params, Head, Args, Ctx, B) ->
    let_form(Head, Args, Ctx, B);
apply_style('flet-binds', _Params, Head, Args, Ctx, B) ->
    flet_form(Head, Args, Ctx, B);
apply_style(subject, _Params, Head, Args, Ctx, B) ->
    subject_block(Head, Args, Ctx, B);
apply_style('receive', _Params, Head, Args, Ctx, B) ->
    receive_form(Head, Args, Ctx, B);
apply_style(block, _Params, Head, Args, Ctx, B) ->
    body_block([{sym, Head}], Args, Ctx, B).

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

%% (flet ((name (args…) body…) …) body…) and fletrec equivalent.
flet_form(Kw, [{list, Bindings} | Body], Ctx, B0) ->
    {BindingsId, B1} = flet_bindings(Bindings, Ctx, B0),
    {BodyIds, B2} = lower_list(Body, Ctx, B1),
    block([{sym, Kw}], [BindingsId | BodyIds], Ctx, B2);
flet_form(Kw, [Bindings | Body], Ctx, B) ->
    %% Malformed or non-list binding containers retain the generic safe shape.
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
%% vertically-broken body indented by the context step. A head with no body
%% (e.g. a `case' whose clause list is empty, as `try''s `(case …)' section
%% reads) renders as just `(head)'.
block(HeadForms, [], Ctx, B0) ->
    {HeadIds, B1} = lower_list(HeadForms, Ctx, B0),
    {HeadDoc, B2} = join_space(HeadIds, B1),
    group_parens(HeadDoc, B2);
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

%% Lower flet/fletrec binding lists. Function bindings get a local
%% name+args head; other binding shapes fall back to ordinary list lowering.
flet_bindings([], _Ctx, B0) ->
    {O, B1} = pe_doc:text(<<"(">>, B0),
    {C, B2} = pe_doc:text(<<")">>, B1),
    pe_doc:concat(O, C, B2);
flet_bindings(Bindings, Ctx, B0) ->
    {BindingIds, B1} = lower_flet_bindings(Bindings, Ctx, B0),
    {Body, B2} = join_nl(BindingIds, B1),
    {Aligned, B3} = pe_doc:align(Body, B2),
    group_parens(Aligned, B3).

lower_flet_binding({list, [Name, {list, _} = Args, FirstBody | RestBody]}, Ctx, B0) ->
    {NameId, B1} = lower(Name, Ctx, B0),
    {ArgsId, B2} = lower(Args, Ctx, B1),
    {HeadDoc, B3} = join_space([NameId, ArgsId], B2),
    {BodyIds, B4} = lower_list([FirstBody | RestBody], Ctx, B3),
    block_doc(HeadDoc, BodyIds, Ctx, B4);
lower_flet_binding(Binding, Ctx, B) ->
    lower(Binding, Ctx, B).

%% Like block/4 but the head is an already-built doc id. A bodyless clause
%% (a `(pattern)' with no body forms) renders as just `(pattern)'.
block_doc(HeadId, [], _Ctx, B0) ->
    group_parens(HeadId, B0);
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
    case lists:any(fun block_valued_arg/1, Args) of
        true -> generic_block_arg_call(Head, Args, Ctx, B0);
        false -> generic_aligned_call(Head, Args, Ctx, B0)
    end.

generic_aligned_call(Head, Args, Ctx, B0) ->
    {HeadId, B1} = lower(Head, Ctx, B0),
    {ArgIds, B2} = lower_list(Args, Ctx, B1),
    {Body, B3} = join_nl(ArgIds, B2),
    {Aligned, B4} = pe_doc:align(Body, B3),
    {Sp, B5} = pe_doc:text(<<" ">>, B4),
    {HeadSp, B6} = pe_doc:concat(HeadId, Sp, B5),
    {Inner, B7} = pe_doc:concat(HeadSp, Aligned, B6),
    group_parens(Inner, B7).

generic_block_arg_call(Head, Args, #{indent := Indent} = Ctx, B0) ->
    {HeadId, B1} = lower(Head, Ctx, B0),
    {ArgIds, B2} = lower_list(Args, Ctx, B1),
    {Body, B3} = join_nl(ArgIds, B2),
    {Nl, B4} = pe_doc:nl(B3),
    {NlBody, B5} = pe_doc:concat(Nl, Body, B4),
    {Nested, B6} = pe_doc:nest(Indent, NlBody, B5),
    {Inner, B7} = pe_doc:concat(HeadId, Nested, B6),
    group_parens(Inner, B7).

block_valued_arg({call, [{sym, <<"lambda">>} | _]}) -> true;
block_valued_arg({call, [{sym, <<"match-lambda">>} | _]}) -> true;
block_valued_arg({call, [{sym, <<"case">>} | _]}) -> true;
block_valued_arg({call, [{sym, <<"receive">>} | _]}) -> true;
block_valued_arg({call, [{sym, <<"cond">>} | _]}) -> true;
block_valued_arg(_) -> false.

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

%% Render a symbol, `|…|'-quoting it when the bare name would not re-read to the
%% same atom — a faithful replica of LFE's printer (`lfe_io_write:quote_symbol/2'
%% with `lfe_scan:start_symbol_char/1' + `symbol_char/1'), kept here so the
%% knowledge layer stays free of the test-only `lfe' dependency.
-spec render_symbol(binary()) -> binary().
render_symbol(Name) ->
    case needs_quote(unicode:characters_to_list(Name)) of
        true -> <<$|, (escape_symbol(Name))/binary, $|>>;
        false -> Name
    end.

%% mirrors lfe_io_write:quote_symbol/2: quote `.', the empty atom, anything that
%% reads as a number, or a name with a non-symbol char (or non-start char first).
-spec needs_quote([char()]) -> boolean().
needs_quote([]) ->
    true;
needs_quote([$.]) ->
    true;
needs_quote([C | Rest] = Cps) ->
    looks_numeric(Cps) orelse
        not (start_symbol_char(C) andalso lists:all(fun symbol_char/1, Rest)).

looks_numeric(Cps) ->
    is_numeric(fun erlang:list_to_float/1, Cps) orelse
        is_numeric(fun erlang:list_to_integer/1, Cps).

is_numeric(F, Cps) ->
    try F(Cps) of
        _ -> true
    catch
        _:_ -> false
    end.

%% lfe_scan:start_symbol_char/1
start_symbol_char($#) -> false;
start_symbol_char($`) -> false;
start_symbol_char($') -> false;
start_symbol_char($,) -> false;
start_symbol_char($|) -> false;
start_symbol_char(C) -> symbol_char(C).

%% lfe_scan:symbol_char/1
symbol_char($() -> false;
symbol_char($)) -> false;
symbol_char($[) -> false;
symbol_char($]) -> false;
symbol_char(${) -> false;
symbol_char($}) -> false;
symbol_char($") -> false;
symbol_char($;) -> false;
symbol_char(C) -> ((C > 16#20) andalso (C =< 16#7E)) orelse (C > 16#A0).

%% Inside a `|…|' symbol, escape `|' and `\' (the structural characters).
-spec escape_symbol(binary()) -> binary().
escape_symbol(Name) ->
    <<<<(escape_sym_char(C))/binary>> || <<C>> <= Name>>.

escape_sym_char($|) -> <<$\\, $|>>;
escape_sym_char($\\) -> <<$\\, $\\>>;
escape_sym_char(C) -> <<C>>.

%% Escape `"' and `\' inside a `"…"' / `#"…"' literal so the rendered text
%% re-reads to the same bytes.
-spec escape_string(binary()) -> binary().
escape_string(S) ->
    <<<<(escape_char(C))/binary>> || <<C>> <= S>>.

escape_char($") -> <<$\\, $">>;
escape_char($\\) -> <<$\\, $\\>>;
escape_char(C) -> <<C>>.

%% A binary literal renders as `#"…"' when every byte is printable ASCII (so the
%% string form is unambiguous), otherwise as `#B(byte …)' decimal bytes. Both
%% re-read to the identical binary.
-spec render_binary(binary()) -> binary().
render_binary(<<>>) ->
    %% `#""' is a scan error in LFE, so the empty binary uses the byte form.
    <<"#B()">>;
render_binary(Bin) ->
    case is_ascii_printable(Bin) of
        true -> <<"#\"", (escape_string(Bin))/binary, "\"">>;
        false -> <<"#B(", (byte_list(Bin))/binary, ")">>
    end.

-spec is_ascii_printable(binary()) -> boolean().
is_ascii_printable(<<>>) -> true;
is_ascii_printable(<<C, R/binary>>) when C >= 16#20, C =< 16#7E -> is_ascii_printable(R);
is_ascii_printable(_) -> false.

-spec byte_list(binary()) -> binary().
byte_list(Bin) ->
    iolist_to_binary(lists:join($\s, [integer_to_binary(B) || B <- binary_to_list(Bin)])).

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

lower_flet_bindings([], _Ctx, B) ->
    {[], B};
lower_flet_bindings([F | Fs], Ctx, B0) ->
    {Id, B1} = lower_flet_binding(F, Ctx, B0),
    {Ids, B2} = lower_flet_bindings(Fs, Ctx, B1),
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
