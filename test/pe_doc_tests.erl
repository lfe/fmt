%%% @doc EUnit tests for {@link pe_doc} — the builder + frozen term DAG.
-module(pe_doc_tests).

-include_lib("eunit/include/eunit.hrl").

%% A1S1-1: constructors + freeze + get/2 via element/2.
constructors_freeze_get_test() ->
    B0 = pe_doc:new(),
    {X, B1} = pe_doc:text(<<"x">>, B0),
    {Nl, B2} = pe_doc:nl(B1),
    {C, B3} = pe_doc:concat(X, Nl, B2),
    Dag = pe_doc:freeze(B3, C),
    ?assertEqual(C, pe_doc:root(Dag)),
    ?assertEqual(3, pe_doc:size(Dag)),
    ?assertEqual({text, <<"x">>, 1}, pe_doc:get(Dag, X)),
    ?assertEqual(nl, pe_doc:get(Dag, Nl)),
    ?assertEqual({concat, X, Nl}, pe_doc:get(Dag, C)).

%% Display width is string:length/1, not byte_size/1 (unicode correctness).
text_display_width_test() ->
    B0 = pe_doc:new(),
    %% "é" as a 2-byte UTF-8 binary is one display column.
    {E, B1} = pe_doc:text(<<"é"/utf8>>, B0),
    Dag = pe_doc:freeze(B1, E),
    ?assertEqual({text, <<"é"/utf8>>, 1}, pe_doc:get(Dag, E)).

%% A1S1-2: hash-consing — identical content interns to the same id.
hashcons_test() ->
    B0 = pe_doc:new(),
    {X1, B1} = pe_doc:text(<<"x">>, B0),
    {X2, B2} = pe_doc:text(<<"x">>, B1),
    ?assertEqual(X1, X2),
    {Y, B3} = pe_doc:text(<<"y">>, B2),
    ?assertNotEqual(X1, Y),
    %% identical *subtrees* dedup to one id, too.
    {C1, B4} = pe_doc:concat(X1, Y, B3),
    {C2, B5} = pe_doc:concat(X1, Y, B4),
    ?assertEqual(C1, C2),
    %% and no extra node was interned for the duplicate concat.
    Dag = pe_doc:freeze(B5, C1),
    ?assertEqual(3, pe_doc:size(Dag)).

%% A1S1-3: children are ordered and may repeat. Uses newline nodes, not text,
%% so the mjl `(Text, Text)` smart-constructor merge (slice8) does not collapse
%% the concat into a single text.
children_order_repeat_test() ->
    B0 = pe_doc:new(),
    {X, B1} = pe_doc:nl(B0),
    {Y, B2} = pe_doc:brk(B1),
    %% repeated child: concat(X, X) -> [X, X] (one node, two refs).
    {Dup, B3} = pe_doc:concat(X, X, B2),
    %% ordered child: concat(X, Y) -> [X, Y], never [Y, X].
    {Ord, B4} = pe_doc:concat(X, Y, B3),
    Dag = pe_doc:freeze(B4, Ord),
    ?assertEqual([X, X], pe_doc:children(Dag, Dup)),
    ?assertEqual([X, Y], pe_doc:children(Dag, Ord)).

%% A1S1-5: flatten rewrites nl -> space, is identity-preserving, and
%% distributes through choice (and nest/align/concat).
flatten_nl_becomes_space_test() ->
    B0 = pe_doc:new(),
    {Nl, B1} = pe_doc:nl(B0),
    {F, B2} = pe_doc:flatten(Nl, B1),
    Dag = pe_doc:freeze(B2, F),
    ?assertEqual({text, <<" ">>, 1}, pe_doc:get(Dag, F)).

flatten_identity_preserving_test() ->
    B0 = pe_doc:new(),
    {X, B1} = pe_doc:text(<<"x">>, B0),
    %% no nl inside -> flatten returns the same id.
    {FX, B2} = pe_doc:flatten(X, B1),
    ?assertEqual(X, FX),
    {C, B3} = pe_doc:concat(X, X, B2),
    {FC, _B4} = pe_doc:flatten(C, B3),
    ?assertEqual(C, FC).

flatten_distributes_through_choice_test() ->
    B0 = pe_doc:new(),
    {Nl, B1} = pe_doc:nl(B0),
    {X, B2} = pe_doc:text(<<"x">>, B1),
    {Ch, B3} = pe_doc:choice(Nl, X, B2),
    {F, B4} = pe_doc:flatten(Ch, B3),
    Dag = pe_doc:freeze(B4, F),
    %% flatten(choice(nl, x)) = choice(space, x): still a choice, nl -> space,
    %% x unchanged.
    ?assertMatch({choice, _, _}, pe_doc:get(Dag, F)),
    [LeftId, RightId] = pe_doc:children(Dag, F),
    ?assertEqual({text, <<" ">>, 1}, pe_doc:get(Dag, LeftId)),
    ?assertEqual(X, RightId).

%% flatten distributes through nest; the inner body keeps a `choice' so the
%% `nest' survives the mjl smart-constructor (slice8) `nest(Text) => Text'
%% short-circuit. (A bare `nest 2 nl' would flatten to just `text " "', since
%% nesting a newline-free document is identity.)
flatten_distributes_through_nest_test() ->
    B0 = pe_doc:new(),
    {Nl, B1} = pe_doc:nl(B0),
    {X, B2} = pe_doc:text(<<"x">>, B1),
    {Ch, B3} = pe_doc:choice(Nl, X, B2),
    {N, B4} = pe_doc:nest(2, Ch, B3),
    {F, B5} = pe_doc:flatten(N, B4),
    Dag = pe_doc:freeze(B5, F),
    {nest, 2, Inner} = pe_doc:get(Dag, F),
    %% flatten(choice(nl, x)) = choice(space, x).
    {choice, SpaceId, XId} = pe_doc:get(Dag, Inner),
    ?assertEqual({text, <<" ">>, 1}, pe_doc:get(Dag, SpaceId)),
    ?assertEqual(X, XId).

%% mjl smart-constructor: nesting/aligning a newline-free document is identity.
nest_align_text_short_circuit_test() ->
    B0 = pe_doc:new(),
    {X, B1} = pe_doc:text(<<"x">>, B0),
    ?assertEqual(X, element(1, pe_doc:nest(2, X, B1))),
    ?assertEqual(X, element(1, pe_doc:align(X, B1))),
    ?assertEqual(X, element(1, pe_doc:reset(X, B1))).

%% group(D) = choice(flatten(D), D); vconcat(A, B) = concat(A, concat(nl, B)).
group_test() ->
    B0 = pe_doc:new(),
    {Nl, B1} = pe_doc:nl(B0),
    {G, B2} = pe_doc:group(Nl, B1),
    Dag = pe_doc:freeze(B2, G),
    {choice, FlatId, BrokenId} = pe_doc:get(Dag, G),
    ?assertEqual({text, <<" ">>, 1}, pe_doc:get(Dag, FlatId)),
    ?assertEqual(Nl, BrokenId).

vconcat_test() ->
    B0 = pe_doc:new(),
    {A, B1} = pe_doc:text(<<"a">>, B0),
    {C, B2} = pe_doc:text(<<"b">>, B1),
    {V, B3} = pe_doc:vconcat(A, C, B2),
    Dag = pe_doc:freeze(B3, V),
    {concat, A, Rhs} = pe_doc:get(Dag, V),
    {concat, NlId, C} = pe_doc:get(Dag, Rhs),
    ?assertEqual(nl, pe_doc:get(Dag, NlId)).
