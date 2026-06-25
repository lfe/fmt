%%% @doc Measures and the operations on them (paper Figs. 12–13).
%%%
%%% A measure is `{Last, Cost, CDoc}': the length of the layout's last line, its
%%% cost under a factory, and the choiceless document that produced it (kept so
%%% the winner can be rendered/inspected later). The paper's ghost fields
%%% `maxx'/`maxy' are omitted — they exist only for the correctness proof.
%%%
%%% `measure_term/5' is the direct measure computation `⇓M' (Fig. 13) over a
%%% choiceless document term; the brute-force oracle uses it, and the resolver
%%% builds the same measures compositionally from {@link text_leaf/5} /
%%% {@link nl_leaf/3} via {@link compose/3} and the `adjust_*' wrappers.
%%%
%%% Note on arities: `compose'/`dominates' take the cost module (they use the
%%% factory's `combine'/`le'), and `measure_term' additionally takes the page
%%% width — the factory needs it to compute overflow, and the engine threads it
%%% separately from the cost module. This refines the prompt's sketched
%%% `compose/2'/`dominates/2'/`measure_term/4'.
%%% @end
-module(pe_measure).

-moduledoc "Measures and operations on them (paper Figs. 12–13).".

-export([
    text_leaf/5,
    nl_leaf/3,
    compose/3,
    adjust_nest/2,
    adjust_align/2,
    adjust_reset/1,
    add_cost/3,
    dominates/3,
    measure_term/5,
    last/1,
    cost/1,
    doc/1
]).

-export_type([measure/0, cdoc/0]).

-doc """
A choiceless document term carried inside a measure. `{reset, _}' renders its
child at indentation 0; a `cost' node leaves no trace in the layout, so it is
not represented here (the resolver folds the injected cost into the measure's
cost and keeps the inner document).
""".
-type cdoc() ::
    {text, binary()}
    | nl
    | {concat, cdoc(), cdoc()}
    | {nest, non_neg_integer(), cdoc()}
    | {align, cdoc()}
    | {reset, cdoc()}
    | {cost, pe_doc:cost_value(), cdoc()}.

-doc "`{Last, Cost, CDoc}': last-line length, cost, and the choiceless document.".
-type measure() :: {non_neg_integer(), pe_cost:cost(), cdoc()}.

%%%-------------------------------------------------------------------
%%% Accessors
%%%-------------------------------------------------------------------

-doc "The length of the last line of this measure's layout.".
-spec last(measure()) -> non_neg_integer().
last({Last, _Cost, _Doc}) -> Last.

-doc "The cost of this measure's layout.".
-spec cost(measure()) -> pe_cost:cost().
cost({_Last, Cost, _Doc}) -> Cost.

-doc "The choiceless document that produced this measure.".
-spec doc(measure()) -> cdoc().
doc({_Last, _Cost, Doc}) -> Doc.

%%%-------------------------------------------------------------------
%%% Leaf measures (used by the resolver, which carries precomputed widths)
%%%-------------------------------------------------------------------

-doc "Measure of a `text' placement of display width `Width' at column `Column'.".
-spec text_leaf(
    binary(),
    non_neg_integer(),
    non_neg_integer(),
    module(),
    non_neg_integer()
) -> measure().
text_leaf(Bin, Width, Column, CostMod, PageWidth) ->
    {Column + Width, CostMod:text_cost(PageWidth, Column, Width), {text, Bin}}.

-doc """
Measure of a `nl' at indentation `Indent'. Per `LineM' (Fig. 13) the cost is
`nlF +F textF(0, Indent)' — the newline plus the cost of its indentation
spaces — so a `nl_cost' of `{0, 1}' still charges indentation overflow.
""".
-spec nl_leaf(non_neg_integer(), module(), non_neg_integer()) -> measure().
nl_leaf(Indent, CostMod, PageWidth) ->
    Cost = CostMod:combine(
        CostMod:nl_cost(PageWidth, Indent),
        CostMod:text_cost(PageWidth, 0, Indent)
    ),
    {Indent, Cost, nl}.

%%%-------------------------------------------------------------------
%%% Operations (Fig. 12)
%%%-------------------------------------------------------------------

-doc "Concatenate two measures (`◦'): cost combines, doc concatenates, last from the right.".
-spec compose(measure(), measure(), module()) -> measure().
compose({_La, Ca, Da}, {Lb, Cb, Db}, CostMod) ->
    {Lb, CostMod:combine(Ca, Cb), {concat, Da, Db}}.

-doc "Wrap a measure's document in `nest N' (last and cost unchanged).".
-spec adjust_nest(non_neg_integer(), measure()) -> measure().
adjust_nest(N, {Last, Cost, Doc}) ->
    {Last, Cost, {nest, N, Doc}}.

-doc "Wrap a measure's document in `align' (last and cost unchanged; ghost maxy dropped).".
-spec adjust_align(non_neg_integer(), measure()) -> measure().
adjust_align(_Indent, {Last, Cost, Doc}) ->
    {Last, Cost, {align, Doc}}.

-doc "Wrap a measure's document in `reset' (last and cost unchanged).".
-spec adjust_reset(measure()) -> measure().
adjust_reset({Last, Cost, Doc}) ->
    {Last, Cost, {reset, Doc}}.

-doc "Add an injected `cost' value to a measure (mjl `Cost'); last and document unchanged.".
-spec add_cost(pe_doc:cost_value(), measure(), module()) -> measure().
add_cost(Cv, {Last, Cost, Doc}, CostMod) ->
    {Last, CostMod:combine(Cv, Cost), Doc}.

-doc "Domination `⪯': `Ma' dominates `Mb' when both its last and cost are no worse.".
-spec dominates(measure(), measure(), module()) -> boolean().
dominates({La, Ca, _}, {Lb, Cb, _}, CostMod) ->
    La =< Lb andalso CostMod:le(Ca, Cb).

%%%-------------------------------------------------------------------
%%% Direct measure computation ⇓M (Fig. 13) — used by the oracle
%%%-------------------------------------------------------------------

-doc "Compute the measure of a choiceless document at column `C', indentation `I'.".
-spec measure_term(cdoc(), non_neg_integer(), non_neg_integer(), module(), non_neg_integer()) ->
    measure().
measure_term({text, S}, C, _I, CostMod, W) ->
    text_leaf(S, string:length(S), C, CostMod, W);
measure_term(nl, _C, I, CostMod, W) ->
    nl_leaf(I, CostMod, W);
measure_term({concat, Da, Db}, C, I, CostMod, W) ->
    Ma = measure_term(Da, C, I, CostMod, W),
    Mb = measure_term(Db, last(Ma), I, CostMod, W),
    compose(Ma, Mb, CostMod);
measure_term({nest, N, D}, C, I, CostMod, W) ->
    adjust_nest(N, measure_term(D, C, I + N, CostMod, W));
measure_term({align, D}, C, I, CostMod, W) ->
    adjust_align(I, measure_term(D, C, C, CostMod, W));
measure_term({reset, D}, C, _I, CostMod, W) ->
    adjust_reset(measure_term(D, C, 0, CostMod, W));
measure_term({cost, Cv, D}, C, I, CostMod, W) ->
    add_cost(Cv, measure_term(D, C, I, CostMod, W), CostMod).
