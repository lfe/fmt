%%% @doc EUnit for the slice9 declarative rule registry: the loader
%%% (`read_rules'/`load_rules'), the registry-driven dispatch, the optional
%%% overlay, and — the gate — behaviour preservation vs the pre-slice9 hardcoded
%%% `call_form' path captured in `test/fixtures/lfe_format_baseline.eterm'.
-module(pe_lfe_registry_tests).

-include_lib("eunit/include/eunit.hrl").

%%%-------------------------------------------------------------------
%%% A1S9-8: behaviour preservation (the gate)
%%%-------------------------------------------------------------------

%% Every `pe_lfe_samples' form x width renders byte-identically to the bytes the
%% pre-slice9 hardcoded dispatch produced (committed baseline). One generated
%% case per row so a regression names the exact sample+width.
behaviour_preserved_vs_baseline_test_() ->
    {ok, [Baseline]} = file:consult("test/fixtures/lfe_format_baseline.eterm"),
    [
        {lists:flatten(io_lib:format("~p @ w=~p", [Id, W])), fun() ->
            Dag = pe_lfe_samples:build(pe_lfe_samples:by_id(Id)),
            {Bin, _, _} = pe:format_binary(Dag, #{width => W}),
            ?assertEqual(Expected, Bin)
        end}
     || {Id, W, Expected} <- Baseline
    ].

%%%-------------------------------------------------------------------
%%% A1S9-2: loader + atom discipline
%%%-------------------------------------------------------------------

base_registry_loads_with_binary_keys_test() ->
    R = pe_lfe:load_rules(),
    %% form names are binary keys — nothing minted as an atom from a form name.
    ?assert(lists:all(fun erlang:is_binary/1, maps:keys(R))),
    ?assertEqual({define, []}, maps:get(<<"defun">>, R)),
    ?assertEqual({'let-binds', []}, maps:get(<<"let*">>, R)),
    ?assertEqual({block, []}, maps:get(<<"eval-when-compile">>, R)).

%%%-------------------------------------------------------------------
%%% A1S9-3: unknown / malformed rows are load errors, not silent skips
%%%-------------------------------------------------------------------

unknown_style_tag_is_load_error_test() ->
    Path = tmp_rules("{rules_version, 1}.\n{rule, \"weird\", bogus_tag, []}.\n"),
    try
        ?assertError({unknown_style_tag, bogus_tag, "weird"}, pe_lfe:read_rules(Path))
    after
        file:delete(Path)
    end.

malformed_rule_is_load_error_test() ->
    %% a 3-tuple `rule' row does not match the {rule, Name, Tag, Params} shape.
    Path = tmp_rules("{rules_version, 1}.\n{rule, \"x\", define}.\n"),
    try
        ?assertError({malformed_rule, {rule, "x", define}}, pe_lfe:read_rules(Path))
    after
        file:delete(Path)
    end.

%%%-------------------------------------------------------------------
%%% A1S9-4: overlay merges over the base (overlay wins per form)
%%%-------------------------------------------------------------------

overlay_wins_and_base_preserved_test() ->
    Base = pe_lfe:load_rules(),
    Overlay = #{<<"case">> => {block, []}, <<"myform">> => {clauses, []}},
    Merged = pe_lfe:load_rules(Overlay),
    %% overlay overrides an existing form...
    ?assertEqual({block, []}, maps:get(<<"case">>, Merged)),
    %% ...and adds a new one...
    ?assertEqual({clauses, []}, maps:get(<<"myform">>, Merged)),
    %% ...while untouched base forms are preserved.
    ?assertEqual(maps:get(<<"defun">>, Base), maps:get(<<"defun">>, Merged)).

%%%-------------------------------------------------------------------
%%% A1S9-5: caller-supplied registry threads through ctx (no global truth)
%%%-------------------------------------------------------------------

custom_registry_changes_dispatch_test() ->
    Catch = catch_form(),
    %% empty registry: `catch' is not special -> generic S-expression layout.
    Generic = fmt(Catch, #{registry => #{}}, 10),
    %% base registry: `catch' is a vertical block (the demonstrator rule).
    Block = fmt(Catch, #{}, 10),
    ?assertNotEqual(Generic, Block),
    ?assertNotEqual(nomatch, binary:match(Block, <<"\n  (foo">>)).

%%%-------------------------------------------------------------------
%%% A1S9-10: the data-only demonstrator (`catch' -> block, no palette code)
%%%-------------------------------------------------------------------

catch_demonstrator_golden_test() ->
    Catch = catch_form(),
    %% wide: flattens to one line.
    ?assertEqual(<<"(catch (foo x) (bar y))">>, fmt(Catch, #{}, 80)),
    %% narrow: vertical block, body indented by the 2-space step.
    ?assertEqual(<<"(catch\n  (foo x)\n  (bar y))">>, fmt(Catch, #{}, 10)).

%%%-------------------------------------------------------------------
%%% Helpers
%%%-------------------------------------------------------------------

catch_form() ->
    {call, [
        {sym, <<"catch">>},
        {call, [{sym, <<"foo">>}, {sym, <<"x">>}]},
        {call, [{sym, <<"bar">>}, {sym, <<"y">>}]}
    ]}.

fmt(Form, Opts, Width) ->
    {Bin, _, _} = pe:format_binary(pe_lfe:to_doc(Form, Opts), #{width => Width}),
    Bin.

tmp_rules(Content) ->
    Name = "pe_lfe_rules_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".eterm",
    Path = filename:join(tmp_dir(), Name),
    ok = file:write_file(Path, Content),
    Path.

tmp_dir() ->
    case os:getenv("TMPDIR") of
        false -> "/tmp";
        Dir -> Dir
    end.
