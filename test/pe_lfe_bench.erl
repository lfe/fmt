%%% @doc Real-LFE sample benchmark (test-only): resolve+render the 20 fixtures
%%% — now lowered through the {@link pe_lfe} knowledge layer — and report
%%% timing, memo/call/taint stats, and rendered size. Numbers for CDC/operator;
%%% draws no conclusion.
%%%
%%% Timing uses `timer:tc/1' (monotonic on modern OTP), best-of-N, with each
%%% repeat in a fresh, monitored process so a crashing worker reports an error
%%% instead of hanging the parent (A1-R009).
-module(pe_lfe_bench).

-export([columns/0, row/2, rows/2, to_csv/1, run/0, run_knowledge/0]).

-define(REPEATS, 5).

-spec columns() -> [atom()].
columns() ->
    [id, label, width, time_us, memo_size, calls, tainted, badness, height, bytes, lines].

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

%% Slice2 baseline mode: widths 80 and 100 -> bench/results/lfe_samples.csv.
-spec run() -> [#{atom() => term()}].
run() ->
    run_to("bench/results/lfe_samples.csv", [80, 100], "real-LFE samples (slice2 baseline shape)").

%% Slice3 knowledge-layer mode: widths 80, 100, and 60 ->
%% bench/results/lfe_knowledge.csv.
-spec run_knowledge() -> [#{atom() => term()}].
run_knowledge() ->
    run_to("bench/results/lfe_knowledge.csv", [80, 100, 60], "LFE knowledge layer (slice3)").

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

print_table(Title, Rows) ->
    io:format("~n== ~s (map backend, limit=width) ==~n", [Title]),
    io:format(
        "~-20s ~5s ~8s ~7s ~7s ~7s ~7s ~6s ~6s ~5s~n",
        ["id", "width", "time_us", "memo", "calls", "tainted", "badness", "height", "bytes", "lines"]
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
