%%% @doc Render a choiceless document to text (paper Fig. 8, `⇓R').
%%%
%%% The resolver's winning measure carries a choiceless document
%%% ({@link pe_measure:doc/1}); this turns it into an `iolist()' (or a binary).
%%% Output is assembled as a nested iolist — nothing is flattened in the hot
%%% path; `render_binary/1' calls `iolist_to_binary/1' once at the edge.
%%%
%%% Column and indentation are tracked separately, the same subtlety as the
%%% resolver: `nest N' increases indentation <em>relative</em> to the current
%%% level, while `align' sets it <em>absolutely</em> to the current column. A
%%% newline emits `\n' followed by the current indentation in spaces.
%%% @end
-module(pe_render).

-moduledoc "Render a choiceless document to text (paper Fig. 8).".

-export([render/1, render_binary/1]).

-doc "Render a choiceless document to an iolist.".
-spec render(pe_measure:cdoc()) -> iolist().
render(Cdoc) ->
    {Iodata, _Col} = render(Cdoc, 0, 0),
    [Iodata].

-doc "Render a choiceless document to a binary (flattened once at the edge).".
-spec render_binary(pe_measure:cdoc()) -> binary().
render_binary(Cdoc) ->
    iolist_to_binary(render(Cdoc)).

%% render(Doc, Column, Indent) -> {iodata(), NewColumn}.
-spec render(pe_measure:cdoc(), non_neg_integer(), non_neg_integer()) ->
    {iodata(), non_neg_integer()}.
render({text, Bin}, Col, _Indent) ->
    {Bin, Col + string:length(Bin)};
render(nl, _Col, Indent) ->
    %% newline, then Indent spaces; the new column is the indentation.
    {[$\n | spaces(Indent)], Indent};
render({concat, A, B}, Col, Indent) ->
    {Ra, Col1} = render(A, Col, Indent),
    {Rb, Col2} = render(B, Col1, Indent),
    {[Ra, Rb], Col2};
render({nest, N, D}, Col, Indent) ->
    %% relative: indentation increases by N for the sub-document.
    render(D, Col, Indent + N);
render({align, D}, Col, _Indent) ->
    %% absolute: indentation is set to the current column.
    render(D, Col, Col).

-spec spaces(non_neg_integer()) -> [32].
spaces(0) -> [];
spaces(N) -> lists:duplicate(N, $\s).
