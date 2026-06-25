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
-export([widen_sym/1, oracle_optimal_sym/3]).

-export_type([sym/0]).

-type sym() ::
    {text, binary()}
    | nl
    | brk
    | hard_nl
    | fail
    | {concat, sym(), sym()}
    | {nest, non_neg_integer(), sym()}
    | {align, sym()}
    | {reset, sym()}
    | {cost, pe_doc:cost_value(), sym()}
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
        {3, leaf()},
        {3, ?LAZY({concat, doc_sym(Half), doc_sym(Half)})},
        {2, ?LAZY({nest, range(0, 4), doc_sym(Smaller)})},
        {1, ?LAZY({align, doc_sym(Smaller)})},
        {1, ?LAZY({reset, doc_sym(Smaller)})},
        {1, ?LAZY({cost, cost_value(), doc_sym(Smaller)})},
        {3, ?LAZY({choice, doc_sym(Half), doc_sym(Half)})},
        {2, ?LAZY({group, doc_sym(Smaller)})},
        {2, ?LAZY({vconcat, doc_sym(Half), doc_sym(Half)})}
    ]).

%% `fail' is generated rarely and weighted toward choice/concat where it is
%% either eliminated (`choice(fail, d) = d') or propagated — so most documents
%% keep at least one valid layout.
leaf() ->
    frequency([
        {6, {text, short_text()}},
        {4, nl},
        {2, brk},
        {2, hard_nl},
        {1, fail}
    ]).

%% A {Badness, Height} cost value in pe_cost_squared's representation.
cost_value() ->
    {range(0, 3), range(0, 2)}.

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
build_sym(brk, B) ->
    pe_doc:brk(B);
build_sym(hard_nl, B) ->
    pe_doc:hard_nl(B);
build_sym(fail, B) ->
    pe_doc:fail(B);
build_sym({reset, D}, B0) ->
    {Id, B1} = build_sym(D, B0),
    pe_doc:reset(Id, B1);
build_sym({cost, Cv, D}, B0) ->
    {Id, B1} = build_sym(D, B0),
    pe_doc:cost(Cv, Id, B1);
build_sym({flatten, D}, B0) ->
    {Id, B1} = build_sym(D, B0),
    pe_doc:flatten(Id, B1);
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
%% brk/hard_nl render as a real newline when not flattened (the flatten target
%% was already consumed at build time), so they widen to the same `nl' CDoc.
widen_payload(brk, _Dag) ->
    [nl];
widen_payload(hard_nl, _Dag) ->
    [nl];
%% fail has no valid layout — it contributes no choiceless documents, so any
%% concat/nest/etc. that reaches it widens to the empty set.
widen_payload(fail, _Dag) ->
    [];
widen_payload({concat, A, C}, Dag) ->
    [{concat, Da, Dc} || Da <- widen(Dag, A), Dc <- widen(Dag, C)];
widen_payload({nest, N, D}, Dag) ->
    [{nest, N, Dd} || Dd <- widen(Dag, D)];
widen_payload({align, D}, Dag) ->
    [{align, Dd} || Dd <- widen(Dag, D)];
widen_payload({reset, D}, Dag) ->
    [{reset, Dd} || Dd <- widen(Dag, D)];
widen_payload({cost, Cv, D}, Dag) ->
    [{cost, Cv, Dd} || Dd <- widen(Dag, D)];
widen_payload({choice, A, C}, Dag) ->
    widen(Dag, A) ++ widen(Dag, C).

-doc """
The optimal measure by brute force: widen the DAG into all choiceless documents,
measure each at `(0, 0)`, and keep the least-cost one. No taint — every layout
is considered — so the resolver must match this when its computation limit is
large enough to taint nothing. Returns `failed' when the document has no valid
layout (every path widens to nothing), mirroring the resolver's failed set.
""".
-spec oracle_optimal(pe_doc:dag(), module(), non_neg_integer()) ->
    failed | pe_measure:measure().
oracle_optimal(Dag, CostMod, PageWidth) ->
    case widen(Dag, pe_doc:root(Dag)) of
        [] -> failed;
        Layouts -> oracle_min(Layouts, CostMod, PageWidth)
    end.

oracle_min([First | Rest], CostMod, PageWidth) ->
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

%%%-------------------------------------------------------------------
%%% Symbolic oracle (the transparent-peephole gate, A1S8-8)
%%%
%%% `widen/2' reads the FROZEN dag, which has already been through pe_doc's
%%% smart constructors — so it cannot witness a peephole that silently changed
%%% meaning. `widen_sym/1' widens the SYMBOLIC tree directly, never building a
%%% dag and never touching a smart constructor, giving an independent reference:
%%% if a transparent peephole perturbed output or cost, the resolver (which uses
%%% the peepholed dag) would disagree with this oracle.
%%%-------------------------------------------------------------------

-doc "Widen a symbolic document into every choiceless cdoc it can produce.".
-spec widen_sym(sym()) -> [pe_measure:cdoc()].
widen_sym({text, _} = T) -> [T];
widen_sym(nl) -> [nl];
widen_sym(brk) -> [nl];
widen_sym(hard_nl) -> [nl];
widen_sym(fail) -> [];
widen_sym({concat, A, C}) -> [{concat, Da, Dc} || Da <- widen_sym(A), Dc <- widen_sym(C)];
widen_sym({nest, N, D}) -> [{nest, N, Dd} || Dd <- widen_sym(D)];
widen_sym({align, D}) -> [{align, Dd} || Dd <- widen_sym(D)];
widen_sym({reset, D}) -> [{reset, Dd} || Dd <- widen_sym(D)];
widen_sym({cost, Cv, D}) -> [{cost, Cv, Dd} || Dd <- widen_sym(D)];
widen_sym({choice, A, C}) -> widen_sym(A) ++ widen_sym(C);
widen_sym({group, D}) -> widen_sym(flatten_sym(D)) ++ widen_sym(D);
widen_sym({vconcat, A, C}) -> widen_sym({concat, A, {concat, nl, C}}).

%% Symbolic flatten, mirroring pe_doc:flatten_payload/2 on the sym tree: each
%% newline becomes its flatten target (`nl'->`" "', `brk'->`""', `hard_nl'->
%% fail), distributed through the combinators; `flatten(group(d)) = flatten(d)'.
-spec flatten_sym(sym()) -> sym().
flatten_sym({text, _} = T) -> T;
flatten_sym(nl) -> {text, <<" ">>};
flatten_sym(brk) -> {text, <<>>};
flatten_sym(hard_nl) -> fail;
flatten_sym(fail) -> fail;
flatten_sym({concat, A, C}) -> {concat, flatten_sym(A), flatten_sym(C)};
flatten_sym({nest, N, D}) -> {nest, N, flatten_sym(D)};
flatten_sym({align, D}) -> {align, flatten_sym(D)};
flatten_sym({reset, D}) -> {reset, flatten_sym(D)};
flatten_sym({cost, Cv, D}) -> {cost, Cv, flatten_sym(D)};
flatten_sym({choice, A, C}) -> {choice, flatten_sym(A), flatten_sym(C)};
flatten_sym({group, D}) -> flatten_sym(D);
flatten_sym({vconcat, A, C}) -> flatten_sym({concat, A, {concat, nl, C}}).

-doc "The brute-force optimum of a symbolic document (peephole-free reference).".
-spec oracle_optimal_sym(sym(), module(), non_neg_integer()) ->
    failed | pe_measure:measure().
oracle_optimal_sym(Sym, CostMod, PageWidth) ->
    case widen_sym(Sym) of
        [] -> failed;
        Layouts -> oracle_min(Layouts, CostMod, PageWidth)
    end.
