%%% @doc arc2/slice1 gate — the AST round-trip over the real LFE corpus.
%%%
%%% For every top-level form `F' of `examples/*.lfe' + `test/*.lfe' + cl/clj.lfe
%%% (located via `code:lib_dir(lfe)'): `format' it, re-read the text with the
%%% faithful reader, and assert the re-read form is **structurally equal** to
%%% `F' (`read ∘ format ≡ read' — formatting preserves meaning, and the output
%%% is valid re-readable LFE). Plus the completeness gate: **0
%%% `unmodeled_construct'** across the corpus.
-module(pe_lfe_roundtrip_tests).

-include_lib("eunit/include/eunit.hrl").

-export([audit/0]).

-define(WIDTH, 80).

corpus_files() ->
    Dir = code:lib_dir(lfe),
    Examples = filelib:wildcard(filename:join([Dir, "examples", "*.lfe"])),
    Tests = filelib:wildcard(filename:join([Dir, "test", "*.lfe"])),
    Core = [filename:join([Dir, "src", F]) || F <- ["cl.lfe", "clj.lfe"]],
    [P || P <- Examples ++ Tests ++ Core, filelib:is_regular(P)].

%% Round-trip one form: format -> re-read -> structural compare.
roundtrip_form(Form) ->
    {Bin, _M, _S} = pe_lfe:format_binary(Form, #{width => ?WIDTH}),
    {ok, [Sexpr]} = lfe_io:read_string(binary_to_list(Bin)),
    {Form =:= pe_lfe_read:convert(Sexpr), Bin}.

%%%-------------------------------------------------------------------
%%% Audit (callable directly for diagnosis; returns a report)
%%%-------------------------------------------------------------------

-doc """
Audit the whole corpus. Returns `#{forms, ok, unmodeled, mismatches}' where
`unmodeled' is a list of `{File, Term}' (reader completeness misses) and
`mismatches' a list of `{File, Line, Form, Rendered}' (forms that did not
round-trip structurally).
""".
-spec audit() -> map().
audit() ->
    lists:foldl(
        fun audit_file/2, #{forms => 0, ok => 0, unmodeled => [], mismatches => []}, corpus_files()
    ).

audit_file(File, Acc) ->
    try pe_lfe_read:read_forms(File) of
        {ok, FormLines} -> audit_forms(File, FormLines, Acc)
    catch
        error:{unmodeled_construct, T} ->
            maps:update_with(unmodeled, fun(U) -> [{File, T} | U] end, Acc)
    end.

audit_forms(File, FormLines, Acc) ->
    lists:foldl(
        fun({Form, Line}, A) ->
            A1 = maps:update_with(forms, fun(N) -> N + 1 end, A),
            try roundtrip_form(Form) of
                {true, _Bin} ->
                    maps:update_with(ok, fun(N) -> N + 1 end, A1);
                {false, Bin} ->
                    maps:update_with(
                        mismatches, fun(M) -> [{File, Line, Form, Bin} | M] end, A1
                    )
            catch
                C:R:St ->
                    maps:update_with(
                        mismatches,
                        fun(M) -> [{File, Line, {crash, C, R, St}, Form} | M] end,
                        A1
                    )
            end
        end,
        Acc,
        FormLines
    ).

%%%-------------------------------------------------------------------
%%% Gates
%%%-------------------------------------------------------------------

%% A2S1-8/9/10: corpus round-trips structurally with 0 unmodeled constructs.
corpus_round_trip_test_() ->
    {timeout, 300, fun() ->
        #{forms := Forms, ok := Ok, unmodeled := Unmodeled, mismatches := Mismatches} = audit(),
        ?assert(Forms > 0),
        ?assertEqual({unmodeled, []}, {unmodeled, [{basename(F), T} || {F, T} <- Unmodeled]}),
        ?assertEqual(
            {mismatches, []}, {mismatches, [{basename(F), L} || {F, L, _Form, _R} <- Mismatches]}
        ),
        ?assertEqual(Forms, Ok)
    end}.

basename(F) -> list_to_binary(filename:basename(F)).

%%%-------------------------------------------------------------------
%%% A2S1-11: cheap idempotence spot-check (full harness is slice3)
%%%-------------------------------------------------------------------

idempotence_spot_check_test() ->
    Dir = code:lib_dir(lfe),
    File = filename:join([Dir, "examples", "church.lfe"]),
    {ok, Forms} = pe_lfe_read:read_file(File),
    lists:foreach(
        fun(Form) ->
            {Bin1, _, _} = pe_lfe:format_binary(Form, #{width => ?WIDTH}),
            %% re-read the formatted text and format again — output must be stable.
            {ok, [Sexpr]} = lfe_io:read_string(binary_to_list(Bin1)),
            {Bin2, _, _} = pe_lfe:format_binary(pe_lfe_read:convert(Sexpr), #{width => ?WIDTH}),
            ?assertEqual(Bin1, Bin2)
        end,
        Forms
    ).
