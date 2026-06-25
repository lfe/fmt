%%% @doc EUnit for the differential-oracle wire format (`pe_oracle_mjl:serialize/1')
%%% and the from-string cost recompute (`recompute/2'). The wire is the Erlang
%%% half of the oracle; the Rust `pe-oracle' binary is the parsing half, and the
%%% end-to-end round-trip (serialise -> Rust parse -> render == our render) is
%%% proven over the corpus by `pe_oracle_mjl:run/1'. These tests pin the
%%% serialiser's shape and escaping for every node of the algebra so a wire
%%% regression is caught without the Rust toolchain (A1S8-14).
-module(pe_wire_tests).

-include_lib("eunit/include/eunit.hrl").

wire(Sym) ->
    {Root, B} = pe_gen:build_sym(Sym, pe_doc:new()),
    iolist_to_binary(pe_oracle_mjl:serialize(pe_doc:freeze(B, Root))).

t(S) -> {text, list_to_binary(S)}.

%%%-------------------------------------------------------------------
%%% Leaves
%%%-------------------------------------------------------------------

text_leaf_test() -> ?assertEqual(<<"(t \"abc\")">>, wire(t("abc"))).
empty_text_test() -> ?assertEqual(<<"(t \"\")">>, wire(t(""))).
nl_test() -> ?assertEqual(<<"(nl)">>, wire(nl)).
brk_test() -> ?assertEqual(<<"(brk)">>, wire(brk)).
hard_nl_test() -> ?assertEqual(<<"(hnl)">>, wire(hard_nl)).
fail_test() -> ?assertEqual(<<"(fail)">>, wire(fail)).

%% ASCII `"' and `\' are escaped so the Rust string parser round-trips them.
escaping_test() ->
    ?assertEqual(<<"(t \"a\\\"b\\\\c\")">>, wire(t("a\"b\\c"))).

%%%-------------------------------------------------------------------
%%% Combinators (built through the smart constructors, so the operands are
%%% chosen to survive normalisation — e.g. text+nl does not merge).
%%%-------------------------------------------------------------------

concat_test() ->
    ?assertEqual(<<"(cat (t \"a\") (nl))">>, wire({concat, t("a"), nl})).

nest_test() ->
    ?assertEqual(<<"(nest 2 (cat (t \"a\") (nl)))">>, wire({nest, 2, {concat, t("a"), nl}})).

align_test() ->
    ?assertEqual(<<"(align (cat (t \"a\") (nl)))">>, wire({align, {concat, t("a"), nl}})).

reset_test() ->
    ?assertEqual(<<"(reset (cat (t \"a\") (nl)))">>, wire({reset, {concat, t("a"), nl}})).

cost_test() ->
    ?assertEqual(<<"(cost 0 2 (cat (t \"a\") (nl)))">>, wire({cost, {0, 2}, {concat, t("a"), nl}})).

choice_test() ->
    ?assertEqual(<<"(alt (t \"a\") (nl))">>, wire({choice, t("a"), nl})).

%% group(d) = choice(flatten(d), d); flatten(text"a" & nl) = "a ".
group_test() ->
    ?assertEqual(<<"(alt (t \"a \") (cat (t \"a\") (nl)))">>, wire({group, {concat, t("a"), nl}})).

%%%-------------------------------------------------------------------
%%% recompute/2: canonical {Badness, Height} from a rendered string
%%%-------------------------------------------------------------------

recompute_flat_test() ->
    %% one line, no overflow at width 80.
    ?assertEqual({0, 0}, pe_oracle_mjl:recompute(<<"hello">>, 80)).

recompute_overflow_test() ->
    %% "abc" over width 2 overflows by 1 => badness 1, no newline.
    ?assertEqual({1, 0}, pe_oracle_mjl:recompute(<<"abc">>, 2)).

recompute_multiline_test() ->
    %% "abc\nde" at width 2: line1 over by 1 (badness 1), line2 fits; 1 newline.
    ?assertEqual({1, 1}, pe_oracle_mjl:recompute(<<"abc\nde">>, 2)),
    %% badness sums squared per-line overflow: "abcd"(2 over => 4) + "ef"(0).
    ?assertEqual({4, 1}, pe_oracle_mjl:recompute(<<"abcd\nef">>, 2)).
