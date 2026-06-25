%%% @doc Builder and frozen term DAG for the Πₑ pretty printer.
%%%
%%% A document is a hash-consed DAG with inline, ordered, repeatable children.
%%% Construction goes through a threaded {@link builder()} that interns nodes
%%% (dedup by content) and assigns dense, bottom-up integer ids — children are
%%% interned before parents, so `child id < parent id' holds for free (a
%%% topological order with no `topsort'). {@link freeze/2} produces a read-only
%%% {@link dag()} backed by a tuple, so {@link get/2} is a single `element/2'.
%%%
%%% The document algebra mirrors mjl's `pretty-expressive` (`lib.rs'):
%%% `text/nl/brk/hard_nl/fail/concat/nest/align/reset/cost/choice', with mjl's
%%% smart-constructor normalisation applied at build time (`fail' propagation,
%%% empty-text elimination, adjacent-text merge, cost push-out, and the
%%% `fail|align|reset|text' short-circuits on nest/align/reset). Newlines are
%%% three distinct nodes by their flatten target — `nl' -> `" "', `brk' -> `""',
%%% `hard_nl' -> fail — rather than mjl's `Newline(Option<String>)'; the
%%% behaviour is identical and it keeps the rest of the engine's `nl' matches
%%% intact.
%%%
%%% `flatten' is pre-expanded at build time into a choiceless rewrite (memoised,
%%% identity-preserving via hash-consing), so no `flatten' node survives
%%% `freeze'.
%%%
%%% This is the substrate the resolver folds over; it knows nothing about
%%% measures or LFE. A `cost' node carries an opaque cost value (the active
%%% `pe_cost' module's representation); pe_doc only stores it.
%%% @end
-module(pe_doc).

%% OTP28+ : -moduledoc/-doc attributes (backport slice strips or guards these).
-moduledoc "Builder and frozen term DAG for the Πₑ pretty printer.".

%% builder — core algebra
-export([new/0, text/2, nl/1, brk/1, hard_nl/1, fail/1]).
-export([concat/3, nest/3, align/2, reset/2, cost/3, choice/3, flatten/2]).
%% derived builder constructors
-export([group/2, vconcat/3]).
%% freeze + frozen read surface
-export([freeze/2, get/2, children/2, root/1, size/1]).

-export_type([builder/0, dag/0, id/0, payload/0, cost_value/0]).

-type id() :: non_neg_integer().

-doc "An opaque cost value carried by a `cost' node (the cost module's representation).".
-type cost_value() :: term().

-doc "A node payload; children are ids, inline and ordered.".
-type payload() ::
    {text, binary(), Width :: non_neg_integer()}
    | nl
    | brk
    | hard_nl
    | fail
    | {concat, id(), id()}
    | {nest, non_neg_integer(), id()}
    | {align, id()}
    | {reset, id()}
    | {cost, cost_value(), id()}
    | {choice, id(), id()}.

-record(builder, {
    %% hash-cons: content -> id (dedup, preserves sharing). Off the hot path.
    rev = #{} :: #{payload() => id()},
    %% id -> payload, for O(1) reads during build (e.g. flatten, smart-ctors).
    fwd = #{} :: #{id() => payload()},
    %% next id to assign.
    next = 0 :: non_neg_integer(),
    %% flatten memo: id -> flattened id (each node flattened at most once).
    flat = #{} :: #{id() => id()}
}).

-record(dag, {
    nodes :: tuple(),
    root :: id(),
    size :: pos_integer()
}).

-opaque builder() :: #builder{}.
-opaque dag() :: #dag{}.

%%%-------------------------------------------------------------------
%%% Builder — leaves
%%%-------------------------------------------------------------------

-doc "A fresh, empty builder.".
-spec new() -> builder().
new() -> #builder{}.

-doc "Intern a text node; display width (not byte size) is computed here.".
-spec text(binary(), builder()) -> {id(), builder()}.
text(Bin, B) when is_binary(Bin) ->
    intern({text, Bin, string:length(Bin)}, B).

-doc "A newline that flattens to a single space.".
-spec nl(builder()) -> {id(), builder()}.
nl(B) -> intern(nl, B).

-doc "A newline that flattens to the empty string (mjl `brk').".
-spec brk(builder()) -> {id(), builder()}.
brk(B) -> intern(brk, B).

-doc "A newline that fails to flatten (mjl `hard_nl').".
-spec hard_nl(builder()) -> {id(), builder()}.
hard_nl(B) -> intern(hard_nl, B).

-doc "A document with no valid layout (mjl `fail').".
-spec fail(builder()) -> {id(), builder()}.
fail(B) -> intern(fail, B).

%%%-------------------------------------------------------------------
%%% Builder — combinators (with mjl smart-constructor normalisation)
%%%-------------------------------------------------------------------

-doc "Unaligned concatenation; ordered, may repeat. mjl `BitAnd' peepholes apply.".
-spec concat(id(), id(), builder()) -> {id(), builder()}.
concat(A, C, B) when is_integer(A), is_integer(C) ->
    concat_smart(A, C, get_payload(A, B), get_payload(C, B), B).

%% mjl lib.rs `bitand' arm order: Fail, Text0-left, Text0-right, (Full,Text)
%% [slice8b], Text+Text merge, Cost push-out (right then left), default Concat.
concat_smart(A, _C, fail, _PC, B) ->
    {A, B};
concat_smart(_A, C, _PA, fail, B) ->
    {C, B};
concat_smart(_A, C, {text, _, 0}, _PC, B) ->
    {C, B};
concat_smart(A, _C, _PA, {text, _, 0}, B) ->
    {A, B};
concat_smart(_A, _C, {text, S1, _}, {text, S2, _}, B) ->
    text(<<S1/binary, S2/binary>>, B);
concat_smart(A, _C, _PA, {cost, Cv, D2}, B) ->
    {Inner, B1} = concat(A, D2, B),
    cost(Cv, Inner, B1);
concat_smart(_A, C, {cost, Cv, D1}, _PC, B) ->
    {Inner, B1} = concat(D1, C, B),
    cost(Cv, Inner, B1);
concat_smart(A, C, _PA, _PC, B) ->
    intern({concat, A, C}, B).

-doc "Arbitrary choice. mjl `BitOr': `(fail,_)=>rhs', `(_,fail)=>self'.".
-spec choice(id(), id(), builder()) -> {id(), builder()}.
choice(A, C, B) when is_integer(A), is_integer(C) ->
    case get_payload(A, B) of
        fail ->
            {C, B};
        _ ->
            case get_payload(C, B) of
                fail -> {A, B};
                _ -> intern({choice, A, C}, B)
            end
    end.

%% nest/align/reset share mjl's short-circuit: a fail/align/reset/text child is
%% returned unchanged (indentation has no effect on it — text has no newline,
%% align/reset override indentation), and a cost child is pushed outward.

-doc "Relative indentation increase of `N'. mjl `nest' short-circuits apply.".
-spec nest(non_neg_integer(), id(), builder()) -> {id(), builder()}.
nest(N, D, B) when is_integer(N), N >= 0, is_integer(D) ->
    case get_payload(D, B) of
        fail ->
            {D, B};
        {align, _} ->
            {D, B};
        {reset, _} ->
            {D, B};
        {text, _, _} ->
            {D, B};
        {cost, Cv, D2} ->
            {Inner, B1} = nest(N, D2, B),
            cost(Cv, Inner, B1);
        _ ->
            intern({nest, N, D}, B)
    end.

-doc "Alignment: set indentation to the current column. mjl `align' short-circuits.".
-spec align(id(), builder()) -> {id(), builder()}.
align(D, B) when is_integer(D) ->
    case get_payload(D, B) of
        fail ->
            {D, B};
        {align, _} ->
            {D, B};
        {reset, _} ->
            {D, B};
        {text, _, _} ->
            {D, B};
        {cost, Cv, D2} ->
            {Inner, B1} = align(D2, B),
            cost(Cv, Inner, B1);
        _ ->
            intern({align, D}, B)
    end.

-doc "Reset indentation to 0 (mjl `reset'). Same short-circuits as `align'.".
-spec reset(id(), builder()) -> {id(), builder()}.
reset(D, B) when is_integer(D) ->
    case get_payload(D, B) of
        fail ->
            {D, B};
        {align, _} ->
            {D, B};
        {reset, _} ->
            {D, B};
        {text, _, _} ->
            {D, B};
        {cost, Cv, D2} ->
            {Inner, B1} = reset(D2, B),
            cost(Cv, Inner, B1);
        _ ->
            intern({reset, D}, B)
    end.

-doc """
Inject an explicit cost into a document (mjl `cost'). `cost(c, fail) = fail';
otherwise wrap. The cost value is opaque to pe_doc — it is the active `pe_cost'
module's representation, combined into each measure by the resolver.
""".
-spec cost(cost_value(), id(), builder()) -> {id(), builder()}.
cost(Cv, D, B) when is_integer(D) ->
    case get_payload(D, B) of
        fail -> {D, B};
        _ -> intern({cost, Cv, D}, B)
    end.

%%%-------------------------------------------------------------------
%%% Build-time flatten
%%%-------------------------------------------------------------------

-doc """
Build-time `flatten': rewrite `D' replacing each newline with its flatten target
(`nl'->`" "', `brk'->`""', `hard_nl'->fail), distributing through the
combinators. Memoised and identity-preserving — a subtree that does not change
interns back to the same id. Reconstruction goes through the smart constructors,
so e.g. `flatten(concat(text, hard_nl)) = fail'.
""".
-spec flatten(id(), builder()) -> {id(), builder()}.
flatten(D, #builder{flat = Flat} = B) when is_integer(D) ->
    case Flat of
        #{D := FlatId} ->
            {FlatId, B};
        _ ->
            {FlatId, B1} = flatten_payload(get_payload(D, B), B),
            {FlatId, B1#builder{flat = (B1#builder.flat)#{D => FlatId}}}
    end.

-spec flatten_payload(payload(), builder()) -> {id(), builder()}.
flatten_payload({text, _, _} = P, B) ->
    intern(P, B);
flatten_payload(fail, B) ->
    intern(fail, B);
flatten_payload(nl, B) ->
    text(<<" ">>, B);
flatten_payload(brk, B) ->
    text(<<>>, B);
flatten_payload(hard_nl, B) ->
    fail(B);
flatten_payload({concat, A, C}, B0) ->
    {FA, B1} = flatten(A, B0),
    {FC, B2} = flatten(C, B1),
    concat(FA, FC, B2);
flatten_payload({nest, N, D}, B0) ->
    {FD, B1} = flatten(D, B0),
    nest(N, FD, B1);
flatten_payload({align, D}, B0) ->
    {FD, B1} = flatten(D, B0),
    align(FD, B1);
flatten_payload({reset, D}, B0) ->
    {FD, B1} = flatten(D, B0),
    reset(FD, B1);
flatten_payload({cost, Cv, D}, B0) ->
    {FD, B1} = flatten(D, B0),
    cost(Cv, FD, B1);
flatten_payload({choice, A, C}, B0) ->
    {FA, B1} = flatten(A, B0),
    {FC, B2} = flatten(C, B1),
    choice(FA, FC, B2).

-doc "Derived: `group(D) = choice(flatten(D), D)' — prefer the flat layout on ties.".
-spec group(id(), builder()) -> {id(), builder()}.
group(D, B0) ->
    {FD, B1} = flatten(D, B0),
    choice(FD, D, B1).

-doc "Derived: `vconcat(A, C) = concat(A, concat(nl, C))' — vertical concatenation.".
-spec vconcat(id(), id(), builder()) -> {id(), builder()}.
vconcat(A, C, B0) ->
    {Nl, B1} = nl(B0),
    {Rhs, B2} = concat(Nl, C, B1),
    concat(A, Rhs, B2).

%%%-------------------------------------------------------------------
%%% Freeze + frozen read surface
%%%-------------------------------------------------------------------

-doc "Freeze the builder into a read-only DAG rooted at `Root'.".
-spec freeze(builder(), id()) -> dag().
freeze(#builder{fwd = Fwd, next = N}, Root) when is_integer(Root), Root < N ->
    Nodes = list_to_tuple([maps:get(I, Fwd) || I <- lists:seq(0, N - 1)]),
    #dag{nodes = Nodes, root = Root, size = N}.

-doc "Read a node payload by id — O(1) via `element/2'.".
-spec get(dag(), id()) -> payload().
get(#dag{nodes = Nodes}, Id) ->
    element(Id + 1, Nodes).

-doc "Ordered child ids of a node (may repeat, e.g. `concat(D, D)' -> `[D, D]').".
-spec children(dag(), id()) -> [id()].
children(Dag, Id) ->
    payload_children(get(Dag, Id)).

-spec payload_children(payload()) -> [id()].
payload_children({text, _, _}) -> [];
payload_children(nl) -> [];
payload_children(brk) -> [];
payload_children(hard_nl) -> [];
payload_children(fail) -> [];
payload_children({concat, A, B}) -> [A, B];
payload_children({nest, _, D}) -> [D];
payload_children({align, D}) -> [D];
payload_children({reset, D}) -> [D];
payload_children({cost, _, D}) -> [D];
payload_children({choice, A, B}) -> [A, B].

-doc "The root id of the DAG.".
-spec root(dag()) -> id().
root(#dag{root = Root}) -> Root.

-doc "The number of interned nodes.".
-spec size(dag()) -> pos_integer().
size(#dag{size = N}) -> N.

%%%-------------------------------------------------------------------
%%% Internal
%%%-------------------------------------------------------------------

%% Hash-cons: return the existing id for equal content, else assign a fresh
%% dense id. Children are already interned, so the new id exceeds them.
-spec intern(payload(), builder()) -> {id(), builder()}.
intern(P, #builder{rev = Rev} = B) ->
    case Rev of
        #{P := Id} ->
            {Id, B};
        _ ->
            Id = B#builder.next,
            {Id, B#builder{
                rev = Rev#{P => Id},
                fwd = (B#builder.fwd)#{Id => P},
                next = Id + 1
            }}
    end.

-spec get_payload(id(), builder()) -> payload().
get_payload(Id, #builder{fwd = Fwd}) ->
    maps:get(Id, Fwd).
