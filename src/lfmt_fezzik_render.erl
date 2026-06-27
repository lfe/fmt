%%%% lfmt_fezzik_render: the mutually-recursive rendering core (one SCC).
%%%% Layer: render depends on util (one-way); fezzik calls print_node/3 here.
-module(lfmt_fezzik_render).

-include("lfmt_fezzik.hrl").

-export([print_node/3]).


%%====================================================================
%% Internal: main printer — flat vs broken decision
%%====================================================================


%% print_node: print a node starting at column Col.
%% Returns {IO, NewCol} where NewCol is the column after the last printed char.
%% Flat if: no multi-line token, fits in WIDTH, and no trivia that would be
%% lost in flat mode (dangling on this node, or any trivia on any descendant).
%% The node's own leading/trailing are always emitted by the parent context and
%% do NOT prevent flat rendering.
%% InData: true when inside a quote/quasiquote context (data, not code).
-spec print_node(lfmt_fezzik_cst:cst_node(), non_neg_integer(), boolean()) ->
          {iolist(), non_neg_integer()}.
print_node(Node, Col, InData) ->
    W = lfmt_fezzik_util:flat_width(Node),
    Fits = W =/= infinity
           andalso Col + W =< ?WIDTH
           andalso not lfmt_fezzik_util:has_internal_trivia(Node),
    case Fits of
        true  -> {lfmt_fezzik_util:flat_render(Node), Col + W};
        false -> print_broken(Node, Col, InData)
    end.


%%====================================================================
%% Internal: broken printing
%%====================================================================

%% print_broken: broken form for containers, prefixed, and multi-line leaves.
%% Transitions InData at quote/quasiquote (→ true) and unquote/-splicing (→ false).
-spec print_broken(lfmt_fezzik_cst:cst_node(), non_neg_integer(), boolean()) ->
          {iolist(), non_neg_integer()}.
print_broken(Node, Col, InData) ->
    case lfmt_fezzik_cst:type(Node) of
        T when T =:= list; T =:= tuple; T =:= map; T =:= binary; T =:= eval ->
            print_broken_container(Node, Col, InData);
        prefixed ->
            PfxText = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:prefix(Node)),
            PfxKind = lfmt_fezzik_lexer:kind(lfmt_fezzik_cst:prefix(Node)),
            [Inner]  = lfmt_fezzik_cst:children(Node),
            InnerInData = case PfxKind of
                quote            -> true;
                quasiquote       -> true;
                unquote          -> false;
                unquote_splicing -> false;
                _                -> InData
            end,
            {InnerIO, InnerCol} = print_node(Inner, Col + length(PfxText), InnerInData),
            {[PfxText, InnerIO], InnerCol};
        _ ->
            %% Leaf with multi-line token (tqstring/tqbstring): emit verbatim.
            Text = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Node)),
            {Text, lfmt_fezzik_util:col_after_text(Text, Col)}
    end.


%% print_broken_container: branches on regime/2 (A7·S2b-2).
%%   canonical        → head-classified indentation (A4) + map pair alignment (S3a)
%%   break_preserving → author break positions preserved (A7·S2b)
%%
%% Dangling trivia always at C+2; close on its own line when dangling present
%% or last child has trailing comment. All A3 trivia rules unchanged.
-spec print_broken_container(lfmt_fezzik_cst:cst_node(), non_neg_integer(),
                             boolean()) ->
          {iolist(), non_neg_integer()}.
print_broken_container(Node, C, InData) ->
    Open      = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Node)),
    Close     = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:close(Node)),
    Children  = lfmt_fezzik_cst:children(Node),
    Dangling  = lfmt_fezzik_cst:dangling(Node),
    Indent    = C + 2,
    IndentStr = lists:duplicate(Indent, $\s),
    CIndStr   = lists:duplicate(C, $\s),
    CloseLen  = length(Close),
    OpenLen   = length(Open),
    case Children of
        [] ->
            case Dangling of
                [] ->
                    {[Open, Close], C + OpenLen + CloseLen};
                _ ->
                    DangIO = lfmt_fezzik_util:emit_dangling(Dangling, IndentStr),
                    {[Open, DangIO, "\n", CIndStr, Close], C + CloseLen}
            end;
        [Head | RestChildren] ->
            case lfmt_fezzik_util:regime(Node, InData) of
                canonical ->
                    case lfmt_fezzik_util:head_has_leading_comment(Head) of
                        true ->
                            %% Opener alone; all children at Indent (fix1 idempotency).
                            {AllIO, LastCol, HasTrail} =
                                print_rest_loop([Head | RestChildren],
                                                Indent, IndentStr, true, InData),
                            {CloseIO, CloseCol} =
                                lfmt_fezzik_util:close_section(Dangling, HasTrail, LastCol,
                                              Indent, IndentStr, C, CIndStr, Close),
                            {[Open, AllIO, CloseIO], CloseCol};
                        false ->
                            case lfmt_fezzik_cst:type(Node) of
                                T when T =:= list; T =:= eval ->
                                    Class = lfmt_fezzik_util:classify_head(Head),
                                    print_classified(Class, Head, RestChildren, Dangling,
                                                     C, Open, OpenLen, Close, CloseLen,
                                                     Indent, IndentStr, CIndStr, InData);
                                map ->
                                    print_map_pairs(Head, RestChildren, Dangling,
                                                    C, Open, OpenLen, Close, CloseLen,
                                                    Indent, IndentStr, CIndStr, InData)
                            end
                    end;
                break_preserving ->
                    print_bp_container(Node, C, Open, OpenLen, Close, CloseLen,
                                       Head, RestChildren, Dangling,
                                       Indent, IndentStr, CIndStr, InData)
            end
    end.


%%====================================================================
%% Internal: break-preserving renderer (A7·S2b-2)
%%====================================================================

%% print_bp_container: render a break-preserving container.
%%
%% Flat path is already handled by print_node (tried before print_broken is called).
%% Here we are in the broken path.
%%
%% If Head has a leading comment: opener alone, all children (incl. Head) via
%% print_rest_loop at Indent — comment safety (same as canonical fix1 path).
%%
%% Otherwise:
%%   - If nl_before(Head)=true: head on new line at C+2, AlignCol=C+2.
%%   - Else: head on opener line at C+OpenLen.
%%     AlignCol = column of first argument:
%%       - If first arg has nl_before or head has trailing comment → C+2 (hanging).
%%       - Else → HTC+1 (align under first arg).
%%
%% Subsequent children via bp_rest_loop: new line if nl_before OR overflow OR
%% has leading comment; otherwise space-separated on current line.
%% Close hugs last child unless dangling or last-child trailing comment.
-spec print_bp_container(lfmt_fezzik_cst:cst_node(),
                         non_neg_integer(), string(), non_neg_integer(),
                         string(), non_neg_integer(),
                         lfmt_fezzik_cst:cst_node(), [lfmt_fezzik_cst:cst_node()],
                         [lfmt_fezzik_cst:trivia()],
                         non_neg_integer(), string(), string(), boolean()) ->
          {iolist(), non_neg_integer()}.
print_bp_container(Node, C, Open, _OpenLen, Close, _CloseLen,
                   Head, RestChildren, Dangling,
                   Indent, IndentStr, CIndStr, InData) ->
    DotTok = lfmt_fezzik_cst:dot_token(Node),
    {RestBody, MaybeTail} = lfmt_fezzik_util:split_dot_tail(DotTok, RestChildren),
    IsCondHead = (lfmt_fezzik_cst:type(Head) =:= symbol)
        andalso (lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)) =:= "cond"),
    case lfmt_fezzik_util:head_has_leading_comment(Head) of
        true ->
            case InData of
                false ->
                    %% Code list: opener-alone, all children one-per-line at Indent (unchanged).
                    {AllIO, LastCol, HasTrail} =
                        print_rest_loop([Head | RestBody], Indent, IndentStr, true, InData),
                    {DotIO, DotCol, DotHasTrail} =
                        lfmt_fezzik_util:apply_dot_suffix(MaybeTail, LastCol, HasTrail),
                    {CloseIO, CloseCol} =
                        lfmt_fezzik_util:close_section(Dangling, DotHasTrail, DotCol,
                                      Indent, IndentStr, C, CIndStr, Close),
                    {[Open, AllIO, DotIO, CloseIO], CloseCol};
                true ->
                    %% Data list (§3.9): first head comment on opener line; rest +
                    %% elements at AlignCol = C+len(Open).
                    AlignCol  = C + length(Open),
                    AlignStr  = lists:duplicate(AlignCol, $\s),
                    HeadLeading = lfmt_fezzik_cst:leading(Head),
                    Comments  = [lfmt_fezzik_lexer:text(Tok)
                                 || {comment, Tok} <- HeadLeading],
                    HeadLeadIO =
                        case Comments of
                            [] ->
                                [];
                            [First | More] ->
                                MoreIO = [[AlignStr, T, "\n"] || T <- More],
                                [First, "\n" | MoreIO]
                        end,
                    {HeadIO, HeadCol}  = print_node(Head, AlignCol, InData),
                    {HeadTrailIO, HTC} = lfmt_fezzik_util:emit_trailing(
                                           lfmt_fezzik_cst:trailing(Head), HeadCol),
                    {RestIO, BodyLastCol, BodyHasTrail} =
                        bp_rest_loop(RestBody, AlignCol, AlignStr, HTC, InData),
                    {DotIO, DotCol, DotHasTrail} =
                        lfmt_fezzik_util:apply_dot_suffix(MaybeTail, BodyLastCol, BodyHasTrail),
                    {CloseIO, CloseCol} =
                        lfmt_fezzik_util:close_section(Dangling, DotHasTrail, DotCol,
                                      AlignCol, AlignStr, C, CIndStr, Close),
                    {[Open, HeadLeadIO, AlignStr, HeadIO, HeadTrailIO,
                      RestIO, DotIO, CloseIO], CloseCol}
            end;
        false ->
            HeadLeadIO = lfmt_fezzik_util:emit_head_leading(lfmt_fezzik_cst:leading(Head), CIndStr),
            HeadCol    = C + length(Open),
            case lfmt_fezzik_cst:nl_before(Head) of
                true ->
                    %% Head on new line at C+2; all args also at C+2.
                    HangStr = IndentStr,
                    {HeadIO, HCol}       = print_node(Head, Indent, InData),
                    {HeadTrailIO, HTC}   = lfmt_fezzik_util:emit_trailing(
                                             lfmt_fezzik_cst:trailing(Head), HCol),
                    {RestIO, BodyLastCol, BodyHasTrail} =
                        case IsCondHead of
                            true  -> bp_clause_rest_loop(RestBody, Indent, HangStr, HTC, InData);
                            false -> bp_rest_loop(RestBody, Indent, HangStr, HTC, InData)
                        end,
                    {DotIO, DotCol, DotHasTrail} =
                        lfmt_fezzik_util:apply_dot_suffix(MaybeTail, BodyLastCol, BodyHasTrail),
                    {CloseIO, CloseCol}  =
                        lfmt_fezzik_util:close_section(Dangling, DotHasTrail, DotCol,
                                      Indent, HangStr, C, CIndStr, Close),
                    {[HeadLeadIO, Open, "\n", HangStr, HeadIO, HeadTrailIO,
                      RestIO, DotIO, CloseIO], CloseCol};
                false ->
                    {HeadIO, HCol}       = print_node(Head, HeadCol, InData),
                    {HeadTrailIO, HTC}   = lfmt_fezzik_util:emit_trailing(
                                             lfmt_fezzik_cst:trailing(Head), HCol),
                    HeadHasTrail = lfmt_fezzik_cst:trailing(Head) =/= [],
                    case RestBody of
                        [] ->
                            {DotIO, DotCol, DotHasTrail} =
                                lfmt_fezzik_util:apply_dot_suffix(MaybeTail, HTC, HeadHasTrail),
                            {CloseIO, CloseCol} =
                                lfmt_fezzik_util:close_section(Dangling, DotHasTrail, DotCol,
                                              Indent, IndentStr, C, CIndStr, Close),
                            {[HeadLeadIO, Open, HeadIO, HeadTrailIO, DotIO, CloseIO], CloseCol};
                        [FirstArg | OtherArgs] ->
                            %% AlignCol = column where first arg lands.
                            %% Hanging (C+2) when: head has trailing comment, first arg
                            %% has nl_before, OR first arg would overflow the current line.
                            %% "Overflow" here uses >= so a token at exactly col 80
                            %% triggers wrapping (col 80 = 81st char on the line, over limit).
                            FirstArgNL = lfmt_fezzik_cst:nl_before(FirstArg),
                            FirstArgW  = lfmt_fezzik_util:flat_width(FirstArg),
                            FirstArgOverflows =
                                FirstArgW =:= infinity
                                orelse HTC + 1 + FirstArgW >= ?WIDTH,
                            {AlignCol, AlignStr} =
                                case HeadHasTrail orelse FirstArgNL orelse FirstArgOverflows of
                                    true  -> {Indent, IndentStr};
                                    false -> {HTC + 1, lists:duplicate(HTC + 1, $\s)}
                                end,
                            IsMultiline = lfmt_fezzik_cst:multiline(Node),
                            {RestIO, BodyLastCol, BodyHasTrail} =
                                case {IsCondHead, IsMultiline orelse OtherArgs =:= []} of
                                    {true, true} ->
                                        bp_clause_rest_loop(RestBody, AlignCol, AlignStr, HTC, InData);
                                    {true, false} ->
                                        {FirstIO, _, _} =
                                            bp_clause_rest_loop([FirstArg], AlignCol, AlignStr, HTC, InData),
                                        {OtherIO, OtherLastCol, OtherHasTrail} =
                                            print_clause_loop(OtherArgs, AlignCol, AlignStr, false, InData),
                                        {[FirstIO, OtherIO], OtherLastCol, OtherHasTrail};
                                    {false, true} ->
                                        bp_rest_loop(RestBody, AlignCol, AlignStr, HTC, InData);
                                    {false, false} ->
                                        {FirstIO, _, _} =
                                            bp_rest_loop([FirstArg], AlignCol, AlignStr, HTC, InData),
                                        {OtherIO, OtherLastCol, OtherHasTrail} =
                                            print_rest_loop(OtherArgs, AlignCol, AlignStr, false, InData),
                                        {[FirstIO, OtherIO], OtherLastCol, OtherHasTrail}
                                end,
                            {DotIO, DotCol, DotHasTrail} =
                                lfmt_fezzik_util:apply_dot_suffix(MaybeTail, BodyLastCol, BodyHasTrail),
                            {CloseIO, CloseCol} =
                                lfmt_fezzik_util:close_section(Dangling, DotHasTrail, DotCol,
                                              AlignCol, AlignStr, C, CIndStr, Close),
                            {[HeadLeadIO, Open, HeadIO, HeadTrailIO, RestIO, DotIO, CloseIO],
                             CloseCol}
                    end
            end
    end.


%% bp_rest_loop: render children preserving nl_before break positions.
%% Each child starts a new line iff:
%%   • nl_before(Child) is true (author broke here), OR
%%   • it has a leading comment (comment safety), OR
%%   • it would overflow column 80 on the current line.
%% Otherwise it is appended space-separated on the current line.
-spec bp_rest_loop([lfmt_fezzik_cst:cst_node()], non_neg_integer(), string(),
                   non_neg_integer(), boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
bp_rest_loop([], _AlignCol, _AlignStr, CurCol, _InData) ->
    {[], CurCol, false};
bp_rest_loop([Child | Rest], AlignCol, AlignStr, CurCol, InData) ->
    W         = lfmt_fezzik_util:flat_width(Child),
    NlBefore  = lfmt_fezzik_cst:nl_before(Child),
    HasLead   = lfmt_fezzik_util:has_comment_leading(lfmt_fezzik_cst:leading(Child)),
    Overflow  = W =:= infinity orelse CurCol + 1 + W >= ?WIDTH,
    NewLine   = NlBefore orelse HasLead orelse Overflow,
    {StartCol, Prefix} =
        case NewLine of
            true  -> {AlignCol, ["\n",
                                 lfmt_fezzik_util:emit_child_leading(
                                   lfmt_fezzik_cst:leading(Child), AlignStr, false),
                                 AlignStr]};
            false -> {CurCol + 1, " "}
        end,
    {ChildIO, ChildCol} = print_node(Child, StartCol, InData),
    {TrailIO, TrailCol} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Child), ChildCol),
    case Rest of
        [] ->
            HasTrail = lfmt_fezzik_cst:trailing(Child) =/= [],
            {[Prefix, ChildIO, TrailIO], TrailCol, HasTrail};
        _ ->
            {RestIO, LastCol, HasTrail} =
                bp_rest_loop(Rest, AlignCol, AlignStr, TrailCol, InData),
            {[Prefix, ChildIO, TrailIO | RestIO], LastCol, HasTrail}
    end.


%% bp_clause_rest_loop: like bp_rest_loop but uses render_clause for each child.
%% Used for cond clauses (preserves nl_before positioning while applying the
%% trivial/non-trivial clause rule to each clause's internal rendering).
-spec bp_clause_rest_loop([lfmt_fezzik_cst:cst_node()], non_neg_integer(), string(),
                          non_neg_integer(), boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
bp_clause_rest_loop([], _AlignCol, _AlignStr, CurCol, _InData) ->
    {[], CurCol, false};
bp_clause_rest_loop([Clause | Rest], AlignCol, AlignStr, CurCol, InData) ->
    W        = lfmt_fezzik_util:flat_width(Clause),
    NlBefore = lfmt_fezzik_cst:nl_before(Clause),
    HasLead  = lfmt_fezzik_util:has_comment_leading(lfmt_fezzik_cst:leading(Clause)),
    Overflow = W =:= infinity orelse CurCol + 1 + W >= ?WIDTH,
    NewLine  = NlBefore orelse HasLead orelse Overflow,
    {StartCol, Prefix} =
        case NewLine of
            true  -> {AlignCol, ["\n",
                                 lfmt_fezzik_util:emit_child_leading(
                                   lfmt_fezzik_cst:leading(Clause), AlignStr, false),
                                 AlignStr]};
            false -> {CurCol + 1, " "}
        end,
    {ClauseIO, ClauseCol} = render_clause(Clause, StartCol, InData),
    {TrailIO, TrailCol}   = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Clause), ClauseCol),
    case Rest of
        [] ->
            HasTrail = lfmt_fezzik_cst:trailing(Clause) =/= [],
            {[Prefix, ClauseIO, TrailIO], TrailCol, HasTrail};
        _ ->
            {RestIO, LastCol, HasTrail} =
                bp_clause_rest_loop(Rest, AlignCol, AlignStr, TrailCol, InData),
            {[Prefix, ClauseIO, TrailIO | RestIO], LastCol, HasTrail}
    end.


%%====================================================================
%% Internal: map key-value pair rendering (A4·S3a)
%%====================================================================

%% print_map_pairs: render map children as key-value pairs (style guide §6).
%%   First pair on the opener line: #m(k1 v1
%%   Subsequent pairs aligned at C+OpenLen:
%%      k2 v2
%%      k3 v3)
%% If any direct map child carries a leading or trailing comment, fall back
%% to element-per-line (identical to list_head rendering) so no comment
%% swallows a paired value.
-spec print_map_pairs(lfmt_fezzik_cst:cst_node(), [lfmt_fezzik_cst:cst_node()],
                      [lfmt_fezzik_cst:trivia()],
                      non_neg_integer(), string(), non_neg_integer(),
                      string(), non_neg_integer(),
                      non_neg_integer(), string(), string(), boolean()) ->
          {iolist(), non_neg_integer()}.
print_map_pairs(Head, RestChildren, Dangling,
                C, Open, OpenLen, Close, CloseLen,
                Indent, IndentStr, CIndStr, InData) ->
    AllChildren = [Head | RestChildren],
    AnyTrivia = lists:any(
        fun(Child) ->
            lfmt_fezzik_cst:leading(Child) =/= []
            orelse lfmt_fezzik_cst:trailing(Child) =/= []
        end, AllChildren),
    case AnyTrivia of
        true ->
            %% Fall back: element-per-line (reuse list_head; safe with trivia).
            print_classified(list_head, Head, RestChildren, Dangling,
                             C, Open, OpenLen, Close, CloseLen,
                             Indent, IndentStr, CIndStr, InData);
        false ->
            AlignCol = C + OpenLen,
            AlignStr = lists:duplicate(AlignCol, $\s),
            {PairsIO, LastCol, HasTrail} =
                print_map_pairs_list(AllChildren, AlignCol, AlignStr, InData),
            {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, HasTrail, LastCol,
                                                Indent, IndentStr, C, CIndStr, Close),
            {[Open, PairsIO, CloseIO], CloseCol}
    end.


%% print_map_pairs_list: render the full list of map children starting at
%% AlignCol (first pair on the opener line, no leading newline).
-spec print_map_pairs_list([lfmt_fezzik_cst:cst_node()],
                            non_neg_integer(), string(), boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
print_map_pairs_list([K, V], AlignCol, _AlignStr, InData) ->
    {KIO, KCol} = print_node(K, AlignCol, InData),
    {VIO, VCol} = print_node(V, KCol + 1, InData),
    VTrail = lfmt_fezzik_cst:trailing(V) =/= [],
    {[KIO, " ", VIO], VCol, VTrail};
print_map_pairs_list([K, V | Rest], AlignCol, AlignStr, InData) ->
    {KIO, KCol} = print_node(K, AlignCol, InData),
    {VIO, _VCol} = print_node(V, KCol + 1, InData),
    {RestIO, LastCol, HasTrail} = print_map_pairs_rest(Rest, AlignCol, AlignStr, InData),
    {[KIO, " ", VIO | RestIO], LastCol, HasTrail};
print_map_pairs_list([K], AlignCol, _AlignStr, InData) ->
    %% Odd last element (malformed map): emit alone.
    {KIO, KCol} = print_node(K, AlignCol, InData),
    KTrail = lfmt_fezzik_cst:trailing(K) =/= [],
    {[KIO], KCol, KTrail}.


%% print_map_pairs_rest: emit remaining k-v pairs each preceded by \n+AlignStr.
-spec print_map_pairs_rest([lfmt_fezzik_cst:cst_node()],
                            non_neg_integer(), string(), boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
print_map_pairs_rest([K, V], AlignCol, AlignStr, InData) ->
    {KIO, KCol} = print_node(K, AlignCol, InData),
    {VIO, VCol} = print_node(V, KCol + 1, InData),
    VTrail = lfmt_fezzik_cst:trailing(V) =/= [],
    {["\n", AlignStr, KIO, " ", VIO], VCol, VTrail};
print_map_pairs_rest([K, V | Rest], AlignCol, AlignStr, InData) ->
    {KIO, KCol} = print_node(K, AlignCol, InData),
    {VIO, _VCol} = print_node(V, KCol + 1, InData),
    {RestIO, LastCol, HasTrail} = print_map_pairs_rest(Rest, AlignCol, AlignStr, InData),
    {["\n", AlignStr, KIO, " ", VIO | RestIO], LastCol, HasTrail};
print_map_pairs_rest([K], AlignCol, AlignStr, InData) ->
    %% Odd last element.
    {KIO, KCol} = print_node(K, AlignCol, InData),
    KTrail = lfmt_fezzik_cst:trailing(K) =/= [],
    {["\n", AlignStr, KIO], KCol, KTrail}.


%% render_clause: flat if trivial; list_head layout otherwise.
%% Directly dispatches to print_classified(list_head, …) to guarantee the
%% break regardless of what regime/2 would return for the clause's head.
-spec render_clause(lfmt_fezzik_cst:cst_node(), non_neg_integer(), boolean()) ->
          {iolist(), non_neg_integer()}.
render_clause(Clause, Col, InData) ->
    case lfmt_fezzik_util:trivial_clause(Clause) of
        true  -> {lfmt_fezzik_util:flat_render(Clause), Col + lfmt_fezzik_util:flat_width(Clause)};
        false ->
            case lfmt_fezzik_cst:children(Clause) of
                [] ->
                    print_broken(Clause, Col, InData);
                [Head | Rest] ->
                    Open     = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Clause)),
                    Close    = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:close(Clause)),
                    OpenLen  = length(Open),
                    CloseLen = length(Close),
                    Dangling = lfmt_fezzik_cst:dangling(Clause),
                    Indent    = Col + 2,
                    IndentStr = lists:duplicate(Indent, $\s),
                    CIndStr   = lists:duplicate(Col, $\s),
                    print_classified(list_head, Head, Rest, Dangling,
                                     Col, Open, OpenLen, Close, CloseLen,
                                     Indent, IndentStr, CIndStr, InData)
            end
    end.


%%====================================================================
%% Internal: classified broken rendering
%%====================================================================

-spec print_classified(head_class(),
                       lfmt_fezzik_cst:cst_node(), [lfmt_fezzik_cst:cst_node()],
                       [lfmt_fezzik_cst:trivia()],
                       non_neg_integer(), string(), non_neg_integer(),
                       string(), non_neg_integer(),
                       non_neg_integer(), string(), string(), boolean()) ->
          {iolist(), non_neg_integer()}.

%% list_head: all elements aligned under the first at C+len(Open).
%%
%% Guard path (S3d): if RestChildren=[Guard|Body] where Guard is (when …)
%% and neither Pat (Head) nor Guard carries a comment, keep Pat+Guard on one
%% line and emit Body one per line at AlignCol.  Falls back to element-per-line
%% when either has a comment (comment safety) or Head has a trailing comment.
%% Atom-pattern clauses (Pat is a symbol → funcall class) never reach here.
print_classified(list_head, Head, RestChildren, Dangling,
                 C, Open, OpenLen, Close, _CloseLen,
                 Indent, IndentStr, CIndStr, InData) ->
    AlignCol = C + OpenLen,
    AlignStr = lists:duplicate(AlignCol, $\s),
    HeadLeadIO = lfmt_fezzik_util:emit_head_leading(lfmt_fezzik_cst:leading(Head), CIndStr),
    {HeadIO, HeadCol}  = print_node(Head, AlignCol, InData),
    {HeadTrailIO, HTC} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Head), HeadCol),
    HeadHasTrail = lfmt_fezzik_cst:trailing(Head) =/= [],
    UseGuard = case RestChildren of
        [G | _] ->
            lfmt_fezzik_util:is_when_form(G)
            andalso not HeadHasTrail
            andalso lfmt_fezzik_cst:leading(G) =:= []
            andalso lfmt_fezzik_cst:trailing(G) =:= [];
        _ -> false
    end,
    case {UseGuard, RestChildren} of
        {true, [Guard | Body]} ->
            %% Pat already printed; Guard on same line, Body below at AlignCol.
            {GuardIO, GuardCol} = print_node(Guard, HTC + 1, InData),
            case Body of
                [] ->
                    {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, false, GuardCol,
                                                        Indent, IndentStr, C, CIndStr, Close),
                    {[HeadLeadIO, Open, HeadIO, HeadTrailIO, " ", GuardIO, CloseIO], CloseCol};
                _ ->
                    {BodyIO, LastCol, HasTrail} = print_rest_loop(Body, AlignCol,
                                                                   AlignStr, true, InData),
                    {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, HasTrail, LastCol,
                                                        Indent, IndentStr, C, CIndStr, Close),
                    {[HeadLeadIO, Open, HeadIO, HeadTrailIO, " ", GuardIO, BodyIO, CloseIO], CloseCol}
            end;
        {false, []} ->
            {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, HeadHasTrail, HTC,
                                                Indent, IndentStr, C, CIndStr, Close),
            {[HeadLeadIO, Open, HeadIO, HeadTrailIO, CloseIO], CloseCol};
        {false, _} ->
            {RestIO, LastCol, HasTrail} = print_rest_loop(RestChildren, AlignCol,
                                                           AlignStr, true, InData),
            {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, HasTrail, LastCol,
                                                Indent, IndentStr, C, CIndStr, Close),
            {[HeadLeadIO, Open, HeadIO, HeadTrailIO, RestIO, CloseIO], CloseCol}
    end;

%% specform N: distinguished args 1..N on head line; body at C+2.
%% N=0: head alone, all args at C+2.
%% defform (provisional = specform 1, refined in S2).
%% Falls back to body layout when:
%%   • N=0 (always), OR
%%   • HeadHasTrail (fix2: a trailing comment on the head ends the line — no
%%     content may follow it on the head line), OR
%%   • any distinguished arg has a leading/trailing comment (fix1-b).
%% Body=[] branch passes HeadHasTrail to close_section so (progn ; c) and
%% similar still break the close onto its own line (fix2).
print_classified({specform, N}, Head, RestChildren, Dangling,
                 C, Open, OpenLen, Close, _CloseLen,
                 Indent, IndentStr, CIndStr, InData) ->
    HeadLeadIO = lfmt_fezzik_util:emit_head_leading(lfmt_fezzik_cst:leading(Head), CIndStr),
    {HeadIO, HeadCol}  = print_node(Head, C + OpenLen, InData),
    {HeadTrailIO, HTC} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Head), HeadCol),
    HeadHasTrail = lfmt_fezzik_cst:trailing(Head) =/= [],
    {DistIO, DistEndCol, Body} =
        case N =:= 0 orelse HeadHasTrail of
            true ->
                {[], HTC, RestChildren};
            false ->
                NSplit = min(N, length(RestChildren)),
                {DistPotential, BodyPotential} = lists:split(NSplit, RestChildren),
                case lfmt_fezzik_util:any_dist_has_comment(DistPotential) of
                    true  -> {[], HTC, RestChildren};  %% fall back: all to body
                    false ->
                        %% For let/let*: force-break binding list (one per line).
                        %% For flet/flet*/fletrec: force-break + defun-like per element.
                        {DIO, DCol} =
                            case lfmt_fezzik_util:is_let_head(Head) andalso DistPotential =/= [] of
                                true ->
                                    [BindList] = DistPotential,
                                    {BIO, BCol} = print_broken(BindList, HTC + 1, InData),
                                    {BTrailIO, BTC} = lfmt_fezzik_util:emit_trailing(
                                        lfmt_fezzik_cst:trailing(BindList), BCol),
                                    {[" ", BIO, BTrailIO], BTC};
                                false ->
                                    case lfmt_fezzik_util:is_flet_head(Head) andalso DistPotential =/= [] of
                                        true ->
                                            [BindList] = DistPotential,
                                            {BIO, BCol} = print_flet_bindlist(
                                                BindList, HTC + 1, InData),
                                            {BTrailIO, BTC} = lfmt_fezzik_util:emit_trailing(
                                                lfmt_fezzik_cst:trailing(BindList), BCol),
                                            {[" ", BIO, BTrailIO], BTC};
                                        false ->
                                            print_distinguished(DistPotential, HTC, InData)
                                    end
                            end,
                        {DIO, DCol, BodyPotential}
                end
        end,
    case Body of
        [] ->
            %% No body args. HeadHasTrail forces the close onto its own line
            %% (covers (progn ; c), (case ; c), and any head-trailing-no-args form).
            {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, HeadHasTrail, DistEndCol,
                                                Indent, IndentStr, C, CIndStr, Close),
            {[HeadLeadIO, Open, HeadIO, HeadTrailIO, DistIO, CloseIO], CloseCol};
        _ ->
            IsCaseHead = lfmt_fezzik_util:is_clause_specform_head(Head, N),
            IsReceiveHead = lfmt_fezzik_util:is_receive_head(Head),
            IsTryHead = lfmt_fezzik_util:is_try_head(Head),
            IsExportImportHead = lfmt_fezzik_util:is_export_import_head(Head),
            IsDefunMatchHead =
                lfmt_fezzik_util:is_defun_match_head(Head, N) andalso DistIO =/= [] andalso lfmt_fezzik_util:all_clauses(Body),
            %% export/import use +1 indent (C+OpenLen); all others use the standard C+2.
            EffIndent = case IsExportImportHead of true -> C + OpenLen; false -> Indent end,
            EffIndStr = case IsExportImportHead of
                            true  -> lists:duplicate(C + OpenLen, $\s);
                            false -> IndentStr
                        end,
            %% export entries sorted alphabetically by {name, arity} (A7·S5b).
            %% Sort only when head is "export", ALL items are (name arity) pairs,
            %% AND no item has a leading comment (a commented item has intentional ordering).
            HeadText = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head)),
            IsExportHead = IsExportImportHead andalso HeadText =:= "export",
            IsImportHead = IsExportImportHead andalso HeadText =:= "import",
            SortedBody =
                case IsExportHead
                     andalso lists:all(fun lfmt_fezzik_util:is_export_entry/1, Body)
                     andalso not lists:any(fun lfmt_fezzik_util:entry_has_comment/1, Body) of
                    true  -> lfmt_fezzik_util:sort_export_entries(Body);
                    false -> Body
                end,
            {BodyIO, LastCol, HasTrail} =
                case {IsImportHead, IsExportImportHead, IsTryHead, IsReceiveHead,
                      IsCaseHead orelse IsDefunMatchHead} of
                    {true, _, _, _, _}  -> print_import_body_loop(Body, EffIndent, EffIndStr,
                                                                   true, InData);
                    {_, true, _, _, _}  -> print_rest_loop(SortedBody, EffIndent, EffIndStr,
                                                            true, InData);
                    {_, _, true, _, _}  -> print_try_body_loop(Body, Indent, IndentStr,
                                                               true, InData);
                    {_, _, _, true, _}  -> print_receive_body_loop(Body, Indent, IndentStr,
                                                                    true, InData);
                    {_, _, _, _, true}  -> print_clause_loop(Body, Indent, IndentStr,
                                                              true, InData);
                    {_, _, _, _, false} -> print_rest_loop(Body, Indent, IndentStr,
                                                            true, InData)
                end,
            {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, HasTrail, LastCol,
                                                EffIndent, EffIndStr, C, CIndStr, Close),
            {[HeadLeadIO, Open, HeadIO, HeadTrailIO, DistIO, BodyIO, CloseIO], CloseCol}
    end;

%% defform — dynamic N, delegating to specform (inherits full comment matrix).
%%
%%   defun/defmacro:
%%     N=2 when RestChildren=[_Name, Arg2|_] and lfmt_fezzik_util:is_arglist(Arg2)
%%            → signature form: (defun name (args)  body…)
%%     N=1 otherwise
%%            → match-clause form: (defun name  clauses…)
%%   any other defform → N=1 (name on head line, rest at C+2).
%%
%% Docstrings need no special case: the first body form (a string) lands at C+2.
print_classified(defform, Head, RestChildren, Dangling,
                 C, Open, OpenLen, Close, CloseLen,
                 Indent, IndentStr, CIndStr, InData) ->
    N = lfmt_fezzik_util:defform_n(Head, RestChildren),
    %% Rule (A7·S4a): def-forms are never alone on a line.  When N=2 and the
    %% distinguished args have a comment that would trigger the N=0 fallback
    %% (keyword alone), fall back to N=1 instead so keyword + name share the
    %% head line even when the arglist cannot.
    EffN = case N > 1 of
        false -> N;
        true  ->
            NSplit = min(N, length(RestChildren)),
            {DistPotential, _} = lists:split(NSplit, RestChildren),
            case lfmt_fezzik_util:any_dist_has_comment(DistPotential) of
                true  -> 1;
                false -> N
            end
    end,
    print_classified({specform, EffN}, Head, RestChildren, Dangling,
                     C, Open, OpenLen, Close, CloseLen,
                     Indent, IndentStr, CIndStr, InData);

%% funcall: a1 on head line; a2..aN aligned under a1's column.
%% Align column = C + len(Open) + len(flat(head)) + 1.
%% Falls back to body layout when head has a trailing comment (fix2: nothing may
%% follow it on the head line) or when a1 has a leading comment (fix1).
print_classified(funcall, Head, RestChildren, Dangling,
                 C, Open, OpenLen, Close, _CloseLen,
                 Indent, IndentStr, CIndStr, InData) ->
    HeadLeadIO = lfmt_fezzik_util:emit_head_leading(lfmt_fezzik_cst:leading(Head), CIndStr),
    {HeadIO, HeadCol}  = print_node(Head, C + OpenLen, InData),
    {HeadTrailIO, HTC} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Head), HeadCol),
    %% Head is always a symbol for funcall; use its text length for alignment.
    HeadTextLen = length(lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Head))),
    AlignCol = C + OpenLen + HeadTextLen + 1,
    AlignStr = lists:duplicate(AlignCol, $\s),
    HeadHasTrail = lfmt_fezzik_cst:trailing(Head) =/= [],
    case RestChildren of
        [] ->
            {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, HeadHasTrail, HTC,
                                                Indent, IndentStr, C, CIndStr, Close),
            {[HeadLeadIO, Open, HeadIO, HeadTrailIO, CloseIO], CloseCol};
        [A1 | RestArgs] ->
            case HeadHasTrail orelse lfmt_fezzik_util:head_has_leading_comment(A1) of
                true ->
                    %% Head trailing or a1 leading comment: all rest as body at C+2.
                    {AllIO, LastCol, HasTrail} = print_rest_loop(RestChildren, Indent,
                                                                  IndentStr, true, InData),
                    {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, HasTrail, LastCol,
                                                        Indent, IndentStr, C, CIndStr, Close),
                    {[HeadLeadIO, Open, HeadIO, HeadTrailIO, AllIO, CloseIO], CloseCol};
                false ->
                    {A1IO, A1Col}     = print_node(A1, HTC + 1, InData),
                    {A1TrailIO, A1TC} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(A1), A1Col),
                    A1HasTrail = lfmt_fezzik_cst:trailing(A1) =/= [],
                    case RestArgs of
                        [] ->
                            {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, A1HasTrail, A1TC,
                                                                 Indent, IndentStr, C, CIndStr,
                                                                 Close),
                            {[HeadLeadIO, Open, HeadIO, HeadTrailIO,
                              " ", A1IO, A1TrailIO, CloseIO], CloseCol};
                        _ ->
                            {RestIO, LastCol, HasTrail} = print_rest_loop(RestArgs, AlignCol,
                                                                           AlignStr, true, InData),
                            {CloseIO, CloseCol} = lfmt_fezzik_util:close_section(Dangling, HasTrail, LastCol,
                                                                 Indent, IndentStr, C, CIndStr,
                                                                 Close),
                            {[HeadLeadIO, Open, HeadIO, HeadTrailIO,
                              " ", A1IO, A1TrailIO, RestIO, CloseIO], CloseCol}
                    end
            end
    end.


%% print_distinguished: print distinguished args space-separated on the head line.
%% Each arg's leading is emitted via lfmt_fezzik_util:emit_head_leading(blanks dropped).
-spec print_distinguished([lfmt_fezzik_cst:cst_node()], non_neg_integer(),
                          boolean()) ->
          {iolist(), non_neg_integer()}.
print_distinguished([], Col, _InData) ->
    {[], Col};
print_distinguished([D | Rest], Col, InData) ->
    DLeadIO = lfmt_fezzik_util:emit_head_leading(lfmt_fezzik_cst:leading(D), ""),
    {DIO, DCol}      = print_node(D, Col + 1, InData),
    {DTrailIO, DTC}  = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(D), DCol),
    {RestIO, LastCol} = print_distinguished(Rest, DTC, InData),
    {[" ", DLeadIO, DIO, DTrailIO | RestIO], LastCol}.


%% print_rest_loop: emit children [c1..cN] each preceded by \n+Indent.
%% Returns {IO, LastCol, LastHasTrailing} where LastHasTrailing is true when
%% the final child carried a trailing comment (used by close_section fix1).
%% IsFirst=true suppresses the leading blank of the first rest child.
-spec print_rest_loop([lfmt_fezzik_cst:cst_node()], non_neg_integer(),
                      string(), boolean(), boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
print_rest_loop([Child | Rest], Indent, IndentStr, IsFirst, InData) ->
    LeadIO = lfmt_fezzik_util:emit_child_leading(lfmt_fezzik_cst:leading(Child), IndentStr, IsFirst),
    {ChildIO, ChildCol}  = print_node(Child, Indent, InData),
    {TrailIO, TrailCol}  = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Child), ChildCol),
    case Rest of
        [] ->
            HasTrail = lfmt_fezzik_cst:trailing(Child) =/= [],
            {["\n", LeadIO, IndentStr, ChildIO, TrailIO], TrailCol, HasTrail};
        _ ->
            {RestIO, LastCol, HasTrail} = print_rest_loop(Rest, Indent, IndentStr,
                                                          false, InData),
            {["\n", LeadIO, IndentStr, ChildIO, TrailIO | RestIO], LastCol, HasTrail}
    end.


%% print_local_fn_binding: render a single flet/fletrec binding (name args body…)
%% with forced {specform, N} classification (defun-like layout) rather than the
%% funcall/BP layout that a plain-symbol head would normally get.
-spec print_local_fn_binding(lfmt_fezzik_cst:cst_node(), non_neg_integer(),
                             boolean()) ->
          {iolist(), non_neg_integer()}.
print_local_fn_binding(Binding, C, InData) ->
    Open      = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Binding)),
    Close     = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:close(Binding)),
    OpenLen   = length(Open),
    CloseLen  = length(Close),
    Dangling  = lfmt_fezzik_cst:dangling(Binding),
    Indent    = C + 2,
    IndentStr = lists:duplicate(Indent, $\s),
    CIndStr   = lists:duplicate(C, $\s),
    N = lfmt_fezzik_util:local_fn_n(Binding),
    case lfmt_fezzik_cst:children(Binding) of
        [Head | RestChildren] ->
            case N =:= 0 andalso RestChildren =/= [] andalso lfmt_fezzik_util:all_clauses(RestChildren) of
                true ->
                    %% Match-clause local fn: name on head line, clauses via
                    %% render_clause at +2 (mirrors match-lambda / defun N=1 path).
                    HeadLeadIO = lfmt_fezzik_util:emit_head_leading(lfmt_fezzik_cst:leading(Head), CIndStr),
                    {HeadIO, HeadCol}  = print_node(Head, C + OpenLen, InData),
                    {HeadTrailIO, _}   = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Head), HeadCol),
                    HeadHasTrail = lfmt_fezzik_cst:trailing(Head) =/= [],
                    {BodyIO, LastCol, HasTrail} =
                        print_clause_loop(RestChildren, Indent, IndentStr, true, InData),
                    {CloseIO, CloseCol} =
                        lfmt_fezzik_util:close_section(Dangling, HasTrail orelse HeadHasTrail, LastCol,
                                      Indent, IndentStr, C, CIndStr, Close),
                    {[HeadLeadIO, Open, HeadIO, HeadTrailIO, BodyIO, CloseIO], CloseCol};
                false ->
                    print_classified({specform, N}, Head, RestChildren, Dangling,
                                     C, Open, OpenLen, Close, CloseLen,
                                     Indent, IndentStr, CIndStr, InData)
            end;
        [] ->
            {[Open, Close], C + OpenLen + CloseLen}
    end.


%% print_flet_bindlist: render the binding list of an flet/fletrec form as a
%% force-broken container, with each binding rendered via print_local_fn_binding
%% (defun-like) rather than the generic BP/funcall path.
%% Geometry mirrors print_broken_container for the non-map canonical path, but
%% the element renderer is swapped.
-spec print_flet_bindlist(lfmt_fezzik_cst:cst_node(), non_neg_integer(),
                          boolean()) ->
          {iolist(), non_neg_integer()}.
print_flet_bindlist(BindList, C, InData) ->
    Open      = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(BindList)),
    Close     = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:close(BindList)),
    OpenLen   = length(Open),
    Bindings  = lfmt_fezzik_cst:children(BindList),
    Dangling  = lfmt_fezzik_cst:dangling(BindList),
    AlignCol  = C + OpenLen,
    AlignStr  = lists:duplicate(AlignCol, $\s),
    CIndStr   = lists:duplicate(C, $\s),
    case Bindings of
        [] ->
            {[Open, Close], C + OpenLen + length(Close)};
        [First | Rest] ->
            FirstLead = lfmt_fezzik_cst:leading(First),
            FirstPrefixIO =
                case lfmt_fezzik_util:has_comment_leading(FirstLead) of
                    true  -> ["\n", lfmt_fezzik_util:emit_child_leading(FirstLead, AlignStr, false), AlignStr];
                    false -> []
                end,
            {FirstIO, FirstCol}     = print_local_fn_binding(First, AlignCol, InData),
            {FirstTrailIO, FirstTC} = lfmt_fezzik_util:emit_trailing(
                                        lfmt_fezzik_cst:trailing(First), FirstCol),
            HasFirstTrail = lfmt_fezzik_cst:trailing(First) =/= [],
            {RestIO, LastCol, HasTrail} =
                print_local_fn_bindings_loop(Rest, AlignCol, AlignStr,
                                             FirstTC, HasFirstTrail, InData),
            {CloseIO, CloseCol} =
                lfmt_fezzik_util:close_section(Dangling, HasTrail, LastCol,
                              AlignCol, AlignStr, C, CIndStr, Close),
            {[Open, FirstPrefixIO, FirstIO, FirstTrailIO, RestIO, CloseIO], CloseCol}
    end.


%% print_local_fn_bindings_loop: render the 2nd-onward flet bindings, one per
%% line at AlignStr, each via print_local_fn_binding.
-spec print_local_fn_bindings_loop([lfmt_fezzik_cst:cst_node()],
                                   non_neg_integer(), string(),
                                   non_neg_integer(), boolean(),
                                   boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
print_local_fn_bindings_loop([], _Indent, _IndStr, LastCol, HasTrail, _InData) ->
    {[], LastCol, HasTrail};
print_local_fn_bindings_loop([B | Rest], Indent, IndStr, _PrevCol, _PrevTrail, InData) ->
    LeadIO  = lfmt_fezzik_util:emit_child_leading(lfmt_fezzik_cst:leading(B), IndStr, false),
    {BIO, BCol}    = print_local_fn_binding(B, Indent, InData),
    {TrailIO, BTC} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(B), BCol),
    HasTrail = lfmt_fezzik_cst:trailing(B) =/= [],
    {RestIO, LastCol, LastHasTrail} =
        print_local_fn_bindings_loop(Rest, Indent, IndStr, BTC, HasTrail, InData),
    {["\n", LeadIO, IndStr, BIO, TrailIO | RestIO], LastCol, LastHasTrail}.


%% print_clause_loop: like print_rest_loop but uses render_clause for each child.
%% Used for case body clauses and for remaining cond clauses.
-spec print_clause_loop([lfmt_fezzik_cst:cst_node()], non_neg_integer(),
                        string(), boolean(), boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
print_clause_loop([Clause | Rest], Indent, IndentStr, IsFirst, InData) ->
    LeadIO = lfmt_fezzik_util:emit_child_leading(lfmt_fezzik_cst:leading(Clause), IndentStr, IsFirst),
    {ClauseIO, ClauseCol} = render_clause(Clause, Indent, InData),
    {TrailIO, TrailCol}   = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Clause), ClauseCol),
    case Rest of
        [] ->
            HasTrail = lfmt_fezzik_cst:trailing(Clause) =/= [],
            {["\n", LeadIO, IndentStr, ClauseIO, TrailIO], TrailCol, HasTrail};
        _ ->
            {RestIO, LastCol, HasTrail} = print_clause_loop(Rest, Indent, IndentStr,
                                                            false, InData),
            {["\n", LeadIO, IndentStr, ClauseIO, TrailIO | RestIO], LastCol, HasTrail}
    end.


%% print_receive_body_loop: receive pattern clauses use render_clause, but the
%% (after timeout body...) section is not a clause and keeps generic rendering.
-spec print_receive_body_loop([lfmt_fezzik_cst:cst_node()], non_neg_integer(),
                              string(), boolean(), boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
print_receive_body_loop([Child | Rest], Indent, IndentStr, IsFirst, InData) ->
    LeadIO = lfmt_fezzik_util:emit_child_leading(lfmt_fezzik_cst:leading(Child), IndentStr, IsFirst),
    {ChildIO, ChildCol} =
        case lfmt_fezzik_util:is_after_section(Child) of
            true  -> print_node(Child, Indent, InData);
            false -> render_clause(Child, Indent, InData)
        end,
    {TrailIO, TrailCol} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Child), ChildCol),
    case Rest of
        [] ->
            HasTrail = lfmt_fezzik_cst:trailing(Child) =/= [],
            {["\n", LeadIO, IndentStr, ChildIO, TrailIO], TrailCol, HasTrail};
        _ ->
            {RestIO, LastCol, HasTrail} = print_receive_body_loop(Rest, Indent,
                                                                  IndentStr, false, InData),
            {["\n", LeadIO, IndentStr, ChildIO, TrailIO | RestIO], LastCol, HasTrail}
    end.


%% print_try_body_loop: first child is the try body expr (print_node); subsequent
%% children are case/catch/after sections rendered via print_try_section.
-spec print_try_body_loop([lfmt_fezzik_cst:cst_node()], non_neg_integer(),
                          string(), boolean(), boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
print_try_body_loop([Child | Rest], Indent, IndentStr, IsFirst, InData) ->
    LeadIO = lfmt_fezzik_util:emit_child_leading(lfmt_fezzik_cst:leading(Child), IndentStr, IsFirst),
    {ChildIO, ChildCol} =
        case IsFirst of
            true  -> print_node(Child, Indent, InData);
            false -> print_try_section(Child, Indent, InData)
        end,
    {TrailIO, TrailCol} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Child), ChildCol),
    case Rest of
        [] ->
            HasTrail = lfmt_fezzik_cst:trailing(Child) =/= [],
            {["\n", LeadIO, IndentStr, ChildIO, TrailIO], TrailCol, HasTrail};
        _ ->
            {RestIO, LastCol, HasTrail} = print_try_body_loop(Rest, Indent, IndentStr,
                                                              false, InData),
            {["\n", LeadIO, IndentStr, ChildIO, TrailIO | RestIO], LastCol, HasTrail}
    end.


%% print_try_section: render a (case/catch/after …) section with the keyword alone
%% on the section line and contents at +2 below (case/catch via print_clause_loop;
%% after via print_rest_loop). Reachable only from print_try_body_loop.
-spec print_try_section(lfmt_fezzik_cst:cst_node(), non_neg_integer(), boolean()) ->
          {iolist(), non_neg_integer()}.
print_try_section(Section, C, InData) ->
    case lfmt_fezzik_cst:type(Section) =:= list of
        false ->
            print_node(Section, C, InData);
        true ->
            case lfmt_fezzik_cst:children(Section) of
                [] ->
                    Open  = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Section)),
                    Close = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:close(Section)),
                    {[Open, Close], C + length(Open) + length(Close)};
                [SectionHead | Contents] ->
                    case lfmt_fezzik_cst:type(SectionHead) =:= symbol of
                        false ->
                            print_node(Section, C, InData);
                        true ->
                            Open      = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Section)),
                            Close     = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:close(Section)),
                            OpenLen   = length(Open),
                            Dangling  = lfmt_fezzik_cst:dangling(Section),
                            Indent    = C + 2,
                            IndentStr = lists:duplicate(Indent, $\s),
                            CIndStr   = lists:duplicate(C, $\s),
                            HeadLeadIO = lfmt_fezzik_util:emit_head_leading(
                                           lfmt_fezzik_cst:leading(SectionHead), CIndStr),
                            {HeadIO, HeadCol}  =
                                print_node(SectionHead, C + OpenLen, InData),
                            {HeadTrailIO, _}   =
                                lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(SectionHead), HeadCol),
                            HeadHasTrail = lfmt_fezzik_cst:trailing(SectionHead) =/= [],
                            {BodyIO, LastCol, HasTrail} =
                                case Contents of
                                    [] ->
                                        {[], HeadCol, false};
                                    _ ->
                                        case lfmt_fezzik_util:is_after_section(Section) of
                                            true ->
                                                print_rest_loop(Contents, Indent, IndentStr,
                                                                true, InData);
                                            false ->
                                                print_clause_loop(Contents, Indent, IndentStr,
                                                                  true, InData)
                                        end
                                end,
                            {CloseIO, CloseCol} =
                                lfmt_fezzik_util:close_section(Dangling, HasTrail orelse HeadHasTrail, LastCol,
                                              Indent, IndentStr, C, CIndStr, Close),
                            {[HeadLeadIO, Open, HeadIO, HeadTrailIO, BodyIO, CloseIO], CloseCol}
                    end
            end
    end.


%% print_import_body_loop: emit import clauses one-per-line via print_import_clause.
%% All children are clauses (from/rename/deprecated/other). Reachable only from
%% the import arm of the specform body router.
-spec print_import_body_loop([lfmt_fezzik_cst:cst_node()], non_neg_integer(),
                              string(), boolean(), boolean()) ->
          {iolist(), non_neg_integer(), boolean()}.
print_import_body_loop([Child | Rest], Indent, IndentStr, IsFirst, InData) ->
    LeadIO = lfmt_fezzik_util:emit_child_leading(lfmt_fezzik_cst:leading(Child), IndentStr, IsFirst),
    {ChildIO, ChildCol} = print_import_clause(Child, Indent, InData),
    {TrailIO, TrailCol} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Child), ChildCol),
    case Rest of
        [] ->
            HasTrail = lfmt_fezzik_cst:trailing(Child) =/= [],
            {["\n", LeadIO, IndentStr, ChildIO, TrailIO], TrailCol, HasTrail};
        _ ->
            {RestIO, LastCol, HasTrail} =
                print_import_body_loop(Rest, Indent, IndentStr, false, InData),
            {["\n", LeadIO, IndentStr, ChildIO, TrailIO | RestIO], LastCol, HasTrail}
    end.


%% print_import_clause: render a single import clause.
%% (from M E…) and (rename M P…): keyword+module on head line; entries one-per-line
%% at C+OpenLen (+1); entries sorted (suppressed if any has a leading comment).
%% deprecated/other/non-list: render via print_node (generic at +1).
-spec print_import_clause(lfmt_fezzik_cst:cst_node(), non_neg_integer(), boolean()) ->
          {iolist(), non_neg_integer()}.
print_import_clause(Clause, C, InData) ->
    case lfmt_fezzik_cst:type(Clause) of
        list ->
            case lfmt_fezzik_cst:children(Clause) of
                [ClauseHead, _Mod | _Entries] ->
                    case lfmt_fezzik_cst:type(ClauseHead) of
                        symbol ->
                            ClauseText = lfmt_fezzik_lexer:text(
                                             lfmt_fezzik_cst:open(ClauseHead)),
                            case lists:member(ClauseText, ["from", "rename"]) of
                                true  -> print_import_from_rename(Clause, C, InData);
                                false -> print_node(Clause, C, InData)
                            end;
                        _ ->
                            print_node(Clause, C, InData)
                    end;
                _ ->
                    print_node(Clause, C, InData)
            end;
        _ ->
            print_node(Clause, C, InData)
    end.


%% print_import_from_rename: shared renderer for (from M E…) and (rename M P…).
%% Keyword and module on head line; entries one-per-line at C+OpenLen (+1).
-spec print_import_from_rename(lfmt_fezzik_cst:cst_node(), non_neg_integer(),
                                boolean()) -> {iolist(), non_neg_integer()}.
print_import_from_rename(Clause, C, InData) ->
    Open      = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(Clause)),
    Close     = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:close(Clause)),
    OpenLen   = length(Open),
    Dangling  = lfmt_fezzik_cst:dangling(Clause),
    Indent    = C + OpenLen,
    IndentStr = lists:duplicate(Indent, $\s),
    CIndStr   = lists:duplicate(C, $\s),
    [ClauseHead, Mod | Entries] = lfmt_fezzik_cst:children(Clause),
    ClauseText = lfmt_fezzik_lexer:text(lfmt_fezzik_cst:open(ClauseHead)),
    HeadLeadIO = lfmt_fezzik_util:emit_head_leading(lfmt_fezzik_cst:leading(ClauseHead), CIndStr),
    {HeadIO, HeadCol}   = print_node(ClauseHead, C + OpenLen, InData),
    {HeadTrailIO, HTC}  = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(ClauseHead), HeadCol),
    HeadHasTrail = lfmt_fezzik_cst:trailing(ClauseHead) =/= [],
    ModLead = lfmt_fezzik_cst:leading(Mod),
    HasModLeadComment = lfmt_fezzik_util:has_comment_leading(ModLead),
    case HeadHasTrail orelse HasModLeadComment of
        true ->
            print_node(Clause, C, InData);
        false ->
            {ModIO, ModCol}   = print_node(Mod, HTC + 1, InData),
            {ModTrailIO, MTC} = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Mod), ModCol),
            ModHasTrail = lfmt_fezzik_cst:trailing(Mod) =/= [],
            SortedEntries = lfmt_fezzik_util:sort_import_entries(ClauseText, Entries),
            {BodyIO, LastCol, HasTrail} =
                case Entries of
                    [] -> {[], MTC, false};
                    _  -> print_rest_loop(SortedEntries, Indent, IndentStr, true, InData)
                end,
            {CloseIO, CloseCol} =
                lfmt_fezzik_util:close_section(Dangling, HasTrail orelse ModHasTrail, LastCol,
                              Indent, IndentStr, C, CIndStr, Close),
            {[HeadLeadIO, Open, HeadIO, HeadTrailIO, " ", ModIO, ModTrailIO,
              BodyIO, CloseIO], CloseCol}
    end.
