%%% @doc EUnit smoke test for the real-LFE sample benchmark.
-module(pe_lfe_bench_tests).

-include_lib("eunit/include/eunit.hrl").

%% A1S2-12: the exact CSV column set is emitted.
columns_test() ->
    ?assertEqual(
        [id, label, width, time_us, memo_size, calls, tainted, badness, height, bytes, lines],
        pe_lfe_bench:columns()
    ).

%% A row carries a value for every column; counters are non-negative.
row_shape_test() ->
    Sample = pe_lfe_samples:by_id(lfe_01_ackermann),
    Row = pe_lfe_bench:row(Sample, 80),
    [?assert(maps:is_key(C, Row)) || C <- pe_lfe_bench:columns()],
    ?assertEqual(80, maps:get(width, Row)),
    ?assert(maps:get(bytes, Row) > 0),
    ?assert(maps:get(lines, Row) >= 1),
    ?assert(maps:get(time_us, Row) >= 0).

%% A1S2-13: all 20 samples at widths 80 and 100 -> 40 rows.
row_count_test() ->
    Rows = pe_lfe_bench:rows(pe_lfe_samples:all(), [80, 100]),
    ?assertEqual(40, length(Rows)).

%% A1S3-21: the knowledge benchmark covers widths 80, 100, 60 -> 60 rows.
knowledge_row_count_test() ->
    Rows = pe_lfe_bench:rows(pe_lfe_samples:all(), [80, 100, 60]),
    ?assertEqual(60, length(Rows)).

%% A1S3-23: CSV fields with commas/quotes/newlines are escaped (quoted, inner
%% quotes doubled); plain fields are left bare.
csv_escaping_test() ->
    Rows = [
        #{
            id => demo,
            label => <<"a,b \"c\"">>,
            width => 80,
            time_us => 1,
            memo_size => 2,
            calls => 3,
            tainted => 0,
            badness => 0,
            height => 1,
            bytes => 5,
            lines => 1
        }
    ],
    Csv = pe_lfe_bench:to_csv(Rows),
    %% the label is quoted with its inner quotes doubled.
    ?assert(binary:match(Csv, <<"\"a,b \"\"c\"\"\"">>) =/= nomatch),
    %% a plain label is not quoted.
    PlainCsv = pe_lfe_bench:to_csv([(hd(Rows))#{label => <<"plain">>}]),
    ?assert(binary:match(PlainCsv, <<",plain,">>) =/= nomatch).

%% A1S2-12/14: CSV header matches the columns and there is one line per row.
csv_header_and_count_test() ->
    Rows = pe_lfe_bench:rows([pe_lfe_samples:by_id(lfe_02_fizz)], [80, 100]),
    Csv = pe_lfe_bench:to_csv(Rows),
    Lines = binary:split(Csv, <<"\n">>, [global, trim]),
    [Header | DataLines] = Lines,
    ?assertEqual(
        <<"id,label,width,time_us,memo_size,calls,tainted,badness,height,bytes,lines">>, Header
    ),
    ?assertEqual(2, length(DataLines)).

%% A1S4-16: stress CSV has the analysis-oriented header.
stress_columns_test() ->
    ?assertEqual(
        [
            id,
            label,
            category,
            size,
            width,
            limit,
            status,
            time_us,
            memo_size,
            calls,
            tainted,
            badness,
            height,
            bytes,
            lines,
            dag_size
        ],
        pe_lfe_bench:stress_columns()
    ).

%% A1S4-16/20: a stress row carries every column and a deterministic DAG size.
stress_row_shape_test() ->
    Sample = pe_lfe_stress:by_id(<<"proper_list_24">>),
    Row = pe_lfe_bench:stress_row(Sample, 40, 1000),
    [?assert(maps:is_key(C, Row)) || C <- pe_lfe_bench:stress_columns()],
    ?assertEqual(<<"proper_list_24">>, maps:get(id, Row)),
    ?assertEqual(<<"proper-list">>, maps:get(category, Row)),
    ?assertEqual(40, maps:get(width, Row)),
    ?assertEqual(40, maps:get(limit, Row)),
    ?assertEqual(ok, maps:get(status, Row)),
    ?assert(maps:get(dag_size, Row) > 0),
    ?assert(maps:get(bytes, Row) > 0).

%% A1S4-17: 25 samples at the five required widths -> 125 rows.
stress_row_count_test() ->
    Rows = pe_lfe_bench:stress_rows(pe_lfe_stress:all(), [20, 40, 60, 80, 100], 1000),
    ?assertEqual(125, length(Rows)).

%% A1S4-18/19: monitored workers report timeout/error as tagged values.
stress_monitored_timeout_test() ->
    ?assertEqual(timeout, pe_lfe_bench:monitored(fun() -> receive
        after 50 -> ok
        end end, 1)).

stress_monitored_error_test() ->
    ?assertMatch({error, _}, pe_lfe_bench:monitored(fun() -> error(bad_stress_worker) end, 1000)).

stress_csv_header_and_count_test() ->
    Rows = pe_lfe_bench:stress_rows([pe_lfe_stress:by_id(<<"nofit_text_80">>)], [20, 40], 1000),
    Csv = pe_lfe_bench:stress_to_csv(Rows),
    Lines = binary:split(Csv, <<"\n">>, [global, trim]),
    [Header | DataLines] = Lines,
    ?assertEqual(
        <<
            "id,label,category,size,width,limit,status,time_us,memo_size,calls,tainted,"
            "badness,height,bytes,lines,dag_size"
        >>,
        Header
    ),
    ?assertEqual(2, length(DataLines)).

%% A1S5-16..19: refined benchmark has its own column set and covers the real
%% sample matrix plus the named affected stress subset.
refined_columns_test() ->
    ?assertEqual(
        [
            suite,
            id,
            label,
            category,
            width,
            limit,
            status,
            time_us,
            memo_size,
            calls,
            tainted,
            badness,
            height,
            bytes,
            lines,
            dag_size
        ],
        pe_lfe_bench:refined_columns()
    ).

refined_row_count_and_subset_test() ->
    Rows = pe_lfe_bench:refined_rows(),
    SampleRows = [R || R <- Rows, maps:get(suite, R) =:= <<"lfe-sample">>],
    StressRows = [R || R <- Rows, maps:get(suite, R) =:= <<"stress-affected">>],
    ?assertEqual(85, length(Rows)),
    ?assertEqual(60, length(SampleRows)),
    ?assertEqual(25, length(StressRows)),
    ?assertEqual([60, 80, 100], lists:usort([maps:get(width, R) || R <- SampleRows])),
    ?assertEqual([20, 40, 60, 80, 100], lists:usort([maps:get(width, R) || R <- StressRows])),
    ?assertEqual(
        [
            <<"block_arg_case">>,
            <<"block_arg_lambda">>,
            <<"block_arg_match_lambda">>,
            <<"block_arg_receive">>,
            <<"fletrec_bindings_12">>
        ],
        lists:usort([maps:get(id, R) || R <- StressRows])
    ),
    [?assert(maps:get(dag_size, R) > 0) || R <- Rows].

refined_csv_header_and_count_test() ->
    Rows = pe_lfe_bench:refined_rows(),
    Csv = pe_lfe_bench:refined_to_csv(Rows),
    Lines = binary:split(Csv, <<"\n">>, [global, trim]),
    [Header | DataLines] = Lines,
    ?assertEqual(
        <<
            "suite,id,label,category,width,limit,status,time_us,memo_size,calls,tainted,"
            "badness,height,bytes,lines,dag_size"
        >>,
        Header
    ),
    ?assertEqual(85, length(DataLines)).

%% A1S6-12: the lfe-files CSV column set is the documented header.
files_columns_test() ->
    ?assertEqual(
        [
            file, width, status, n_forms, bytes, lines, parse_us, fmt_us,
            worst_form_us, worst_form_index, worst_form_head, memo_size, calls,
            tainted, badness, dag_size, genericised
        ],
        pe_lfe_bench:files_columns()
    ).

files_csv_header_test() ->
    Dir = code:lib_dir(lfe),
    Row = pe_lfe_bench:files_row(filename:join([Dir, "src", "cl.lfe"]), 80, 30000),
    Csv = pe_lfe_bench:files_to_csv([Row]),
    [Header | _] = binary:split(Csv, <<"\n">>, [global, trim]),
    ?assertEqual(
        <<
            "file,width,status,n_forms,bytes,lines,parse_us,fmt_us,worst_form_us,"
            "worst_form_index,worst_form_head,memo_size,calls,tainted,badness,"
            "dag_size,genericised"
        >>,
        Header
    ).

%% A1S6-9/10: a real file yields a populated ok row with separate parse/fmt times.
files_row_ok_test() ->
    Dir = code:lib_dir(lfe),
    Row = pe_lfe_bench:files_row(filename:join([Dir, "src", "cl.lfe"]), 80, 30000),
    ?assertEqual(ok, maps:get(status, Row)),
    ?assert(maps:get(n_forms, Row) > 0),
    ?assert(maps:get(fmt_us, Row) >= 0),
    ?assert(maps:get(parse_us, Row) >= 0),
    ?assert(maps:get(dag_size, Row) > 0).

%% A1S6-9: a bad path becomes an error status row, never a hang or a crash.
files_row_error_test() ->
    Row = pe_lfe_bench:files_row("/no/such/file_xyz.lfe", 80, 2000),
    ?assertEqual(error, maps:get(status, Row)),
    ?assertEqual(0, maps:get(n_forms, Row)).
