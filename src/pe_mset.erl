%%% @doc Measure sets and the merge that prunes them (paper Fig. 14).
%%%
%%% A measure set is either:
%%% <ul>
%%%   <li>`{set, [Measure]}' — a Pareto frontier, kept as a list ordered by cost
%%%       strictly ascending (equivalently last strictly descending), with no
%%%       measure dominating another; or</li>
%%%   <li>`{tainted, fun(() -> Measure)}' — a singleton fallback used when every
%%%       layout blows the computation-width limit `W'. The measure is held
%%%       behind a thunk so that resolving beyond `W' can be <em>delayed</em>
%%%       (Lemma 6.9): the thunk is forced only if the whole document is
%%%       tainted, which is what keeps the resolver's work bounded.</li>
%%% </ul>
%%%
%%% The representation is intentionally transparent: the resolver pattern-matches
%%% the two shapes on its hot path.
%%% @end
-module(pe_mset).

-moduledoc "Measure sets and the merge that prunes them (paper Fig. 14).".

-export([
    singleton/1,
    failed/0,
    tainted/1,
    tainted_lazy/1,
    is_tainted/1,
    merge/3,
    taint/1,
    lift/2,
    dedup/2,
    optimal/1
]).

-export_type([mset/0]).

-type measure() :: pe_measure:measure().

-doc """
A Pareto frontier of measures, a tainted (delayed) fallback measure, or
`failed' — the empty set, a document with no valid layout. `failed' mirrors
mjl's `MeasureSet::Failed' (measure.rs) and is the identity for {@link merge/3}.
""".
-type mset() :: {set, [measure(), ...]} | {tainted, fun(() -> measure())} | failed.

%%%-------------------------------------------------------------------
%%% Constructors
%%%-------------------------------------------------------------------

-doc "A singleton frontier from one measure.".
-spec singleton(measure()) -> mset().
singleton(M) -> {set, [M]}.

-doc "The empty/failed set — a document with no valid layout.".
-spec failed() -> mset().
failed() -> failed.

-doc "A tainted set wrapping an already-computed measure.".
-spec tainted(measure()) -> mset().
tainted(M) -> {tainted, fun() -> M end}.

-doc "A tainted set whose measure is delayed behind a thunk (resolving beyond `W').".
-spec tainted_lazy(fun(() -> measure())) -> mset().
tainted_lazy(Thunk) when is_function(Thunk, 0) -> {tainted, Thunk}.

-doc "Whether a measure set is tainted.".
-spec is_tainted(mset()) -> boolean().
is_tainted({tainted, _}) -> true;
is_tainted({set, _}) -> false;
is_tainted(failed) -> false.

%%%-------------------------------------------------------------------
%%% Operations
%%%-------------------------------------------------------------------

-doc """
Merge two measure sets (`⊎'), preferring a `Set' over a `Tainted' and, between
two `Tainted's, the left one. Merging two frontiers is a merge-sort-style pass
that prunes dominated measures as it goes.
""".
-spec merge(mset(), mset(), module()) -> mset().
merge(failed, Other, _CostMod) ->
    %% failed ⊎ X = X (mjl measure.rs: (Failed, other) => other). Must precede
    %% the tainted clause so `failed ⊎ tainted = tainted'.
    Other;
merge(This, failed, _CostMod) ->
    %% X ⊎ failed = X (mjl: (this, Failed) => this).
    This;
merge(S, {tainted, _}, _CostMod) ->
    %% S ⊎ Tainted = S (covers Set⊎Tainted and the left-biased Tainted⊎Tainted).
    S;
merge({tainted, _}, {set, _} = S, _CostMod) ->
    %% Tainted ⊎ Set = Set.
    S;
merge({set, A}, {set, B}, CostMod) ->
    {set, merge_frontiers(A, B, CostMod)}.

-doc "Taint a measure set: a `Tainted' is unchanged; a `Set' collapses to its least-cost head.".
-spec taint(mset()) -> mset().
taint(failed) -> failed;
taint({tainted, _} = S) -> S;
taint({set, [M0 | _]}) -> tainted(M0).

-doc "Apply `Fun' to every measure in the set (lazily through a `Tainted's thunk).".
-spec lift(mset(), fun((measure()) -> measure())) -> mset().
lift(failed, _Fun) -> failed;
lift({set, Ms}, Fun) -> {set, [Fun(M) || M <- Ms]};
lift({tainted, Thunk}, Fun) -> {tainted, fun() -> Fun(Thunk()) end}.

-doc """
The least-cost measure: the head of a frontier, or the forced tainted measure.
`failed' has no layout and raises — a top-level `failed' means the document is
unprintable (mjl returns its `Error' here).
""".
-spec optimal(mset()) -> measure().
optimal({set, [M0 | _]}) -> M0;
optimal({tainted, Thunk}) -> Thunk();
optimal(failed) -> error(no_valid_layout).

-doc """
Prune a list of measures that is ordered by last strictly descending and cost
non-strictly ascending into a Pareto frontier (drops dominated measures). Used
by the resolver after composing a left measure with a right frontier.
""".
-spec dedup([measure(), ...], module()) -> [measure(), ...].
dedup([M], _CostMod) ->
    [M];
dedup([M, M2 | Rest], CostMod) ->
    case pe_measure:dominates(M2, M, CostMod) of
        true -> dedup([M2 | Rest], CostMod);
        false -> [M | dedup([M2 | Rest], CostMod)]
    end.

%%%-------------------------------------------------------------------
%%% Internal
%%%-------------------------------------------------------------------

-spec merge_frontiers([measure()], [measure()], module()) -> [measure()].
merge_frontiers([], Ys, _CostMod) ->
    Ys;
merge_frontiers(Xs, [], _CostMod) ->
    Xs;
merge_frontiers([X | Xs] = L, [Y | Ys] = R, CostMod) ->
    case pe_measure:dominates(X, Y, CostMod) of
        true ->
            %% X dominates Y: drop Y.
            merge_frontiers(L, Ys, CostMod);
        false ->
            case pe_measure:dominates(Y, X, CostMod) of
                true ->
                    %% Y dominates X: drop X.
                    merge_frontiers(Xs, R, CostMod);
                false ->
                    %% Neither dominates: emit the larger-last first (cost ascending).
                    case pe_measure:last(X) > pe_measure:last(Y) of
                        true -> [X | merge_frontiers(Xs, R, CostMod)];
                        false -> [Y | merge_frontiers(L, Ys, CostMod)]
                    end
            end
    end.
