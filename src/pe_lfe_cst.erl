%%% @doc A positioned, comment-bearing LFE reader (arc2/slice2b).
%%%
%%% A thin recursive-descent parser over {@link pe_lfe_scan} tokens, producing a
%%% **concrete syntax tree** (`cst()'): the parsed s-expression with, on every
%%% node, its source `pos' and its leading/trailing comment trivia. Trivia is
%%% bound by the **Roslyn following-token model**: a token's *trailing* trivia is
%%% the comments that follow it through end-of-line; everything else is *leading*
%%% trivia bound to the next token. A node's leading/trailing trivia come from
%%% its boundary tokens.
%%%
%%% `cst_to_sexpr/1' strips a `cst()' back to the bare Erlang s-expression — the
%%% exact term LFE's own reader (`lfe_io') produces, reader-constructors
%%% evaluated (`#(…)'→tuple, `#M(…)'→map, `#B(…)'→binary, `#''→`[function,…]').
%%% That equality is the AST differential (the 739 gate) against the slice1
%%% `lfe_io' reader. `src/' stays zero-dep; `lfe' is only the test oracle.
%%%
%%% This is additive — `pe_lfe' lowering and the engine are untouched. Rendering
%%% the captured comments is slice3.
%%% @end
-module(pe_lfe_cst).

-export([read/1, read_forms/1, cst_to_sexpr/1, comments/1, positions/1]).
-export([pos/1, lead/1, trail/1, children/1]).

-export_type([cst/0, comment/0]).

-record(cst, {
    sexpr :: term(),
    pos :: pe_lfe_scan:pos() | eof,
    lead = [] :: [comment()],
    trail = [] :: [comment()]
}).

-doc "A captured comment: kind, raw text, and source position.".
-type comment() :: {line | block, binary(), pe_lfe_scan:pos()}.

-doc "A concrete syntax tree node (see the module doc).".
-opaque cst() :: #cst{}.

%%%-------------------------------------------------------------------
%%% Public surface
%%%-------------------------------------------------------------------

-doc "Read a source binary into a list of top-level `cst()' forms.".
-spec read(binary()) -> [cst()].
read(Bin) ->
    {Annotated, EndComments} = attach_trivia(pe_lfe_scan:scan(Bin)),
    parse_forms(Annotated, EndComments).

-doc "Read into `{cst(), Line}' pairs (the top-level form's source line).".
-spec read_forms(binary()) -> [{cst(), pos_integer()}].
read_forms(Bin) ->
    [{C, element(1, C#cst.pos)} || C <- read(Bin)].

-doc "The node's source position.".
-spec pos(cst()) -> pe_lfe_scan:pos().
pos(#cst{pos = P}) -> P.

-doc "The node's leading comment trivia.".
-spec lead(cst()) -> [comment()].
lead(#cst{lead = L}) -> L.

-doc "The node's trailing comment trivia.".
-spec trail(cst()) -> [comment()].
trail(#cst{trail = T}) -> T.

-doc "The node's direct child `cst()' nodes (in source order).".
-spec children(cst()) -> [cst()].
children(#cst{sexpr = {quote, D}}) -> [D];
children(#cst{sexpr = {backquote, D}}) -> [D];
children(#cst{sexpr = {comma, D}}) -> [D];
children(#cst{sexpr = {'comma-at', D}}) -> [D];
children(#cst{sexpr = {list, Ds}}) -> Ds;
children(#cst{sexpr = {dotted, Ds, Tail}}) -> Ds ++ [Tail];
children(#cst{sexpr = {tuple, Ds}}) -> Ds;
children(#cst{sexpr = {map, Ds}}) -> Ds;
children(#cst{sexpr = {binary_ctor, Ds}}) -> Ds;
children(#cst{}) -> [].

-doc "Every comment in the tree, in source order (for the capture gate).".
-spec comments(cst() | [cst()]) -> [comment()].
comments(Csts) when is_list(Csts) ->
    lists:flatmap(fun comments/1, Csts);
comments(#cst{sexpr = S, lead = L, trail = T} = _C) ->
    L ++ child_comments(S) ++ T.

child_comments({quote, D}) -> comments(D);
child_comments({backquote, D}) -> comments(D);
child_comments({comma, D}) -> comments(D);
child_comments({'comma-at', D}) -> comments(D);
child_comments({list, Ds}) -> comments(Ds);
child_comments({dotted, Ds, Tail}) -> comments(Ds) ++ comments(Tail);
child_comments({tuple, Ds}) -> comments(Ds);
child_comments({map, Ds}) -> comments(Ds);
child_comments({binary_ctor, Ds}) -> comments(Ds);
child_comments(_Leaf) -> [].

-doc "Every node's position in the tree (for the every-node-position gate).".
-spec positions(cst() | [cst()]) -> [pe_lfe_scan:pos() | eof].
positions(Csts) when is_list(Csts) ->
    lists:flatmap(fun positions/1, Csts);
positions(#cst{sexpr = S, pos = P}) ->
    [P | child_positions(S)].

child_positions({quote, D}) -> positions(D);
child_positions({backquote, D}) -> positions(D);
child_positions({comma, D}) -> positions(D);
child_positions({'comma-at', D}) -> positions(D);
child_positions({list, Ds}) -> positions(Ds);
child_positions({dotted, Ds, Tail}) -> positions(Ds) ++ positions(Tail);
child_positions({tuple, Ds}) -> positions(Ds);
child_positions({map, Ds}) -> positions(Ds);
child_positions({binary_ctor, Ds}) -> positions(Ds);
child_positions(_Leaf) -> [].

%%%-------------------------------------------------------------------
%%% Roslyn trivia attachment — annotate each non-trivia token with its
%%% leading/trailing comments. Returns {[{Tok, Lead, Trail}], EndComments}
%%% where EndComments are trailing file comments with no following token.
%%%-------------------------------------------------------------------

attach_trivia(Tokens) ->
    {Lead, Rest} = split_comments(Tokens, []),
    attach(Rest, Lead, []).

attach([], Lead, Acc) ->
    {lists:reverse(Acc), Lead};
attach([Tok | Rest0], Lead, Acc) ->
    {Trail, Rest1} = take_trailing(Rest0, end_line(Tok), []),
    {NextLead, Rest2} = split_comments(Rest1, []),
    attach(Rest2, NextLead, [{Tok, Lead, Trail} | Acc]).

%% Leading comments: the run of comment tokens before the next value token.
split_comments([{comment, V, P} | Rest], Acc) ->
    split_comments(Rest, [{comment_kind(V), comment_text(V), P} | Acc]);
split_comments(Rest, Acc) ->
    {lists:reverse(Acc), Rest}.

%% Trailing comments: those on the same (end) line as the preceding token.
take_trailing([{comment, V, {CL, _} = P} | Rest], EndL, Acc) when CL =:= EndL ->
    take_trailing(Rest, EndL, [{comment_kind(V), comment_text(V), P} | Acc]);
take_trailing(Rest, _EndL, Acc) ->
    {lists:reverse(Acc), Rest}.

comment_kind({Kind, _Text}) -> Kind.
comment_text({_Kind, Text}) -> Text.

%% The line a token ends on (strings/binaries may span lines).
end_line({_Type, Val, {L, _C}}) -> L + value_newlines(Val).

value_newlines(Val) when is_list(Val) -> count_nl(Val, 0);
value_newlines(Val) when is_binary(Val) -> count_nl(binary_to_list(Val), 0);
value_newlines(_) -> 0.

count_nl([$\n | T], N) -> count_nl(T, N + 1);
count_nl([_ | T], N) -> count_nl(T, N);
count_nl([], N) -> N.

%%%-------------------------------------------------------------------
%%% Recursive-descent parser over annotated tokens
%%%-------------------------------------------------------------------

parse_forms(Toks, EndComments) ->
    attach_end(parse_all(Toks), EndComments).

parse_all([]) ->
    [];
parse_all(Toks) ->
    {Cst, Rest} = parse_datum(Toks),
    [Cst | parse_all(Rest)].

%% Trailing file comments (no following token): attach to the last form's trail
%% so the capture gate still sees them. A comments-only file (no forms) keeps
%% them on a `file_end' sentinel.
attach_end(Forms, []) ->
    Forms;
attach_end([], Comments) ->
    [#cst{sexpr = {file_end}, pos = eof, lead = Comments, trail = []}];
attach_end(Forms, Comments) ->
    {Init, [Last]} = lists:split(length(Forms) - 1, Forms),
    Init ++ [Last#cst{trail = Last#cst.trail ++ Comments}].

parse_datum([{Tok, Lead, Trail} | Rest]) ->
    parse_tok(Tok, Lead, Trail, Rest).

%% Leaves.
parse_tok({symbol, A, Pos}, Lead, Trail, Rest) ->
    {#cst{sexpr = {atom, A}, pos = Pos, lead = Lead, trail = Trail}, Rest};
parse_tok({number, N, Pos}, Lead, Trail, Rest) ->
    {#cst{sexpr = {number, N}, pos = Pos, lead = Lead, trail = Trail}, Rest};
parse_tok({string, Cps, Pos}, Lead, Trail, Rest) ->
    {#cst{sexpr = {string, Cps}, pos = Pos, lead = Lead, trail = Trail}, Rest};
parse_tok({binary, B, Pos}, Lead, Trail, Rest) ->
    {#cst{sexpr = {binary, B}, pos = Pos, lead = Lead, trail = Trail}, Rest};
parse_tok({'#\'', Field, Pos}, Lead, Trail, Rest) ->
    {#cst{sexpr = {funref, Field}, pos = Pos, lead = Lead, trail = Trail}, Rest};
%% Quote family — `lead' from the prefix token, `trail' from the quoted datum.
parse_tok({'\'', none, Pos}, Lead, _Trail, Rest) ->
    prefix(quote, Pos, Lead, Rest);
parse_tok({'`', none, Pos}, Lead, _Trail, Rest) ->
    prefix(backquote, Pos, Lead, Rest);
parse_tok({',', none, Pos}, Lead, _Trail, Rest) ->
    prefix(comma, Pos, Lead, Rest);
parse_tok({',@', none, Pos}, Lead, _Trail, Rest) ->
    prefix('comma-at', Pos, Lead, Rest);
%% Datum comment `#;' — comments out the following datum; the real value is the
%% datum after it. (Rare: 0 in the corpus; comments inside the skipped datum are
%% not separately captured.)
parse_tok({'#;', none, _Pos}, Lead, _Trail, Rest) ->
    {_Commented, Rest1} = parse_datum(Rest),
    {Real, Rest2} = parse_datum(Rest1),
    {Real#cst{lead = Lead ++ Real#cst.lead}, Rest2};
%% Aggregates. `OpenTrail' = comments trailing the open bracket on its line;
%% they lead the first element (or, for an empty aggregate, sit on the trail).
parse_tok({'(', none, Pos}, Lead, Trail, Rest) ->
    parse_list(Rest, Pos, Lead, Trail, ')');
parse_tok({'[', none, Pos}, Lead, Trail, Rest) ->
    parse_list(Rest, Pos, Lead, Trail, ']');
parse_tok({'#(', none, Pos}, Lead, Trail, Rest) ->
    parse_seq(Rest, Pos, Lead, Trail, tuple, ')');
parse_tok({'#M(', none, Pos}, Lead, Trail, Rest) ->
    parse_seq(Rest, Pos, Lead, Trail, map, ')');
parse_tok({'#B(', none, Pos}, Lead, Trail, Rest) ->
    parse_seq(Rest, Pos, Lead, Trail, binary_ctor, ')').

prefix(Kind, Pos, Lead, Rest) ->
    {Datum, Rest1} = parse_datum(Rest),
    {#cst{sexpr = {Kind, Datum}, pos = Pos, lead = Lead, trail = Datum#cst.trail}, Rest1}.

%% A `(' list: proper, or improper via `.'. `Close' is the matching close atom.
parse_list([{{Close, none, _}, CloseLead, Trail} | Rest], Pos, Lead, OpenTrail, Close) ->
    {
        #cst{sexpr = {list, []}, pos = Pos, lead = Lead, trail = OpenTrail ++ CloseLead ++ Trail},
        Rest
    };
parse_list(Toks, Pos, Lead, OpenTrail, Close) ->
    {Elem, Rest} = parse_datum(Toks),
    parse_list_items(Rest, Pos, Lead, Close, [absorb_lead(OpenTrail, Elem)]).

%% Interior comments just before `)' (`CloseLead', on their own lines) are
%% captured on the node's trail so no comment is lost.
parse_list_items([{{Close, none, _}, CloseLead, Trail} | Rest], Pos, Lead, Close, Acc) ->
    {
        #cst{
            sexpr = {list, lists:reverse(Acc)}, pos = Pos, lead = Lead, trail = CloseLead ++ Trail
        },
        Rest
    };
parse_list_items([{{'.', none, _}, _L, _T} | Rest0], Pos, Lead, Close, Acc) ->
    {Tail, Rest1} = parse_datum(Rest0),
    [{{Close, none, _}, CloseLead, Trail} | Rest2] = Rest1,
    {
        #cst{
            sexpr = {dotted, lists:reverse(Acc), Tail},
            pos = Pos,
            lead = Lead,
            trail = CloseLead ++ Trail
        },
        Rest2
    };
parse_list_items(Toks, Pos, Lead, Close, Acc) ->
    {Elem, Rest} = parse_datum(Toks),
    parse_list_items(Rest, Pos, Lead, Close, [Elem | Acc]).

%% A `#(' / `#M(' / `#B(' sequence up to `Close'.
parse_seq([{{Close, none, _}, CloseLead, Trail} | Rest], Pos, Lead, OpenTrail, Kind, Close) ->
    {
        #cst{sexpr = {Kind, []}, pos = Pos, lead = Lead, trail = OpenTrail ++ CloseLead ++ Trail},
        Rest
    };
parse_seq(Toks, Pos, Lead, OpenTrail, Kind, Close) ->
    {Elem, Rest} = parse_datum(Toks),
    parse_seq_items(Rest, Pos, Lead, Kind, Close, [absorb_lead(OpenTrail, Elem)]).

parse_seq_items([{{Close, none, _}, CloseLead, Trail} | Rest], Pos, Lead, Kind, Close, Acc) ->
    {
        #cst{
            sexpr = {Kind, lists:reverse(Acc)}, pos = Pos, lead = Lead, trail = CloseLead ++ Trail
        },
        Rest
    };
parse_seq_items(Toks, Pos, Lead, Kind, Close, Acc) ->
    {Elem, Rest} = parse_datum(Toks),
    parse_seq_items(Rest, Pos, Lead, Kind, Close, [Elem | Acc]).

absorb_lead([], Cst) -> Cst;
absorb_lead(Comments, #cst{lead = L} = Cst) -> Cst#cst{lead = Comments ++ L}.

%%%-------------------------------------------------------------------
%%% cst_to_sexpr — strip to the bare lfe_io-equivalent s-expression
%%%-------------------------------------------------------------------

-doc "Strip a `cst()' to the bare Erlang s-expression LFE's reader produces.".
-spec cst_to_sexpr(cst()) -> term().
cst_to_sexpr(#cst{sexpr = S}) -> sexpr(S).

sexpr({atom, A}) -> A;
sexpr({number, N}) -> N;
%% A string is the byte list `lfe_io' yields (the scanner gives codepoints; LFE
%% strings round-trip as their utf8 bytes).
sexpr({string, Cps}) -> binary_to_list(unicode:characters_to_binary(Cps, utf8));
sexpr({binary, B}) -> B;
sexpr({funref, Field}) -> funref_sexpr(Field);
sexpr({quote, D}) -> [quote, cst_to_sexpr(D)];
sexpr({backquote, D}) -> [backquote, cst_to_sexpr(D)];
sexpr({comma, D}) -> [comma, cst_to_sexpr(D)];
sexpr({'comma-at', D}) -> ['comma-at', cst_to_sexpr(D)];
sexpr({list, Ds}) -> [cst_to_sexpr(D) || D <- Ds];
sexpr({dotted, Ds, Tail}) -> dotted([cst_to_sexpr(D) || D <- Ds], cst_to_sexpr(Tail));
sexpr({tuple, Ds}) -> list_to_tuple([cst_to_sexpr(D) || D <- Ds]);
sexpr({map, Ds}) -> maps:from_list(pairs([cst_to_sexpr(D) || D <- Ds]));
sexpr({binary_ctor, Ds}) -> build_binary([cst_to_sexpr(D) || D <- Ds]).

dotted(Heads, Tail) -> Heads ++ Tail.

pairs([K, V | Rest]) -> [{K, V} | pairs(Rest)];
pairs([]) -> [].

%% `#'name/arity' reads as `[function, Name, Arity]', and the module-qualified
%% `#'mod:name/arity' as `[function, Mod, Name, Arity]'. Arity is after the last
%% `/'; a module is split at the *first* `:'. `=:=/2' is special-cased (its
%% colons are part of the operator name), exactly as LFE's `lfe_parse:make_fun'.
funref_sexpr("=:=/2") ->
    [function, '=:=', 2];
funref_sexpr(Field) ->
    [NamePart, ArityStr] = string:split(Field, "/", trailing),
    Arity = list_to_integer(ArityStr),
    case string:split(NamePart, ":") of
        [Mod, Name] -> [function, list_to_atom(Mod), list_to_atom(Name), Arity];
        [Name] -> [function, list_to_atom(Name), Arity]
    end.

%% Construct a `#B(…)' binary by evaluating its segments as `(binary …)' does:
%% a bare integer is an 8-bit byte, a string its bytes, and a `(Value float)'
%% segment a 64-bit IEEE float. (The corpus uses only these; richer bit specs
%% raise — slice-scoped, the AST differential would surface any miss.)
build_binary(Segs) ->
    iolist_to_binary([seg_bits(S) || S <- Segs]).

seg_bits(N) when is_integer(N) -> <<N:8>>;
seg_bits(L) when is_list(L) -> seg_string(L);
seg_bits([Value, float]) -> <<Value:64/float>>;
seg_bits([Value, integer]) -> <<Value:8>>;
seg_bits(Other) -> error({unsupported_bitseg, Other}).

%% A string segment is its bytes; a `(Value Spec…)' list is matched above. A list
%% of all-integers reaching here is a string; anything else is a spec list and
%% was matched by an earlier clause (or is unsupported).
seg_string(L) ->
    case lists:all(fun(C) -> is_integer(C) andalso C >= 0 andalso C =< 255 end, L) of
        true -> list_to_binary(L);
        false -> seg_bits_spec(L)
    end.

seg_bits_spec([Value, float]) -> <<Value:64/float>>;
seg_bits_spec([Value, integer]) -> <<Value:8>>;
seg_bits_spec(Other) -> error({unsupported_bitseg, Other}).
