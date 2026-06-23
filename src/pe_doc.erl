%%% @doc Builder and frozen term DAG for the Πₑ pretty printer.
%%%
%%% A document is a hash-consed DAG with inline, ordered, repeatable children.
%%% Construction goes through a threaded {@link builder()} that interns nodes
%%% (dedup by content) and assigns dense, bottom-up integer ids — children are
%%% interned before parents, so `child id < parent id' holds for free (a
%%% topological order with no `topsort'). {@link freeze/2} produces a read-only
%%% {@link dag()} backed by a tuple, so {@link get/2} is a single `element/2'.
%%%
%%% `flatten' is pre-expanded at build time into a choiceless `nl'->space
%%% rewrite (memoised, identity-preserving via hash-consing), so no `flatten'
%%% node survives `freeze'.
%%%
%%% This is the substrate the resolver folds over; it knows nothing about cost,
%%% measures, or LFE.
%%% @end
-module(pe_doc).

%% OTP28+ : -moduledoc/-doc attributes (backport slice strips or guards these).
-moduledoc "Builder and frozen term DAG for the Πₑ pretty printer.".

%% builder
-export([new/0, text/2, nl/1, concat/3, nest/3, align/2, choice/3, flatten/2]).
%% derived builder constructors
-export([group/2, vconcat/3]).
%% freeze + frozen read surface
-export([freeze/2, get/2, children/2, root/1, size/1]).

-export_type([builder/0, dag/0, id/0, payload/0]).

-type id() :: non_neg_integer().

-doc "A choiceless-or-choice node payload; children are ids, inline and ordered.".
-type payload() ::
    {text, binary(), Width :: non_neg_integer()}
    | nl
    | {concat, id(), id()}
    | {nest, non_neg_integer(), id()}
    | {align, id()}
    | {choice, id(), id()}.

-record(builder, {
    %% hash-cons: content -> id (dedup, preserves sharing). Off the hot path.
    rev = #{} :: #{payload() => id()},
    %% id -> payload, for O(1) reads during build (e.g. flatten).
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
%%% Builder
%%%-------------------------------------------------------------------

-doc "A fresh, empty builder.".
-spec new() -> builder().
new() -> #builder{}.

-doc "Intern a text node; display width (not byte size) is computed here.".
-spec text(binary(), builder()) -> {id(), builder()}.
text(Bin, B) when is_binary(Bin) ->
    intern({text, Bin, string:length(Bin)}, B).

-doc "Intern a newline node.".
-spec nl(builder()) -> {id(), builder()}.
nl(B) -> intern(nl, B).

-doc "Intern an unaligned concatenation; left and right are ordered and may be equal.".
-spec concat(id(), id(), builder()) -> {id(), builder()}.
concat(A, C, B) when is_integer(A), is_integer(C) ->
    intern({concat, A, C}, B).

-doc "Intern a relative indentation increase of `N'.".
-spec nest(non_neg_integer(), id(), builder()) -> {id(), builder()}.
nest(N, D, B) when is_integer(N), N >= 0, is_integer(D) ->
    intern({nest, N, D}, B).

-doc "Intern an alignment node (sets indentation to the current column).".
-spec align(id(), builder()) -> {id(), builder()}.
align(D, B) when is_integer(D) ->
    intern({align, D}, B).

-doc "Intern an arbitrary choice between two layouts.".
-spec choice(id(), id(), builder()) -> {id(), builder()}.
choice(A, C, B) when is_integer(A), is_integer(C) ->
    intern({choice, A, C}, B).

-doc """
Build-time `flatten': rewrite `D' replacing every `nl' with a single space,
distributing through `concat'/`nest'/`align'/`choice'. Memoised, and
identity-preserving — a subtree with no `nl' interns back to the same id.
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
flatten_payload(nl, B) ->
    text(<<" ">>, B);
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
payload_children({concat, A, B}) -> [A, B];
payload_children({nest, _, D}) -> [D];
payload_children({align, D}) -> [D];
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
