%%% @doc EUnit tests for the pathological stress corpus.
-module(pe_lfe_stress_tests).

-include_lib("eunit/include/eunit.hrl").

expected_ids() ->
    [
        <<"proper_list_24">>,
        <<"proper_list_48">>,
        <<"dotted_list_16">>,
        <<"dotted_list_32">>,
        <<"generic_call_24">>,
        <<"generic_call_48">>,
        <<"deep_sexp_8">>,
        <<"deep_sexp_12">>,
        <<"shared_concat_10">>,
        <<"shared_choice_8">>,
        <<"quote_tower_12">>,
        <<"quote_tower_18">>,
        <<"let_bindings_16">>,
        <<"letstar_bindings_24">>,
        <<"fletrec_bindings_12">>,
        <<"nested_case_8">>,
        <<"nested_receive_6">>,
        <<"nested_cond_12">>,
        <<"block_arg_match_lambda">>,
        <<"block_arg_lambda">>,
        <<"block_arg_case">>,
        <<"block_arg_receive">>,
        <<"nofit_text_80">>,
        <<"nofit_text_180">>,
        <<"tiny_width_call_30">>
    ].

required_categories() ->
    [
        <<"proper-list">>,
        <<"dotted-list">>,
        <<"generic-call">>,
        <<"deep-sexp">>,
        <<"shared-dag">>,
        <<"quote-tower">>,
        <<"binding-list">>,
        <<"clause-form">>,
        <<"block-argument">>,
        <<"forced-nofit">>
    ].

%% A1S4-1/2: stable corpus metadata.
stress_count_and_ids_test() ->
    Samples = pe_lfe_stress:all(),
    ?assertEqual(25, length(Samples)),
    ?assertEqual(expected_ids(), [pe_lfe_stress:id(S) || S <- Samples]).

stress_metadata_test() ->
    [
        begin
            ?assert(is_binary(pe_lfe_stress:id(S))),
            ?assert(byte_size(pe_lfe_stress:id(S)) > 0),
            ?assert(is_binary(pe_lfe_stress:label(S))),
            ?assert(byte_size(pe_lfe_stress:label(S)) > 0),
            ?assert(is_binary(pe_lfe_stress:category(S))),
            ?assert(byte_size(pe_lfe_stress:category(S)) > 0),
            ?assert(pe_lfe_stress:size(S) >= 0)
        end
     || S <- pe_lfe_stress:all()
    ].

stress_categories_test() ->
    Categories = lists:usort([pe_lfe_stress:category(S) || S <- pe_lfe_stress:all()]),
    [?assert(lists:member(C, Categories)) || C <- required_categories()].

by_id_test() ->
    S = pe_lfe_stress:by_id(<<"proper_list_24">>),
    ?assertEqual(<<"proper_list_24">>, pe_lfe_stress:id(S)),
    ?assertError({unknown_stress_sample, <<"missing">>}, pe_lfe_stress:by_id(<<"missing">>)).

%% A1S4-13: deterministic builds for all samples.
stress_builds_deterministic_test() ->
    [
        begin
            Dag1 = pe_lfe_stress:build(S),
            Dag2 = pe_lfe_stress:build(S),
            ?assert(pe_doc:size(Dag1) > 0),
            ?assertEqual(pe_doc:size(Dag1), pe_doc:size(Dag2)),
            ?assertEqual(pe_doc:root(Dag1), pe_doc:root(Dag2))
        end
     || S <- pe_lfe_stress:all()
    ].

%% A1S4-3..12/21: one bounded render representative per stress family.
representative_families_render_test() ->
    Ids = [
        <<"proper_list_24">>,
        <<"dotted_list_16">>,
        <<"generic_call_24">>,
        <<"deep_sexp_8">>,
        <<"shared_concat_10">>,
        <<"quote_tower_12">>,
        <<"let_bindings_16">>,
        <<"nested_case_8">>,
        <<"block_arg_match_lambda">>,
        <<"nofit_text_80">>
    ],
    [render_ok(pe_lfe_stress:by_id(Id), 40) || Id <- Ids].

render_ok(Sample, Width) ->
    Dag = pe_lfe_stress:build(Sample),
    {Bin, _Measure, _Stats} = pe:format_binary(Dag, #{width => Width, limit => Width}),
    ?assert(byte_size(Bin) > 0).

%% A1S4-7/20: direct shared DAG samples are structurally small despite large
%% expanded trees; `dag_size' means the frozen hash-consed node count.
shared_dag_size_test() ->
    Dag = pe_lfe_stress:build(pe_lfe_stress:by_id(<<"shared_concat_10">>)),
    ?assert(pe_doc:size(Dag) =< 12).

%% A1S4-22: forced no-fit canary yields non-zero badness at narrow width.
forced_nofit_badness_test() ->
    Dag = pe_lfe_stress:build(pe_lfe_stress:by_id(<<"nofit_text_80">>)),
    {_Bin, Measure, Stats} = pe:format_binary(Dag, #{width => 20, limit => 20}),
    {Badness, _Height} = pe_measure:cost(Measure),
    ?assert(Badness > 0),
    ?assert(maps:get(tainted, Stats) > 0).

%% A1S5-5/12: affected stress canaries reflect the refined layout.
block_argument_stress_layout_test() ->
    ?assert(block_arg_line(<<"block_arg_match_lambda">>, <<"  (match-lambda">>)),
    ?assert(block_arg_line(<<"block_arg_lambda">>, <<"  (lambda">>)),
    ?assert(block_arg_line(<<"block_arg_case">>, <<"  (case">>)),
    ?assert(block_arg_line(<<"block_arg_receive">>, <<"  (receive">>)).

fletrec_stress_binding_layout_test() ->
    Bin = render_bin(pe_lfe_stress:by_id(<<"fletrec_bindings_12">>), 40),
    Lines = lines(Bin),
    ?assert(lists:member(<<"  ((f_1 (x_1) (+ x_1 1))">>, Lines)),
    ?assert(lists:member(<<"   (f_2 (x_2) (+ x_2 2))">>, Lines)),
    ?assertNot(contains(Bin, <<"\n    (x_1)\n">>)).

block_arg_line(Id, Line) ->
    Lines = lines(render_bin(pe_lfe_stress:by_id(Id), 40)),
    lists:any(fun(L) -> starts_with(L, Line) end, Lines).

starts_with(Bin, Prefix) when byte_size(Bin) >= byte_size(Prefix) ->
    binary:part(Bin, 0, byte_size(Prefix)) =:= Prefix;
starts_with(_Bin, _Prefix) ->
    false.

render_bin(Sample, Width) ->
    Dag = pe_lfe_stress:build(Sample),
    {Bin, _Measure, _Stats} = pe:format_binary(Dag, #{width => Width, limit => Width}),
    Bin.

lines(Bin) ->
    binary:split(Bin, <<"\n">>, [global]).

contains(Bin, Needle) ->
    binary:match(Bin, Needle) =/= nomatch.
