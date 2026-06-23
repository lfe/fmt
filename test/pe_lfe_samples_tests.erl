%%% @doc EUnit tests for the {@link pe_lfe_samples} fixture corpus.
-module(pe_lfe_samples_tests).

-include_lib("eunit/include/eunit.hrl").

expected_ids() ->
    [
        lfe_01_ackermann, lfe_02_fizz, lfe_03_buzz1, lfe_04_tail_buzz,
        lfe_05_plusplus, lfe_06_cond, lfe_07_bq_expand, lfe_08_ets_new,
        lfe_09_by_place_ms, lfe_10_mnesia_new, lfe_11_guess_server,
        lfe_12_ping_pong, lfe_13_get_page, lfe_14_fish_closure,
        lfe_15_fish_process, lfe_16_account, lfe_17_eval_expr,
        lfe_18_parse_bitspecs, lfe_19_eval_lambda, lfe_20_eval_receive
    ].

%% A1S2-6: exactly 20 samples with id/label/source/tags metadata.
sample_count_test() ->
    ?assertEqual(20, length(pe_lfe_samples:all())).

sample_metadata_test() ->
    [
        begin
            ?assert(is_atom(pe_lfe_samples:id(S))),
            ?assert(is_binary(pe_lfe_samples:label(S))),
            ?assert(byte_size(pe_lfe_samples:label(S)) > 0),
            ?assert(is_binary(pe_lfe_samples:source(S))),
            ?assert(byte_size(pe_lfe_samples:source(S)) > 0),
            ?assert(is_list(pe_lfe_samples:tags(S))),
            ?assert(length(pe_lfe_samples:tags(S)) > 0)
        end
     || S <- pe_lfe_samples:all()
    ].

%% A1S2-7: the corpus is exactly Ackermann plus the 19 selected forms.
sample_ids_test() ->
    Ids = [pe_lfe_samples:id(S) || S <- pe_lfe_samples:all()],
    ?assertEqual(expected_ids(), Ids).

by_id_test() ->
    S = pe_lfe_samples:by_id(lfe_01_ackermann),
    ?assertEqual(lfe_01_ackermann, pe_lfe_samples:id(S)),
    ?assertError({unknown_sample, nope}, pe_lfe_samples:by_id(nope)).

%% A1S2-8: every builder returns a frozen DAG with positive size and a stable
%% root (the root is a valid node id and re-building is deterministic).
sample_builds_test() ->
    [
        begin
            Dag = pe_lfe_samples:build(S),
            ?assert(pe_doc:size(Dag) > 0),
            Root = pe_doc:root(Dag),
            ?assert(Root >= 0 andalso Root < pe_doc:size(Dag)),
            Dag2 = pe_lfe_samples:build(S),
            ?assertEqual(pe_doc:root(Dag), pe_doc:root(Dag2)),
            ?assertEqual(pe_doc:size(Dag), pe_doc:size(Dag2))
        end
     || S <- pe_lfe_samples:all()
    ].

%% A1S2-9 / A1S2-10: every sample resolves + renders at widths 80 and 100 with
%% non-empty, paren-balanced output.
samples_render_width_80_test() ->
    [render_ok(S, 80) || S <- pe_lfe_samples:all()].

samples_render_width_100_test() ->
    [render_ok(S, 100) || S <- pe_lfe_samples:all()].

render_ok(S, Width) ->
    Dag = pe_lfe_samples:build(S),
    {Bin, _Measure, _Stats} = pe:format_binary(Dag, #{width => Width}),
    ?assert(byte_size(Bin) > 0),
    ?assertEqual(
        count(Bin, $(),
        count(Bin, $)),
        lists:flatten(io_lib:format("unbalanced parens in ~p @ ~p", [pe_lfe_samples:id(S), Width]))
    ).

%% A1S2-11: rendering is deterministic across repeated runs.
samples_deterministic_test() ->
    [
        begin
            Dag = pe_lfe_samples:build(S),
            {B1, _, _} = pe:format_binary(Dag, #{width => 80}),
            {B2, _, _} = pe:format_binary(Dag, #{width => 80}),
            ?assertEqual(B1, B2)
        end
     || S <- pe_lfe_samples:all()
    ].

count(Bin, Char) ->
    length([c || <<C>> <= Bin, C =:= Char]).
