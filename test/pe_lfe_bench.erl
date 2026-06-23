%%% @doc Real-LFE sample benchmark (test-only): resolve+render the 20 fixtures
%%% at widths 80 and 100 and report timing, memo/call/taint stats, and rendered
%%% size. Produces numbers for CDC/operator; draws no conclusion.
%%%
%%% Timing uses `timer:tc/1' (monotonic on modern OTP), best-of-N, with each
%%% repeat run in a fresh process to suppress shared-heap/GC skew (PF-03).
-module(pe_lfe_bench).

-export([columns/0, row/2, rows/2, to_csv/1, run/0]).

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

%% All samples × all widths.
-spec rows([pe_lfe_samples:sample()], [non_neg_integer()]) -> [#{atom() => term()}].
rows(Samples, Widths) ->
    [row(S, W) || W <- Widths, S <- Samples].

%% Run the full sweep, print a table, and write the CSV.
-spec run() -> [#{atom() => term()}].
run() ->
    Rows = rows(pe_lfe_samples:all(), [80, 100]),
    print_table(Rows),
    ok = filelib:ensure_dir("bench/results/"),
    ok = file:write_file("bench/results/lfe_samples.csv", to_csv(Rows)),
    io:format("~nWrote bench/results/lfe_samples.csv (~b rows)~n", [length(Rows)]),
    Rows.

%%%-------------------------------------------------------------------
%%% CSV
%%%-------------------------------------------------------------------

-spec to_csv([#{atom() => term()}]) -> binary().
to_csv(Rows) ->
    Header = lists:join(",", [atom_to_list(C) || C <- columns()]),
    Lines = [lists:join(",", [field(maps:get(C, R)) || C <- columns()]) || R <- Rows],
    iolist_to_binary([lists:join("\n", [Header | Lines]), "\n"]).

field(V) when is_atom(V) -> atom_to_list(V);
field(V) when is_integer(V) -> integer_to_list(V);
field(V) when is_binary(V) -> binary_to_list(V).

%%%-------------------------------------------------------------------
%%% Timing (fresh process per repeat) and reporting
%%%-------------------------------------------------------------------

best_of(N, Fun) ->
    lists:min([run_once(Fun) || _ <- lists:seq(1, N)]).

run_once(Fun) ->
    Parent = self(),
    Ref = make_ref(),
    _ = spawn(fun() ->
        {Time, _Result} = timer:tc(Fun),
        Parent ! {Ref, Time}
    end),
    receive
        {Ref, Time} -> Time
    end.

print_table(Rows) ->
    io:format("~n== real-LFE sample benchmark (map backend, limit=width) ==~n", []),
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
    length([c || <<C>> <= Bin, C =:= Char]).
