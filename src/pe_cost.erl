%%% @doc The cost-factory behaviour: the optimality objective as a parameter.
%%%
%%% A cost factory is a totally-ordered monoid with translational invariance
%%% (paper Fig. 6). It supplies a cost type and four operations. `le'/`combine'
%%% are the cost algebra (width-independent); `text_cost'/`nl_cost' compute the
%%% cost of placing text / a newline and therefore need the page `Width' (the
%%% engine threads it, since the resolver carries `width' separately from the
%%% `cost' module).
%%%
%%% Contracts every implementation must satisfy (these license the Pareto
%%% pruning — see {@link pe_cost_squared} and `prop_factory_contracts'):
%%% <ul>
%%%   <li>`le' is a total order;</li>
%%%   <li>`combine' is associative and monotone in both arguments, with
%%%       identity `text_cost(W, 0, 0)';</li>
%%%   <li>`text_cost' is monotone in the column and decomposes additively:
%%%       `text_cost(W, C, L1+L2) = combine(text_cost(W, C, L1),
%%%        text_cost(W, C+L1, L2))';</li>
%%%   <li>`text_cost(W, C, 0) = text_cost(W, 0, 0)'.</li>
%%% </ul>
%%% @end
-module(pe_cost).

-moduledoc "The cost-factory behaviour: the optimality objective as a parameter.".

-export_type([cost/0]).

-doc "An opaque-to-the-engine cost value; only the factory interprets it.".
-type cost() :: term().

-callback le(cost(), cost()) -> boolean().
-callback combine(cost(), cost()) -> cost().
-callback text_cost(
    Width :: non_neg_integer(),
    Column :: non_neg_integer(),
    Length :: non_neg_integer()
) -> cost().
-callback nl_cost(Width :: non_neg_integer(), Indent :: non_neg_integer()) -> cost().
