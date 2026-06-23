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
    Rows = [#{
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
    }],
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
    ?assertEqual(<<"id,label,width,time_us,memo_size,calls,tainted,badness,height,bytes,lines">>, Header),
    ?assertEqual(2, length(DataLines)).
