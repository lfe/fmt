%%%% LFE source formatter — public entry + document orchestration.
%%%% Pipeline: lfmt_fezzik_lexer -> lfmt_fezzik_cst -> render -> iolist.
-module(lfmt_fezzik).

-behaviour(lfmt_engine).

-export([format/1, format/2]).

%% regime/2 exported for unit testing only (re-exported from lfmt_fezzik_util).
-ifdef(TEST).
-export([regime/2]).
regime(Node, InData) -> lfmt_fezzik_util:regime(Node, InData).
-endif.


%%====================================================================
%% Exported API
%%====================================================================

%% Dialyzer infers a concrete nested-list type for the iolist return; suppress
%% the underspecs warning since iolist() is the correct public abstraction.
-dialyzer({no_underspecs, format/1}).
-spec format(binary() | string()) -> {ok, iolist()} | {error, term()}.
format(Input) ->
    case lfmt_fezzik_lexer:tokens(Input) of
        {ok, Tokens} ->
            case lfmt_fezzik_cst:parse(Tokens) of
                {ok, Doc} -> {ok, render_document(Doc)};
                {error, _} = Err -> Err
            end;
        {error, _} = Err ->
            Err
    end.

%% lfmt_engine behaviour callback. 0.4.0 opts carry only the engine selector
%% (consumed by lfmt:format/2 before dispatch), so there is no fezzik-specific
%% option to read yet. format/1's domain is binary()|string() (the lexer's), so
%% normalise the generic chardata() the behaviour accepts to a UTF-8 binary
%% first — this keeps fezzik honest about the contract without touching the
%% engine internals. (When fezzik honours an option, e.g. width, read it here.)
-spec format(lfmt:opts(), unicode:chardata()) -> {ok, iolist()} | {error, term()}.
format(_Opts, Source) ->
    case unicode:characters_to_binary(Source) of
        Bin when is_binary(Bin) -> format(Bin);
        _ -> {error, {invalid_encoding, Source}}
    end.


%%====================================================================
%% Internal: document-level layout
%%====================================================================

-spec render_document(lfmt_fezzik_cst:cst_document()) -> iolist().
render_document(Doc) ->
    Nodes     = lfmt_fezzik_cst:document_children(Doc),
    DangItems = lfmt_fezzik_cst:document_dangling(Doc),
    Parts     = render_toplevel(Nodes, true, [], false),
    DangIO    = lfmt_fezzik_util:emit_toplevel_dangling(DangItems),
    lists:reverse([DangIO | Parts]).


%% render_toplevel: emit each top-level node with its leading trivia and final \n.
-spec render_toplevel([lfmt_fezzik_cst:cst_node()], boolean(), iolist(),
                      boolean()) -> iolist().
render_toplevel([], _IsFirst, Acc, _InData) ->
    Acc;
render_toplevel([Node | Rest], IsFirst, Acc, InData) ->
    LeadIO = lfmt_fezzik_util:emit_leading_trivia(lfmt_fezzik_cst:leading(Node), "", IsFirst),
    {NodeIO, NodeCol} = lfmt_fezzik_render:print_node(Node, 0, InData),
    {TrailIO, _Col}   = lfmt_fezzik_util:emit_trailing(lfmt_fezzik_cst:trailing(Node), NodeCol),
    Part = [LeadIO, NodeIO, TrailIO, "\n"],
    render_toplevel(Rest, false, [Part | Acc], InData).
