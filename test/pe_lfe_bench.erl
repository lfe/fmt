%%% @doc Real-LFE sample benchmark (test-only): resolve+render the 20 fixtures
%%% — now lowered through the {@link pe_lfe} knowledge layer — and report
%%% timing, memo/call/taint stats, and rendered size. Numbers for CDC/operator;
%%% draws no conclusion.
%%%
%%% Timing uses `timer:tc/1' (monotonic on modern OTP), best-of-N, with each
%%% repeat in a fresh, monitored process so a crashing worker reports an error
%%% instead of hanging the parent (A1-R009).
-module(pe_lfe_bench).

-export([
    columns/0,
    row/2,
    rows/2,
    to_csv/1,
    run/0,
    run_knowledge/0,
    stress_columns/0,
    stress_row/3,
    stress_rows/3,
    stress_to_csv/1,
    run_stress/0,
    refined_columns/0,
    refined_rows/0,
    refined_to_csv/1,
    run_refined/0,
    monitored/2
]).

-define(REPEATS, 5).
-define(STRESS_WIDTHS, [20, 40, 60, 80, 100]).
-define(REFINED_SAMPLE_WIDTHS, [60, 80, 100]).
-define(REFINED_STRESS_IDS, [
    <<"block_arg_match_lambda">>,
    <<"block_arg_lambda">>,
    <<"block_arg_case">>,
    <<"block_arg_receive">>,
    <<"fletrec_bindings_12">>
]).
-define(STRESS_TIMEOUT_MS, 5000).

-spec columns() -> [atom()].
columns() ->
    [id, label, width, time_us, memo_size, calls, tainted, badness, height, bytes, lines].

-spec stress_columns() -> [atom()].
stress_columns() ->
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
    ].

-spec refined_columns() -> [atom()].
refined_columns() ->
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
    ].

%% Resolve + render one sample at one width; return a row map keyed by columns/0.
-spec row(pe_lfe_samples:sample(), non_neg_integer()) -> #{atom() => term()}.
row(Sample, Width) ->
    Dag = pe_lfe_samples:build(Sample),
    Opts = #{width => Width},
    Fun = fun() -> pe:format_binary(Dag, Opts) end,
    TimeUs = best_of(?REPEATS, Fun),
    {Bin, Measure, Stats} = Fun(),
    {Badness, Height} = pe_measure:cost(Measure),
    #{
        id => pe_lfe_samples:id(Sample),
        label => pe_lfe_samples:label(Sample),
        width => Width,
        time_us => TimeUs,
        memo_size => maps:get(memo_size, Stats),
        calls => maps:get(calls, Stats),
        tainted => maps:get(tainted, Stats),
        badness => Badness,
        height => Height,
        bytes => byte_size(Bin),
        lines => count_char(Bin, $\n) + 1
    }.

-spec rows([pe_lfe_samples:sample()], [non_neg_integer()]) -> [#{atom() => term()}].
rows(Samples, Widths) ->
    [row(S, W) || W <- Widths, S <- Samples].

%% Resolve + render one pathological stress row in a monitored worker with a
%% timeout. `dag_size' is `pe_doc:size/1': the frozen hash-consed document-node
%% count. Construction, dag sizing, resolve, render, and metric extraction all
%% run inside the worker timeout boundary.
-spec stress_row(pe_lfe_stress:sample(), non_neg_integer(), timeout()) -> #{atom() => term()}.
stress_row(Sample, Width, TimeoutMs) ->
    Limit = Width,
    Base = #{
        id => pe_lfe_stress:id(Sample),
        label => pe_lfe_stress:label(Sample),
        category => pe_lfe_stress:category(Sample),
        size => pe_lfe_stress:size(Sample),
        width => Width,
        limit => Limit
    },
    Fun = fun() -> stress_metrics(Sample, Width, Limit) end,
    case monitored(Fun, TimeoutMs) of
        {ok, TimeUs, Metrics} ->
            Base#{
                status => ok,
                time_us => TimeUs,
                memo_size => maps:get(memo_size, Metrics),
                calls => maps:get(calls, Metrics),
                tainted => maps:get(tainted, Metrics),
                badness => maps:get(badness, Metrics),
                height => maps:get(height, Metrics),
                bytes => maps:get(bytes, Metrics),
                lines => maps:get(lines, Metrics),
                dag_size => maps:get(dag_size, Metrics)
            };
        timeout ->
            failed_stress_row(Base, timeout);
        {error, Reason} ->
            io:format(
                "stress row error: id=~s width=~b reason=~p~n",
                [pe_lfe_stress:id(Sample), Width, Reason]
            ),
            failed_stress_row(Base, error)
    end.

-spec stress_rows([pe_lfe_stress:sample()], [non_neg_integer()], timeout()) ->
    [#{atom() => term()}].
stress_rows(Samples, Widths, TimeoutMs) ->
    [stress_row(S, W, TimeoutMs) || W <- Widths, S <- Samples].

-spec refined_rows() -> [#{atom() => term()}].
refined_rows() ->
    refined_sample_rows(pe_lfe_samples:all(), ?REFINED_SAMPLE_WIDTHS) ++
        refined_stress_rows(refined_stress_samples(), ?STRESS_WIDTHS, ?STRESS_TIMEOUT_MS).

%% Slice2 baseline mode: widths 80 and 100 -> bench/results/lfe_samples.csv.
-spec run() -> [#{atom() => term()}].
run() ->
    run_to("bench/results/lfe_samples.csv", [80, 100], "real-LFE samples (slice2 baseline shape)").

%% Slice3 knowledge-layer mode: widths 80, 100, and 60 ->
%% bench/results/lfe_knowledge.csv.
-spec run_knowledge() -> [#{atom() => term()}].
run_knowledge() ->
    run_to("bench/results/lfe_knowledge.csv", [80, 100, 60], "LFE knowledge layer (slice3)").

%% Slice4 stress mode: widths 20, 40, 60, 80, 100 ->
%% bench/results/lfe_stress.csv.
-spec run_stress() -> [#{atom() => term()}].
run_stress() ->
    Rows = stress_rows(pe_lfe_stress:all(), ?STRESS_WIDTHS, ?STRESS_TIMEOUT_MS),
    print_stress_table("pathological LFE/S-expression stress corpus (slice4)", Rows),
    print_stress_summary(Rows),
    ok = filelib:ensure_dir("bench/results/"),
    ok = file:write_file("bench/results/lfe_stress.csv", stress_to_csv(Rows)),
    io:format("~nWrote bench/results/lfe_stress.csv (~b rows)~n", [length(Rows)]),
    Rows.

%% Slice5 refined mode: 20 real samples at widths 60, 80, 100 plus affected
%% stress samples at widths 20, 40, 60, 80, 100.
-spec run_refined() -> [#{atom() => term()}].
run_refined() ->
    Rows = refined_rows(),
    print_refined_table("LFE refined layout targets (slice5)", Rows),
    ok = filelib:ensure_dir("bench/results/"),
    ok = file:write_file("bench/results/lfe_refined.csv", refined_to_csv(Rows)),
    io:format("~nWrote bench/results/lfe_refined.csv (~b rows)~n", [length(Rows)]),
    Rows.

run_to(Path, Widths, Title) ->
    Rows = rows(pe_lfe_samples:all(), Widths),
    print_table(Title, Rows),
    ok = filelib:ensure_dir("bench/results/"),
    ok = file:write_file(Path, to_csv(Rows)),
    io:format("~nWrote ~s (~b rows)~n", [Path, length(Rows)]),
    Rows.

%%%-------------------------------------------------------------------
%%% CSV (with minimal escaping for binary fields)
%%%-------------------------------------------------------------------

-spec to_csv([#{atom() => term()}]) -> binary().
to_csv(Rows) ->
    Header = lists:join($,, [atom_to_list(C) || C <- columns()]),
    Lines = [lists:join($,, [field(maps:get(C, R)) || C <- columns()]) || R <- Rows],
    iolist_to_binary([lists:join($\n, [Header | Lines]), $\n]).

-spec stress_to_csv([#{atom() => term()}]) -> binary().
stress_to_csv(Rows) ->
    Header = lists:join($,, [atom_to_list(C) || C <- stress_columns()]),
    Lines = [lists:join($,, [field(maps:get(C, R)) || C <- stress_columns()]) || R <- Rows],
    iolist_to_binary([lists:join($\n, [Header | Lines]), $\n]).

-spec refined_to_csv([#{atom() => term()}]) -> binary().
refined_to_csv(Rows) ->
    Header = lists:join($,, [atom_to_list(C) || C <- refined_columns()]),
    Lines = [lists:join($,, [field(maps:get(C, R)) || C <- refined_columns()]) || R <- Rows],
    iolist_to_binary([lists:join($\n, [Header | Lines]), $\n]).

field(V) when is_atom(V) -> atom_to_list(V);
field(V) when is_integer(V) -> integer_to_list(V);
field(V) when is_binary(V) -> escape_csv(V).

%% Quote a field that contains a comma, quote, or newline; double inner quotes.
escape_csv(Bin) ->
    case binary:match(Bin, [<<",">>, <<"\"">>, <<"\n">>]) of
        nomatch -> Bin;
        _ -> [$", binary:replace(Bin, <<"\"">>, <<"\"\"">>, [global]), $"]
    end.

%%%-------------------------------------------------------------------
%%% Timing (fresh, monitored process per repeat) and reporting
%%%-------------------------------------------------------------------

best_of(N, Fun) ->
    lists:min([run_once(Fun) || _ <- lists:seq(1, N)]).

%% Run Fun in a fresh monitored process; return the elapsed microseconds. A
%% worker crash surfaces as an error here instead of hanging the parent.
run_once(Fun) ->
    {Pid, Ref} = spawn_monitor(fun() -> exit({ok, element(1, timer:tc(Fun))}) end),
    receive
        {'DOWN', Ref, process, Pid, {ok, Time}} -> Time;
        {'DOWN', Ref, process, Pid, Reason} -> error({bench_worker_crashed, Reason})
    end.

%% Run Fun in a monitored worker with an explicit timeout. The result is a
%% tagged value so stress benchmarking can record timeout/error CSV rows and
%% continue with the remaining corpus.
-spec monitored(fun(() -> term()), timeout()) ->
    {ok, non_neg_integer(), term()} | timeout | {error, term()}.
monitored(Fun, TimeoutMs) ->
    {Pid, Ref} = spawn_monitor(fun() -> exit(monitored_result(Fun)) end),
    receive
        {'DOWN', Ref, process, Pid, {ok, TimeUs, Result}} ->
            {ok, TimeUs, Result};
        {'DOWN', Ref, process, Pid, Reason} ->
            {error, Reason}
    after TimeoutMs ->
        exit(Pid, kill),
        receive
            {'DOWN', Ref, process, Pid, _} -> timeout
        end
    end.

monitored_result(Fun) ->
    Start = erlang:monotonic_time(microsecond),
    try Fun() of
        Result ->
            TimeUs = erlang:monotonic_time(microsecond) - Start,
            {ok, TimeUs, Result}
    catch
        Class:Reason ->
            {error, {Class, Reason}}
    end.

print_table(Title, Rows) ->
    io:format("~n== ~s (map backend, limit=width) ==~n", [Title]),
    io:format(
        "~-20s ~5s ~8s ~7s ~7s ~7s ~7s ~6s ~6s ~5s~n",
        [
            "id",
            "width",
            "time_us",
            "memo",
            "calls",
            "tainted",
            "badness",
            "height",
            "bytes",
            "lines"
        ]
    ),
    [
        io:format(
            "~-20s ~5b ~8b ~7b ~7b ~7b ~7b ~6b ~6b ~5b~n",
            [
                atom_to_list(maps:get(id, R)),
                maps:get(width, R),
                maps:get(time_us, R),
                maps:get(memo_size, R),
                maps:get(calls, R),
                maps:get(tainted, R),
                maps:get(badness, R),
                maps:get(height, R),
                maps:get(bytes, R),
                maps:get(lines, R)
            ]
        )
     || R <- Rows
    ],
    ok.

count_char(Bin, Char) ->
    count_char(Bin, Char, 0).

count_char(<<C, Rest/binary>>, C, N) -> count_char(Rest, C, N + 1);
count_char(<<_, Rest/binary>>, C, N) -> count_char(Rest, C, N);
count_char(<<>>, _C, N) -> N.

stress_metrics(Sample, Width, Limit) ->
    Dag = pe_lfe_stress:build(Sample),
    DagSize = pe_doc:size(Dag),
    {Bin, Measure, Stats} = pe:format_binary(Dag, #{width => Width, limit => Limit}),
    {Badness, Height} = pe_measure:cost(Measure),
    #{
        memo_size => maps:get(memo_size, Stats),
        calls => maps:get(calls, Stats),
        tainted => maps:get(tainted, Stats),
        badness => Badness,
        height => Height,
        bytes => byte_size(Bin),
        lines => count_char(Bin, $\n) + 1,
        dag_size => DagSize
    }.

failed_stress_row(Base, Status) ->
    Base#{
        status => Status,
        time_us => 0,
        memo_size => 0,
        calls => 0,
        tainted => 0,
        badness => 0,
        height => 0,
        bytes => 0,
        lines => 0,
        dag_size => 0
    }.

refined_sample_rows(Samples, Widths) ->
    [refined_sample_row(S, W) || W <- Widths, S <- Samples].

refined_sample_row(Sample, Width) ->
    Dag = pe_lfe_samples:build(Sample),
    Opts = #{width => Width, limit => Width},
    Fun = fun() -> pe:format_binary(Dag, Opts) end,
    TimeUs = best_of(?REPEATS, Fun),
    {Bin, Measure, Stats} = Fun(),
    {Badness, Height} = pe_measure:cost(Measure),
    #{
        suite => <<"lfe-sample">>,
        id => pe_lfe_samples:id(Sample),
        label => pe_lfe_samples:label(Sample),
        category => <<"real-sample">>,
        width => Width,
        limit => Width,
        status => ok,
        time_us => TimeUs,
        memo_size => maps:get(memo_size, Stats),
        calls => maps:get(calls, Stats),
        tainted => maps:get(tainted, Stats),
        badness => Badness,
        height => Height,
        bytes => byte_size(Bin),
        lines => count_char(Bin, $\n) + 1,
        dag_size => pe_doc:size(Dag)
    }.

refined_stress_rows(Samples, Widths, TimeoutMs) ->
    [(stress_row(S, W, TimeoutMs))#{suite => <<"stress-affected">>} || W <- Widths, S <- Samples].

refined_stress_samples() ->
    [pe_lfe_stress:by_id(Id) || Id <- ?REFINED_STRESS_IDS].

print_stress_table(Title, Rows) ->
    io:format("~n== ~s (map backend, limit=width, timeout=~bms) ==~n", [Title, ?STRESS_TIMEOUT_MS]),
    io:format(
        "~-22s ~-16s ~5s ~5s ~8s ~7s ~7s ~7s ~7s ~10s ~6s ~6s ~5s~n",
        [
            "id",
            "category",
            "width",
            "limit",
            "status",
            "time_us",
            "memo",
            "calls",
            "tainted",
            "bad",
            "height",
            "dag",
            "lines"
        ]
    ),
    [
        io:format(
            "~-22s ~-16s ~5b ~5b ~8s ~7b ~7b ~7b ~7b ~10b ~6b ~6b ~5b~n",
            [
                maps:get(id, R),
                maps:get(category, R),
                maps:get(width, R),
                maps:get(limit, R),
                atom_to_list(maps:get(status, R)),
                maps:get(time_us, R),
                maps:get(memo_size, R),
                maps:get(calls, R),
                maps:get(tainted, R),
                maps:get(badness, R),
                maps:get(height, R),
                maps:get(dag_size, R),
                maps:get(lines, R)
            ]
        )
     || R <- Rows
    ],
    ok.

print_stress_summary(Rows) ->
    io:format("~n== stress worst rows (stable counters first) ==~n", []),
    print_top(calls, Rows),
    print_top(memo_size, Rows),
    print_top(tainted, Rows),
    print_top(badness, Rows),
    StatusRows = [R || R <- Rows, maps:get(status, R) =/= ok],
    case StatusRows of
        [] ->
            io:format("status: no timeout/error rows~n", []);
        _ ->
            io:format("status rows:~n", []),
            [print_summary_row(R) || R <- StatusRows]
    end.

print_top(Key, Rows) ->
    Sorted = lists:sublist(
        lists:sort(fun(A, B) -> maps:get(Key, A) >= maps:get(Key, B) end, Rows),
        5
    ),
    io:format("~p top:~n", [Key]),
    [print_summary_row(R) || R <- Sorted].

print_summary_row(R) ->
    io:format(
        "  id=~s width=~b status=~p calls=~b memo=~b tainted=~b badness=~b dag=~b~n",
        [
            maps:get(id, R),
            maps:get(width, R),
            maps:get(status, R),
            maps:get(calls, R),
            maps:get(memo_size, R),
            maps:get(tainted, R),
            maps:get(badness, R),
            maps:get(dag_size, R)
        ]
    ).

print_refined_table(Title, Rows) ->
    io:format("~n== ~s (map backend, limit=width) ==~n", [Title]),
    io:format(
        "~-16s ~-22s ~5s ~8s ~7s ~7s ~7s ~10s ~6s ~6s ~5s~n",
        [
            "suite",
            "id",
            "width",
            "time_us",
            "memo",
            "calls",
            "tainted",
            "bad",
            "height",
            "dag",
            "lines"
        ]
    ),
    [
        io:format(
            "~-16s ~-22s ~5b ~8b ~7b ~7b ~7b ~10b ~6b ~6b ~5b~n",
            [
                maps:get(suite, R),
                id_to_binary(maps:get(id, R)),
                maps:get(width, R),
                maps:get(time_us, R),
                maps:get(memo_size, R),
                maps:get(calls, R),
                maps:get(tainted, R),
                maps:get(badness, R),
                maps:get(height, R),
                maps:get(dag_size, R),
                maps:get(lines, R)
            ]
        )
     || R <- Rows
    ],
    ok.

id_to_binary(Id) when is_atom(Id) ->
    atom_to_binary(Id, utf8);
id_to_binary(Id) when is_binary(Id) ->
    Id.
