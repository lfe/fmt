%%% @doc PropEr property: rendering a choiceless document is total and its
%%% iolist and binary forms agree.
-module(prop_pe_render).

-include_lib("proper/include/proper.hrl").

-export([prop_render_total/0]).

%% Rendering never crashes on a well-formed choiceless document, render/1
%% returns an iolist, render_binary/1 a binary, and they flatten to the same
%% bytes.
prop_render_total() ->
    ?FORALL(
        Cdoc,
        cdoc(),
        begin
            Iolist = pe_render:render(Cdoc),
            Bin = pe_render:render_binary(Cdoc),
            is_list(Iolist) andalso is_binary(Bin) andalso iolist_to_binary(Iolist) =:= Bin
        end
    ).

cdoc() ->
    ?SIZED(Size, cdoc(Size)).

cdoc(0) ->
    oneof([{text, short_bin()}, nl]);
cdoc(Size) ->
    Half = Size div 2,
    frequency([
        {2, {text, short_bin()}},
        {1, nl},
        {3, ?LAZY({concat, cdoc(Half), cdoc(Half)})},
        {2, ?LAZY({nest, range(0, 4), cdoc(Size - 1)})},
        {2, ?LAZY({align, cdoc(Size - 1)})}
    ]).

short_bin() ->
    ?LET(N, range(0, 4), list_to_binary(lists:duplicate(N, $x))).
