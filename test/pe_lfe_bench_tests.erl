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

%% A1S2-12/14: CSV header matches the columns and there is one line per row.
csv_header_and_count_test() ->
    Rows = pe_lfe_bench:rows([pe_lfe_samples:by_id(lfe_02_fizz)], [80, 100]),
    Csv = pe_lfe_bench:to_csv(Rows),
    Lines = binary:split(Csv, <<"\n">>, [global, trim]),
    [Header | DataLines] = Lines,
    ?assertEqual(<<"id,label,width,time_us,memo_size,calls,tainted,badness,height,bytes,lines">>, Header),
    ?assertEqual(2, length(DataLines)).
