%%%% lfmt_fezzik_util: pure leaf helpers (classification, predicates, sorting,
%%%% cons-dot, flat rendering, trivia emission, column math).
%%%% Layer: lexer -> cst -> [util] -> render -> fezzik. Calls nothing above it.
-module(lfmt_fezzik_util).

-include("lfmt_fezzik.hrl").

-export([regime/2, split_dot_tail/2, apply_dot_suffix/3, is_when_form/1, head_has_leading_comment/1, any_dist_has_comment/1, must_break/1, is_export_import_with_entries/1, is_always_break_head/1, is_let_head/1, is_flet_head/1, local_fn_n/1, is_lambda_multi_body/1, is_clause_specform_head/2, is_defun_match_head/2, is_receive_head/1, is_try_head/1, is_export_import_head/1, is_export_entry/1, is_non_neg_integer_text/1, sort_export_entries/1, is_rename_entry/1, sort_rename_entries/1, sort_import_entries/2, is_after_section/1, all_clauses/1, trivial_clause/1, has_clause_internal_trivia/1, is_trivial_datum/1, is_arglist/1, is_force_break_defform/1, has_empty_arglist/1, defform_n/2, classify_head/1, specform_table/0, close_section/8, flat_render/1, flat_width/1, sum_widths/2, add_widths/2, emit_leading_trivia/3, emit_head_leading/2, emit_child_leading/3, emit_trailing/2, emit_dangling/2, emit_toplevel_dangling/1, has_internal_trivia/1, has_descendant_trivia/1, has_comment_leading/1, entry_has_comment/1, col_after_text/2]).


%%====================================================================
%% Internal: regime classification (A7·S2b)
%%====================================================================

-type regime() :: canonical | break_preserving.

%% regime/2: decide per container node whether the formatter owns layout
%% (canonical) or preserves the author's break positions (break_preserving).
%%
%% Rules (in priority order):
%%   InData=true         → break_preserving  (inside a quote — data context)
%%   tuple / binary      → break_preserving  (data containers)
%%   map                 → canonical          (k/v pair alignment owned by formatter)
%%   list/eval with specform or defform head → canonical
%%   any other list/eval (plain call, unknown head, non-symbol head) → break_preserving
%%
%% Note: leaves and prefixed nodes do not take a regime; only containers do.
-spec regime(lfmt_fezzik_cst:cst_node(), boolean()) -> regime().
regime(_Node, true) ->
    break_preserving;
regime(Node, false) ->
    case lfmt_fezzik_cst:type(Node) of
        tuple  -> break_preserving;
        binary -> break_preserving;
        map    -> canonical;
        T when T =:= list; T =:= eval ->
            case lfmt_fezzik_cst:dot_token(Node) of
                undefined ->
                    case lfmt_fezzik_cst:children(Node) of
                        [Head | _] ->
                            case classify_head(Head) of
                                {specform, _} -> canonical;
                                defform       -> canonical;
                                _             -> break_preserving
                            end;
                        [] -> break_preserving
                    end;
                _ ->
                    break_preserving  %% dotted lists are never canonical specforms
            end;
        _ ->
            break_preserving
    end.


%%====================================================================
%% Internal: cons-dot helpers (A7·S1)
%%====================================================================

%% split_dot_tail/2: for a dotted list, separate body children from the tail.
split_dot_tail(undefined, Children)  -> {Children, none};
split_dot_tail(_, [])                -> {[], none};
split_dot_tail(DotTok, Children) ->
    {lists:droplast(Children), {DotTok, lists:last(Children)}}.


%% apply_dot_suffix/3: append " . tail" IO after the body, returning updated col.
apply_dot_suffix(none, Col, HasTrail) ->
    {[], Col, HasTrail};
apply_dot_suffix({DotTok, TailNode}, Col, _HasTrail) ->
    DotText = lfmt_fezzik_lexer:text(DotTok),
    TailIO  = flat_render(TailNode),
    TailW   = case flat_width(TailNode) of infinity -> 0; W -> W end,
    TailCol = Col + 3 + TailW,
    TailHasTrail = lfmt_fezzik_cst:trailing(TailNode) =/= [],
    {[" ", DotText, " ", TailIO], TailCol, TailHasTrail}.


%% is_when_form: true if Node is a list whose first child is the symbol "when".
-spec is_when_form(lfmt_fezzik_cst:cst_node()) -> boolean().
is_when_form(Node) ->
    lfmt_fezzik_cst:type(Node) =:= list
    andalso case lfmt_fezzik_cst:children(Node) of
                [WHead | _] ->
                    lfmt_fezzik_cst:type(WHead) =:= symbol
                    andalso lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(WHead)) =:= "when";
                [] -> false
            end.


%% head_has_leading_comment: true iff the node's leading contains a comment.
-spec head_has_leading_comment(lfmt_fezzik_cst:cst_node()) -> boolean().
head_has_leading_comment(Node) ->
    lists:any(fun({comment, _}) -> true; (_) -> false end,
              lfmt_fezzik_cst:leading(Node)).


%% any_dist_has_comment: true if the distinguished args have an unsafe comment.
%% Safe: trailing comment on the LAST distinguished arg (ends head line; body
%% goes below at +2).  Unsafe: leading comment on ANY arg, or trailing comment
%% on a NON-LAST arg (would swallow the next distinguished arg on the same line).
-spec any_dist_has_comment([lfmt_fezzik_cst:cst_node()]) -> boolean().
any_dist_has_comment([]) -> false;
any_dist_has_comment([D]) ->
    %% Last item: trailing comment is safe; only leading triggers fallback.
    head_has_leading_comment(D);
any_dist_has_comment([D | Rest]) ->
    head_has_leading_comment(D)
    orelse lfmt_fezzik_cst:trailing(D) =/= []
    orelse any_dist_has_comment(Rest).


%% must_break: true when flat rendering must be suppressed regardless of width.
%%   • defform-headed lists (defun/defmacro with args, defmodule, defrecord, …)
%%   • maps: key-value pairs always on separate lines
%%   • list headed by let/let*/case/cond
%% Scope note: flet/fletrec/letrec-function and other let-family forms are NOT
%% forced — they retain flat-if-fits.  Extend this list when adjudicated.
-spec must_break(lfmt_fezzik_cst:cst_node()) -> boolean().
must_break(Node) ->
    case lfmt_fezzik_cst:type(Node) of
        map  -> true;
        list ->
            lfmt_fezzik_cst:dot_token(Node) =:= undefined
            andalso (is_force_break_defform(Node)
                     orelse is_always_break_head(Node)
                     orelse is_lambda_multi_body(Node)
                     orelse is_export_import_with_entries(Node));
        _    -> false
    end.


%% is_export_import_with_entries: true for export/import lists with at least one entry.
%% Empty (export) may stay flat; any entry forces a break.
-spec is_export_import_with_entries(lfmt_fezzik_cst:cst_node()) -> boolean().
is_export_import_with_entries(Node) ->
    case lfmt_fezzik_cst:children(Node) of
        [Head | Rest] when Rest =/= [] ->
            is_export_import_head(Head);
        _ ->
            false
    end.


%% is_always_break_head: true for list nodes headed by a form that must always
%% break (let/let*/case/cond/if/progn/receive/try/maybe/match-lambda).
-spec is_always_break_head(lfmt_fezzik_cst:cst_node()) -> boolean().
is_always_break_head(Node) ->
    case lfmt_fezzik_cst:children(Node) of
        [Head | _] ->
            case lfmt_fezzik_cst:type(Head) of
                symbol ->
                    Text = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
                    Text =:= "let"     orelse Text =:= "let*"
                    orelse Text =:= "case"    orelse Text =:= "cond"
                    orelse Text =:= "if"      orelse Text =:= "progn"
                    orelse Text =:= "receive" orelse Text =:= "try"
                    orelse Text =:= "maybe"   orelse Text =:= "match-lambda";
                _ -> false
            end;
        [] -> false
    end.


%% is_let_head: true when the head symbol is let or let*.
-spec is_let_head(lfmt_fezzik_cst:cst_node()) -> boolean().
is_let_head(Head) ->
    case lfmt_fezzik_cst:type(Head) of
        symbol ->
            Text = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
            Text =:= "let" orelse Text =:= "let*";
        _ -> false
    end.


%% is_flet_head: true when the head symbol is flet, flet*, or fletrec.
-spec is_flet_head(lfmt_fezzik_cst:cst_node()) -> boolean().
is_flet_head(Head) ->
    case lfmt_fezzik_cst:type(Head) of
        symbol ->
            Text = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
            Text =:= "flet" orelse Text =:= "flet*" orelse Text =:= "fletrec";
        _ -> false
    end.


%% local_fn_n: N for rendering a single flet/fletrec binding as a defun-like form.
%% Binding children = [name | rest].  N=1 when rest has an arglist as its first
%% element (signature form: name + arglist on head line); N=0 otherwise (match-
%% clause form: name on head line, clauses at +2).
-spec local_fn_n(lfmt_fezzik_cst:cst_node()) -> non_neg_integer().
local_fn_n(Binding) ->
    case lfmt_fezzik_cst:children(Binding) of
        [_Name, Arg2 | _] ->
            case is_arglist(Arg2) of
                true  -> 1;
                false -> 0
            end;
        _ -> 0
    end.


%% is_lambda_multi_body: true for (lambda arglist body1 body2 …) with >1 body form.
%% Children = [lambda-sym, arglist | body…]; body count > 1 forces a break so the
%% implicit progn is always written one-form-per-line (formatting-rules §3.2).
-spec is_lambda_multi_body(lfmt_fezzik_cst:cst_node()) -> boolean().
is_lambda_multi_body(Node) ->
    case lfmt_fezzik_cst:children(Node) of
        [Head, _Arglist | Body] ->
            length(Body) > 1
            andalso lfmt_fezzik_cst:type(Head) =:= symbol
            andalso lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)) =:= "lambda";
        _ -> false
    end.


%% is_clause_specform_head: true for specforms whose body children are clauses.
%% try case/catch sections are intentionally deferred to A7·S4.
-spec is_clause_specform_head(lfmt_fezzik_cst:cst_node(), non_neg_integer()) -> boolean().
is_clause_specform_head(Head, N) ->
    case lfmt_fezzik_cst:type(Head) of
        symbol ->
            Text = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
            Text =:= "case" orelse (Text =:= "match-lambda" andalso N =:= 0);
        _ ->
            false
    end.


%% is_defun_match_head: true for defun/defmacro routed through dynamic N=1.
-spec is_defun_match_head(lfmt_fezzik_cst:cst_node(), non_neg_integer()) -> boolean().
is_defun_match_head(Head, 1) ->
    case lfmt_fezzik_cst:type(Head) of
        symbol ->
            Text = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
            Text =:= "defun" orelse Text =:= "defmacro";
        _ ->
            false
    end;
is_defun_match_head(_Head, _N) ->
    false.


-spec is_receive_head(lfmt_fezzik_cst:cst_node()) -> boolean().
is_receive_head(Head) ->
    case lfmt_fezzik_cst:type(Head) of
        symbol ->
            lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)) =:= "receive";
        _ ->
            false
    end.


-spec is_try_head(lfmt_fezzik_cst:cst_node()) -> boolean().
is_try_head(Head) ->
    case lfmt_fezzik_cst:type(Head) of
        symbol ->
            lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)) =:= "try";
        _ ->
            false
    end.


-spec is_export_import_head(lfmt_fezzik_cst:cst_node()) -> boolean().
is_export_import_head(Head) ->
    case lfmt_fezzik_cst:type(Head) of
        symbol ->
            Text = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
            Text =:= "export" orelse Text =:= "import";
        _ ->
            false
    end.


%% is_export_entry: true for a 2-child list (symbol name, non-negative integer arity).
%% Used to decide whether to sort export entries.
-spec is_export_entry(lfmt_fezzik_cst:cst_node()) -> boolean().
is_export_entry(Node) ->
    case lfmt_fezzik_cst:type(Node) of
        list ->
            case lfmt_fezzik_cst:children(Node) of
                [Name, Arity] ->
                    lfmt_fezzik_cst:type(Name) =:= symbol
                    andalso lfmt_fezzik_cst:type(Arity) =:= number
                    andalso is_non_neg_integer_text(
                        lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Arity)));
                _ -> false
            end;
        _ -> false
    end.


-spec is_non_neg_integer_text(string()) -> boolean().
is_non_neg_integer_text([]) -> false;
is_non_neg_integer_text(Text) ->
    lists:all(fun(C) -> C >= $0 andalso C =< $9 end, Text).


%% sort_export_entries: stable sort by {name, arity} using keysort.
-spec sort_export_entries([lfmt_fezzik_cst:cst_node()]) ->
        [lfmt_fezzik_cst:cst_node()].
sort_export_entries(Entries) ->
    Tagged = [begin
                  [Name, Arity] = lfmt_fezzik_cst:children(E),
                  NameText = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Name)),
                  ArityInt = list_to_integer(
                      lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Arity))),
                  {{NameText, ArityInt}, E}
              end || E <- Entries],
    [E || {_, E} <- lists:keysort(1, Tagged)].


%% is_rename_entry: true for ((name arity) new-name) — a 2-child list whose first
%% child is itself a valid export entry (name arity).
-spec is_rename_entry(lfmt_fezzik_cst:cst_node()) -> boolean().
is_rename_entry(Node) ->
    case lfmt_fezzik_cst:type(Node) of
        list ->
            case lfmt_fezzik_cst:children(Node) of
                [OldPair | _] -> is_export_entry(OldPair);
                _             -> false
            end;
        _ -> false
    end.


%% sort_rename_entries: stable sort by old {name, arity} from the inner (name arity) pair.
-spec sort_rename_entries([lfmt_fezzik_cst:cst_node()]) -> [lfmt_fezzik_cst:cst_node()].
sort_rename_entries(Entries) ->
    Tagged = [begin
                  [OldPair | _] = lfmt_fezzik_cst:children(E),
                  [Name, Arity] = lfmt_fezzik_cst:children(OldPair),
                  NameText = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Name)),
                  ArityInt = list_to_integer(
                      lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Arity))),
                  {{NameText, ArityInt}, E}
              end || E <- Entries],
    [E || {_, E} <- lists:keysort(1, Tagged)].


%% sort_import_entries: sort from/rename clause entries; suppress when any entry
%% carries a leading comment (preserves developer ordering).
-spec sort_import_entries(string(), [lfmt_fezzik_cst:cst_node()]) ->
        [lfmt_fezzik_cst:cst_node()].
sort_import_entries("from", Entries) ->
    case lists:all(fun is_export_entry/1, Entries)
         andalso not lists:any(fun entry_has_comment/1, Entries) of
        true  -> sort_export_entries(Entries);
        false -> Entries
    end;
sort_import_entries("rename", Entries) ->
    case lists:all(fun is_rename_entry/1, Entries)
         andalso not lists:any(fun entry_has_comment/1, Entries) of
        true  -> sort_rename_entries(Entries);
        false -> Entries
    end;
sort_import_entries(_, Entries) ->
    Entries.


-spec is_after_section(lfmt_fezzik_cst:cst_node()) -> boolean().
is_after_section(Node) ->
    lfmt_fezzik_cst:type(Node) =:= list
    andalso case lfmt_fezzik_cst:children(Node) of
        [Head | _] ->
            lfmt_fezzik_cst:type(Head) =:= symbol
            andalso lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)) =:= "after";
        [] ->
            false
    end.


-spec all_clauses([lfmt_fezzik_cst:cst_node()]) -> boolean().
all_clauses(Children) ->
    lists:all(
        fun(Child) ->
            lfmt_fezzik_cst:type(Child) =:= list
            andalso lfmt_fezzik_cst:open(Child) =/= undefined
            andalso lfmt_fezzik_cst:close(Child) =/= undefined
        end, Children).


%%====================================================================
%% Internal: clause helpers (A7·S3b-1)
%%====================================================================

%% trivial_clause: a clause is trivial iff it has exactly two children
%% (pattern + a trivial datum) and carries no internal trivia. Trivial
%% clauses render flat; non-trivial clauses always break (pattern line +
%% body below via the list_head path). The clause's own trailing trivia
%% is handled by the parent loop and does not affect triviality.
-spec trivial_clause(lfmt_fezzik_cst:cst_node()) -> boolean().
trivial_clause(Node) ->
    lfmt_fezzik_cst:type(Node) =:= list
    andalso not has_clause_internal_trivia(Node)
    andalso case lfmt_fezzik_cst:children(Node) of
        [_Pattern, Datum] -> is_trivial_datum(Datum);
        _                 -> false
    end.


%% has_clause_internal_trivia: true when the clause itself has a leading comment
%% or dangling trivia, or any descendant has any trivia.
%% The clause's own trailing is excluded (handled externally).
-spec has_clause_internal_trivia(lfmt_fezzik_cst:cst_node()) -> boolean().
has_clause_internal_trivia(Node) ->
    has_comment_leading(lfmt_fezzik_cst:leading(Node))
    orelse lfmt_fezzik_cst:dangling(Node) =/= []
    orelse lists:any(fun has_descendant_trivia/1, lfmt_fezzik_cst:children(Node)).


%% is_trivial_datum: true for a leaf node (symbol/number/string/char) or a
%% prefixed node whose inner is such a leaf.
-spec is_trivial_datum(lfmt_fezzik_cst:cst_node()) -> boolean().
is_trivial_datum(Node) ->
    case lfmt_fezzik_cst:type(Node) of
        T when T =:= symbol; T =:= number; T =:= string; T =:= char -> true;
        prefixed ->
            case lfmt_fezzik_cst:children(Node) of
                [Inner] ->
                    case lfmt_fezzik_cst:type(Inner) of
                        T when T =:= symbol; T =:= number;
                               T =:= string; T =:= char -> true;
                        _ -> false
                    end;
                _ -> false
            end;
        _ -> false
    end.


%%====================================================================
%% Internal: defform helpers (A4·S2)
%%====================================================================

%% is_arglist: true for () and (x y z) but NOT for ((pat) body) match clauses.
%% A list whose first child is itself a list is a match clause, not an arglist.
-spec is_arglist(lfmt_fezzik_cst:cst_node()) -> boolean().
is_arglist(Node) ->
    lfmt_fezzik_cst:type(Node) =:= list
    andalso case lfmt_fezzik_cst:children(Node) of
                []          -> true;
                [First | _] -> lfmt_fezzik_cst:type(First) =/= list
            end.


%% is_force_break_defform: true for defform-headed lists that must always break.
%% Only defun/defmacro with an empty arglist (the constant idiom) are excluded
%% and allowed to be flat-if-fits.
-spec is_force_break_defform(lfmt_fezzik_cst:cst_node()) -> boolean().
is_force_break_defform(Node) ->
    case lfmt_fezzik_cst:children(Node) of
        [Head | RestChildren] ->
            case classify_head(Head) of
                defform ->
                    HeadText = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
                    IsDefunMacro = HeadText =:= "defun" orelse HeadText =:= "defmacro",
                    case IsDefunMacro of
                        true  -> not has_empty_arglist(RestChildren);
                        false -> true   %% defmodule, defrecord, etc. always break
                    end;
                _ -> false
            end;
        _ -> false
    end.


%% has_empty_arglist: true when RestChildren is [Name, Arg2 | _] and Arg2 is
%% an arglist with no children (the empty-arglist / constant idiom).
-spec has_empty_arglist([lfmt_fezzik_cst:cst_node()]) -> boolean().
has_empty_arglist([_Name, Arg2 | _]) ->
    is_arglist(Arg2) andalso lfmt_fezzik_cst:children(Arg2) =:= [];
has_empty_arglist(_) ->
    false.


%% defform_n: compute the number of distinguished args for a breaking defform.
%%   defun/defmacro + non-empty arglist as Arg2 → N=2 (signature form)
%%   defun/defmacro + match-clause Arg2 (or missing Arg2) → N=1
%%   any other defform → N=1 (name on head line, rest at C+2)
-spec defform_n(lfmt_fezzik_cst:cst_node(), [lfmt_fezzik_cst:cst_node()]) ->
          pos_integer().
defform_n(Head, RestChildren) ->
    HeadText = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
    case HeadText =:= "defun" orelse HeadText =:= "defmacro" of
        true ->
            case RestChildren of
                [_Name, Arg2 | _] ->
                    case is_arglist(Arg2) of
                        true  -> 2;   %% (defun name (args) body…)
                        false -> 1    %% (defun name ((pat) body)…) match clauses
                    end;
                _ -> 1
            end;
        false ->
            1   %% defmodule, defrecord, defstruct, …
    end.


%%====================================================================
%% Internal: head classification (A4)
%%====================================================================


%% classify_head: determines indentation class for a breaking list's head.
%% Algorithm (order matters — table wins over def-prefix):
%%   1. Head not a symbol   → list_head
%%   2. Head in specform table → {specform, N}
%%   3. Head starts with "def" and length > 3 → defform
%%   4. else → funcall
-spec classify_head(lfmt_fezzik_cst:cst_node()) -> head_class().
classify_head(Head) ->
    case lfmt_fezzik_cst:type(Head) of
        symbol ->
            Text = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
            case maps:find(Text, specform_table()) of
                {ok, N} -> {specform, N};
                error   ->
                    case length(Text) > 3 andalso lists:prefix("def", Text) of
                        true  -> defform;
                        false -> funcall
                    end
            end;
        _ ->
            list_head
    end.


%% specform_table: verbatim from lfe-indent.el; maps symbol text → N distinguished args.
%% Intentional extensions beyond lfe-indent.el (per Duncan's ruling):
%%   "export" => 0, "import" => 0 — keyword-alone style, items at C+OpenLen (+1), always-break.
%%   Other module-clause forms (behaviour, doc, …) could be added similarly.
%% Dialyzer infers a narrower key type ([1..255,...]) than string(); suppress.
-dialyzer({no_underspecs, specform_table/0}).
-spec specform_table() -> #{string() => non_neg_integer()}.
specform_table() ->
    #{
        ":"                 => 2,
        "after"             => 1,
        "bc"                => 1,
        "binary-comp"       => 1,
        "call"              => 2,
        "case"              => 1,
        "catch"             => 0,
        "define-function"   => 1,
        "define-macro"      => 1,
        "define-module"     => 1,
        "export"            => 0,
        "extend-module"     => 0,
        "import"            => 0,
        "do"                => 2,
        "else"              => 0,
        "eval-when-compile" => 0,
        "flet"              => 1,
        "flet*"             => 1,
        "fletrec"           => 1,
        "if"                => 1,
        "lambda"            => 1,
        "let"               => 1,
        "let*"              => 1,
        "let-function"      => 1,
        "letrec-function"   => 1,
        "let-macro"         => 1,
        "lc"                => 1,
        "list-comp"         => 1,
        "macrolet"          => 1,
        "match-lambda"      => 0,
        "match-spec"        => 0,
        "maybe"             => 0,
        "prog1"             => 1,
        "prog2"             => 2,
        "progn"             => 0,
        "receive"           => 0,
        "try"               => 0,
        "when"              => 0,
        "syntaxlet"         => 1,
        "defflavor"         => 3,
        "begin"             => 0,
        "let-syntax"        => 1,
        "syntax-rules"      => 0,
        "macro"             => 0
    }.


%% close_section: emit dangling then close, or close hugging last child.
%% Breaks close onto its own line at Indent (content indent) when:
%%   • Dangling is non-empty (existing rule), OR
%%   • LastHasTrail=true (last child had a trailing comment — fix1: a comment
%%     runs to end-of-line so the close must not follow it on the same line).
%% The close aligns with the preceding content/dangling lines (IndStr), never
%% de-indented to the form's open column C (A7·S4b).
-spec close_section([lfmt_fezzik_cst:trivia()], boolean(), non_neg_integer(),
                    non_neg_integer(), string(), non_neg_integer(), string(), string()) ->
          {iolist(), non_neg_integer()}.
close_section([], false, LastCol, _Indent, _IndStr, _C, _CIndStr, Close) ->
    {Close, LastCol + length(Close)};
close_section(Dangling, _HasTrail, _LastCol, Indent, IndStr, _C, _CIndStr, Close) ->
    DangIO = emit_dangling(Dangling, IndStr),
    {[DangIO, "\n", IndStr, Close], Indent + length(Close)}.


%%====================================================================
%% Internal: flat rendering (used when node passes flat check)
%%====================================================================

-spec flat_render(lfmt_fezzik_cst:cst_node()) -> iolist().
flat_render(Node) ->
    case lfmt_fezzik_cst:type(Node) of
        T when T =:= symbol; T =:= number; T =:= string; T =:= char ->
            lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Node));
        T when T =:= list; T =:= tuple; T =:= map; T =:= binary; T =:= eval ->
            Open  = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Node)),
            Close = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:close(Node)),
            case lfmt_fezzik_cst:children(Node) of
                [] -> [Open, Close];
                Children ->
                    case lfmt_fezzik_cst:dot_token(Node) of
                        undefined ->
                            [Open, lists:join(" ", [flat_render(C) || C <- Children]), Close];
                        DotTok ->
                            AllButLast = lists:droplast(Children),
                            Tail = lists:last(Children),
                            DotText = lfmt_fezzik_lexer:text(DotTok),
                            PreRendered = lists:join(" ", [flat_render(C) || C <- AllButLast]),
                            [Open, PreRendered, " ", DotText, " ", flat_render(Tail), Close]
                    end
            end;
        prefixed ->
            PfxText = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:prefix(Node)),
            [Inner]  = lfmt_fezzik_cst:children(Node),
            [PfxText | flat_render(Inner)]
    end.


%%====================================================================
%% Internal: flat-width calculation
%%====================================================================

-spec flat_width(lfmt_fezzik_cst:cst_node()) -> width().
flat_width(Node) ->
    case lfmt_fezzik_cst:type(Node) of
        T when T =:= symbol; T =:= number; T =:= string; T =:= char ->
            Tok = lfmt_fezzik_cst:open(Node),
            case lfmt_fezzik_lexer:kind(Tok) of
                K when K =:= tqstring; K =:= tqbstring -> infinity;
                _                                       ->
                    length(lfmt_fezzik_lexer:text(Tok))
            end;
        T when T =:= list; T =:= tuple; T =:= map; T =:= binary; T =:= eval ->
            %% must_break: defforms, maps, and let/let*/case/cond lists always break.
            case must_break(Node) of
                true -> infinity;
                false ->
                    OpenLen  = length(lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Node))),
                    CloseLen = length(lfmt_fezzik_lexer:text(lfmt_fezzik_cst:close(Node))),
                    Children = lfmt_fezzik_cst:children(Node),
                    DotTok   = lfmt_fezzik_cst:dot_token(Node),
                    case Children of
                        [] -> OpenLen + CloseLen;
                        _  ->
                            Widths = [flat_width(C) || C <- Children],
                            %% Dotted: " . " before tail adds 2 extra chars vs plain " ".
                            Spaces = case DotTok of
                                undefined -> length(Children) - 1;
                                _         -> length(Children) + 1
                            end,
                            add_widths(OpenLen + CloseLen + Spaces, sum_widths(Widths, 0))
                    end
            end;
        prefixed ->
            PfxLen  = length(lfmt_fezzik_lexer:text(lfmt_fezzik_cst:prefix(Node))),
            [Inner] = lfmt_fezzik_cst:children(Node),
            add_widths(PfxLen, flat_width(Inner))
    end.


-spec sum_widths([width()], non_neg_integer()) -> width().
sum_widths([], Acc)            -> Acc;
sum_widths([infinity | _], _)  -> infinity;
sum_widths([W | Rest], Acc)    -> sum_widths(Rest, Acc + W).


-spec add_widths(non_neg_integer(), width()) -> width().
add_widths(_, infinity) -> infinity;
add_widths(A, B)        -> A + B.


%%====================================================================
%% Internal: trivia emission helpers
%%====================================================================

%% emit_leading_trivia: emit leading trivia items at IndentStr.
%% DropFirstBlank=true suppresses the first blank (doc-start / after opener).
-spec emit_leading_trivia([lfmt_fezzik_cst:trivia()], string(), boolean()) -> iolist().
emit_leading_trivia([], _IndStr, _DropFirstBlank) ->
    [];
emit_leading_trivia([blank | Rest], IndStr, true) ->
    emit_leading_trivia(Rest, IndStr, false);
emit_leading_trivia([blank | Rest], IndStr, false) ->
    ["\n" | emit_leading_trivia(Rest, IndStr, false)];
emit_leading_trivia([{comment, Tok} | Rest], IndStr, _Drop) ->
    Text = lfmt_fezzik_lexer:text(Tok),
    [IndStr, Text, "\n" | emit_leading_trivia(Rest, IndStr, false)].


%% emit_head_leading: leading trivia for the head child, emitted before the opener.
%% Blanks are always dropped (head is on the opener line; no blank between leading
%% comments and the opener itself is unusual enough to discard in generic mode).
-spec emit_head_leading([lfmt_fezzik_cst:trivia()], string()) -> iolist().
emit_head_leading([], _CIndStr) ->
    [];
emit_head_leading([blank | Rest], CIndStr) ->
    emit_head_leading(Rest, CIndStr);
emit_head_leading([{comment, Tok} | Rest], CIndStr) ->
    Text = lfmt_fezzik_lexer:text(Tok),
    [CIndStr, Text, "\n" | emit_head_leading(Rest, CIndStr)].


%% emit_child_leading: leading trivia for a rest child at IndentStr.
%% IsFirst=true drops the first blank (no blank immediately after head line).
-spec emit_child_leading([lfmt_fezzik_cst:trivia()], string(), boolean()) -> iolist().
emit_child_leading(Leading, IndentStr, IsFirst) ->
    emit_leading_trivia(Leading, IndentStr, IsFirst).


%% emit_trailing: emit a trailing comment (if any) on the same line as the node.
-spec emit_trailing([lfmt_fezzik_cst:trivia()], non_neg_integer()) ->
          {iolist(), non_neg_integer()}.
emit_trailing([], Col) ->
    {[], Col};
emit_trailing([{comment, Tok}], Col) ->
    Text   = lfmt_fezzik_lexer:text(Tok),
    NewCol = col_after_text(Text, Col + 1),
    {[" ", Text], NewCol}.


%% emit_dangling: emit dangling trivia items, each on its own line at IndentStr.
%% The leading \n for each item is included (caller appends \nCIndStr+close after).
-spec emit_dangling([lfmt_fezzik_cst:trivia()], string()) -> iolist().
emit_dangling([], _IndStr) ->
    [];
emit_dangling([{comment, Tok} | Rest], IndStr) ->
    Text = lfmt_fezzik_lexer:text(Tok),
    ["\n", IndStr, Text | emit_dangling(Rest, IndStr)];
emit_dangling([blank | Rest], IndStr) ->
    ["\n" | emit_dangling(Rest, IndStr)].


%% emit_toplevel_dangling: trailing trivia after the last top-level form.
%% Blanks are dropped; comments are emitted at column 0.
-spec emit_toplevel_dangling([lfmt_fezzik_cst:trivia()]) -> iolist().
emit_toplevel_dangling([]) ->
    [];
emit_toplevel_dangling([blank | Rest]) ->
    emit_toplevel_dangling(Rest);
emit_toplevel_dangling([{comment, Tok} | Rest]) ->
    Text = lfmt_fezzik_lexer:text(Tok),
    [Text, "\n" | emit_toplevel_dangling(Rest)].


%%====================================================================
%% Internal: flat-eligibility helpers
%%====================================================================

%% has_internal_trivia: true if flat-rendering this node would silently drop trivia.
%% A node's own leading/trailing are emitted by the parent context (not by
%% flat_render), so they do not prevent flat mode. Only:
%%   • the node's own dangling (inside the container content)
%%   • any leading/trailing/dangling on any descendant
%% force breaking.
-spec has_internal_trivia(lfmt_fezzik_cst:cst_node()) -> boolean().
has_internal_trivia(Node) ->
    lfmt_fezzik_cst:dangling(Node) =/= []
    orelse lists:any(fun has_descendant_trivia/1, lfmt_fezzik_cst:children(Node)).


-spec has_descendant_trivia(lfmt_fezzik_cst:cst_node()) -> boolean().
has_descendant_trivia(Node) ->
    has_comment_leading(lfmt_fezzik_cst:leading(Node))
    orelse lfmt_fezzik_cst:trailing(Node) =/= []
    orelse lfmt_fezzik_cst:dangling(Node) =/= []
    orelse lists:any(fun has_descendant_trivia/1, lfmt_fezzik_cst:children(Node)).


%% Blank-only leading does not prevent flat rendering: blanks are always dropped
%% or collapsed in broken mode, so they never carry observable information.
%% Only a leading comment forces broken layout (otherwise it would be silently lost).
-spec has_comment_leading([lfmt_fezzik_cst:trivia()]) -> boolean().
has_comment_leading([])               -> false;
has_comment_leading([blank | Rest])   -> has_comment_leading(Rest);
has_comment_leading([{comment,_}|_])  -> true.


%% entry_has_comment: true when an entry node carries a leading OR trailing comment.
%% Used for sort suppression — any developer comment signals intentional ordering.
-spec entry_has_comment(lfmt_fezzik_cst:cst_node()) -> boolean().
entry_has_comment(E) ->
    has_comment_leading(lfmt_fezzik_cst:leading(E))
    orelse lfmt_fezzik_cst:trailing(E) =/= [].


%%====================================================================
%% Internal: column helpers
%%====================================================================

-spec col_after_text(string(), non_neg_integer()) -> non_neg_integer().
col_after_text([], Col)         -> Col;
col_after_text([$\n | Rest], _) -> col_after_text(Rest, 0);
col_after_text([_ | Rest], Col) -> col_after_text(Rest, Col + 1).
