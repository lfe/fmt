%%% @doc Shared test helpers: a symbolic-document generator and a builder
%%% interpreter, used by the property tests and the brute-force oracle.
%%%
%%% A symbolic document is a plain term tree (no ids); {@link build_sym/2}
%%% realises it into a {@link pe_doc} builder. Keeping generation separate from
%%% the builder lets the same random tree drive both the resolver and the
%%% oracle.
-module(pe_gen).

-include_lib("proper/include/proper.hrl").

-export([doc_sym/0, doc_sym/1, build_sym/2]).
-export([widen/2, oracle_optimal/3]).

-export_type([sym/0]).

-type sym() ::
    {text, binary()}
    | nl
    | {concat, sym(), sym()}
    | {nest, non_neg_integer(), sym()}
    | {align, sym()}
    | {choice, sym(), sym()}
    | {group, sym()}
    | {vconcat, sym(), sym()}.

%%%-------------------------------------------------------------------
%%% Generators
%%%-------------------------------------------------------------------

-doc "A size-bounded symbolic document exercising every construct.".
-spec doc_sym() -> proper_types:type().
doc_sym() ->
    ?SIZED(Size, doc_sym(Size)).

-spec doc_sym(non_neg_integer()) -> proper_types:type().
doc_sym(0) ->
    leaf();
doc_sym(Size) ->
    Half = Size div 2,
    Smaller = Size - 1,
    frequency([
        {2, leaf()},
        {3, ?LAZY({concat, doc_sym(Half), doc_sym(Half)})},
        {2, ?LAZY({nest, range(0, 4), doc_sym(Smaller)})},
        {1, ?LAZY({align, doc_sym(Smaller)})},
        {3, ?LAZY({choice, doc_sym(Half), doc_sym(Half)})},
        {2, ?LAZY({group, doc_sym(Smaller)})},
        {2, ?LAZY({vconcat, doc_sym(Half), doc_sym(Half)})}
    ]).

leaf() ->
    oneof([{text, short_text()}, nl]).

%% Short ASCII text so layouts overflow modest widths and exercise choices.
short_text() ->
    ?LET(N, range(1, 5), list_to_binary(lists:duplicate(N, $x))).

%%%-------------------------------------------------------------------
%%% Builder interpreter
%%%-------------------------------------------------------------------

-doc "Realise a symbolic document into a builder, returning the root id.".
-spec build_sym(sym(), pe_doc:builder()) -> {pe_doc:id(), pe_doc:builder()}.
build_sym({text, Bin}, B) ->
    pe_doc:text(Bin, B);
build_sym(nl, B) ->
    pe_doc:nl(B);
build_sym({concat, A, C}, B0) ->
    {Ia, B1} = build_sym(A, B0),
    {Ic, B2} = build_sym(C, B1),
    pe_doc:concat(Ia, Ic, B2);
build_sym({nest, N, D}, B0) ->
    {Id, B1} = build_sym(D, B0),
    pe_doc:nest(N, Id, B1);
build_sym({align, D}, B0) ->
    {Id, B1} = build_sym(D, B0),
    pe_doc:align(Id, B1);
build_sym({choice, A, C}, B0) ->
    {Ia, B1} = build_sym(A, B0),
    {Ic, B2} = build_sym(C, B1),
    pe_doc:choice(Ia, Ic, B2);
build_sym({group, D}, B0) ->
    {Id, B1} = build_sym(D, B0),
    pe_doc:group(Id, B1);
build_sym({vconcat, A, C}, B0) ->
    {Ia, B1} = build_sym(A, B0),
    {Ic, B2} = build_sym(C, B1),
    pe_doc:vconcat(Ia, Ic, B2).

%%%-------------------------------------------------------------------
%%% Brute-force oracle (the correctness gate for the resolver)
%%%-------------------------------------------------------------------

-doc "Widen a DAG node into every choiceless document it can produce.".
-spec widen(pe_doc:dag(), pe_doc:id()) -> [pe_measure:cdoc(), ...].
widen(Dag, Id) ->
    widen_payload(pe_doc:get(Dag, Id), Dag).

widen_payload({text, S, _W}, _Dag) ->
    [{text, S}];
widen_payload(nl, _Dag) ->
    [nl];
widen_payload({concat, A, C}, Dag) ->
    [{concat, Da, Dc} || Da <- widen(Dag, A), Dc <- widen(Dag, C)];
widen_payload({nest, N, D}, Dag) ->
    [{nest, N, Dd} || Dd <- widen(Dag, D)];
widen_payload({align, D}, Dag) ->
    [{align, Dd} || Dd <- widen(Dag, D)];
widen_payload({choice, A, C}, Dag) ->
    widen(Dag, A) ++ widen(Dag, C).

-doc """
The optimal measure by brute force: widen the DAG into all choiceless documents,
measure each at `(0, 0)`, and keep the least-cost one. No taint — every layout
is considered — so the resolver must match this when its computation limit is
large enough to taint nothing.
""".
-spec oracle_optimal(pe_doc:dag(), module(), non_neg_integer()) -> pe_measure:measure().
oracle_optimal(Dag, CostMod, PageWidth) ->
    [First | Rest] = widen(Dag, pe_doc:root(Dag)),
    Measure = fun(Cdoc) -> pe_measure:measure_term(Cdoc, 0, 0, CostMod, PageWidth) end,
    lists:foldl(
        fun(Cdoc, Best) ->
            M = Measure(Cdoc),
            case CostMod:le(pe_measure:cost(M), pe_measure:cost(Best)) of
                true -> M;
                false -> Best
            end
        end,
        Measure(First),
        Rest
    ).
