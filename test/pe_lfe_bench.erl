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
    monitored/2,
    files_columns/0,
    files_row/3,
    files_to_csv/1,
    run_files/0
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
-define(FILES_WIDTHS, [60, 80, 100]).
-define(FILES_TIMEOUT_MS, 30000).

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
%%% Slice6 lfe-files mode: real whole-file formatter latency
%%%-------------------------------------------------------------------

-spec files_columns() -> [atom()].
files_columns() ->
    [
        file,
        width,
        status,
        n_forms,
        bytes,
        lines,
        parse_us,
        fmt_us,
        worst_form_us,
        worst_form_index,
        worst_form_head,
        memo_size,
        calls,
        tainted,
        badness,
        dag_size,
        genericised
    ].

%% Whole-file latency for one reference file at one width, in a monitored worker
%% with a generous timeout. The headline metric is `fmt_us' = Σ(per-form
%% pe_lfe:format_binary); `parse_us' (read+convert) is timed separately. A read,
%% convert, or format failure becomes a status row — never a hang, never an
%% aborted run.
-spec files_row(file:name_all(), non_neg_integer(), timeout()) -> #{atom() => term()}.
files_row(Path, Width, TimeoutMs) ->
    Base = #{file => list_to_binary(filename:basename(Path)), width => Width},
    case monitored(fun() -> file_metrics(Path, Width) end, TimeoutMs) of
        {ok, _WorkerUs, Metrics} ->
            maps:merge(Base#{status => ok}, Metrics);
        timeout ->
            failed_files_row(Base, timeout);
        {error, Reason} ->
            io:format("lfe-files error: ~s width=~b reason=~p~n", [
                filename:basename(Path), Width, Reason
            ]),
            failed_files_row(Base, error)
    end.

%% Read+convert (timed as parse_us), then format every top-level form (each
%% timed; summed as fmt_us), aggregating stable counters and tracking the worst
%% single form.
file_metrics(Path, Width) ->
    T0 = erlang:monotonic_time(microsecond),
    {ok, Forms} = pe_lfe_read:read_file(Path),
    ParseUs = erlang:monotonic_time(microsecond) - T0,
    Indexed = lists:zip(lists:seq(1, length(Forms)), Forms),
    PerForm = [form_metrics(Index, Form, Width) || {Index, Form} <- Indexed],
    Worst = worst_by(time_us, PerForm),
    #{
        n_forms => length(Forms),
        bytes => sum(bytes, PerForm),
        lines => sum(lines, PerForm),
        parse_us => ParseUs,
        fmt_us => sum(time_us, PerForm),
        worst_form_us => get0(time_us, Worst),
        worst_form_index => get0(index, Worst),
        worst_form_head => get_head(Worst),
        memo_size => sum(memo_size, PerForm),
        calls => sum(calls, PerForm),
        tainted => sum(tainted, PerForm),
        badness => sum(badness, PerForm),
        dag_size => sum(dag_size, PerForm),
        genericised => length([1 || M <- PerForm, maps:get(genericised, M)])
    }.

%% Per-form metrics. `time_us' covers pe_lfe:format_binary (lower+resolve+render)
%% so it sums to the whole-file fmt_us; dag size is taken separately (untimed).
form_metrics(Index, Form, Width) ->
    Opts = #{width => Width},
    Start = erlang:monotonic_time(microsecond),
    {Bin, Measure, Stats, Genericised} = pe_lfe_read:safe_format_binary(Form, Opts),
    TimeUs = erlang:monotonic_time(microsecond) - Start,
    {Badness, _Height} = pe_measure:cost(Measure),
    #{
        index => Index,
        head => form_head(Form),
        time_us => TimeUs,
        bytes => byte_size(Bin),
        lines => count_char(Bin, $\n) + 1,
        memo_size => maps:get(memo_size, Stats),
        calls => maps:get(calls, Stats),
        tainted => maps:get(tainted, Stats),
        badness => Badness,
        dag_size => safe_dag_size(Form),
        genericised => Genericised
    }.

%% The head symbol of a form, for diagnostics (which form dominates).
form_head({call, [{sym, H} | _]}) -> H;
form_head({call, _}) -> <<"(call)">>;
form_head({Tag, _}) when is_atom(Tag) -> atom_to_binary(Tag, utf8);
form_head(_) -> <<"?">>.

safe_dag_size(Form) ->
    try pe_doc:size(pe_lfe:to_doc(Form)) of
        N -> N
    catch
        _:_ -> pe_doc:size(pe_lfe:to_doc(pe_lfe_read:genericize(Form)))
    end.

sum(Key, Maps) -> lists:sum([maps:get(Key, M) || M <- Maps]).

worst_by(_Key, []) -> undefined;
worst_by(Key, [M | Ms]) -> worst_by(Key, Ms, M).
worst_by(_Key, [], Best) -> Best;
worst_by(Key, [M | Ms], Best) ->
    case maps:get(Key, M) > maps:get(Key, Best) of
        true -> worst_by(Key, Ms, M);
        false -> worst_by(Key, Ms, Best)
    end.

get0(_Key, undefined) -> 0;
get0(Key, Map) -> maps:get(Key, Map).

get_head(undefined) -> <<"-">>;
get_head(Map) -> maps:get(head, Map).

failed_files_row(Base, Status) ->
    maps:merge(Base#{status => Status}, #{
        n_forms => 0,
        bytes => 0,
        lines => 0,
        parse_us => 0,
        fmt_us => 0,
        worst_form_us => 0,
        worst_form_index => 0,
        worst_form_head => <<"-">>,
        memo_size => 0,
        calls => 0,
        tainted => 0,
        badness => 0,
        dag_size => 0,
        genericised => 0
    }).

%% cl.lfe, clj.lfe, and the test/*.lfe suites of the test-profile lfe dep.
file_paths() ->
    Dir = code:lib_dir(lfe),
    Core = [filename:join([Dir, "src", F]) || F <- ["cl.lfe", "clj.lfe"]],
    Tests = lists:sort(filelib:wildcard(filename:join([Dir, "test", "*.lfe"]))),
    [P || P <- Core ++ Tests, filelib:is_regular(P)].

-spec files_to_csv([#{atom() => term()}]) -> binary().
files_to_csv(Rows) ->
    Header = lists:join($,, [atom_to_list(C) || C <- files_columns()]),
    Lines = [lists:join($,, [field(maps:get(C, R)) || C <- files_columns()]) || R <- Rows],
    iolist_to_binary([lists:join($\n, [Header | Lines]), $\n]).

-spec run_files() -> [#{atom() => term()}].
run_files() ->
    Rows = [
        files_row(Path, Width, ?FILES_TIMEOUT_MS)
     || Width <- ?FILES_WIDTHS, Path <- file_paths()
    ],
    print_files_table("real LFE whole-file latency (slice6)", Rows),
    ok = filelib:ensure_dir("bench/results/"),
    ok = file:write_file("bench/results/lfe_files.csv", files_to_csv(Rows)),
    io:format("~nWrote bench/results/lfe_files.csv (~b rows)~n", [length(Rows)]),
    Rows.

print_files_table(Title, Rows) ->
    io:format("~n== ~s (map backend, limit=width, timeout=~bms) ==~n", [Title, ?FILES_TIMEOUT_MS]),
    io:format(
        "~-22s ~5s ~8s ~6s ~9s ~9s ~9s ~7s ~8s ~6s~n",
        ["file", "width", "status", "forms", "parse_us", "fmt_us", "worst_us", "tainted", "dag", "genrc"]
    ),
    [
        io:format(
            "~-22s ~5b ~8s ~6b ~9b ~9b ~9b ~7b ~8b ~6b~n",
            [
                maps:get(file, R),
                maps:get(width, R),
                atom_to_list(maps:get(status, R)),
                maps:get(n_forms, R),
                maps:get(parse_us, R),
                maps:get(fmt_us, R),
                maps:get(worst_form_us, R),
                maps:get(tainted, R),
                maps:get(dag_size, R),
                maps:get(genericised, R)
            ]
        )
     || R <- Rows
    ],
    ok.

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
