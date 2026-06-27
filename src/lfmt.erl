%%%% lfmt: the public, multi-engine LFE formatter API.
%%%%
%%%% new/1 builds a validated, opaque opts handle; format/1,2 dispatch on the
%%%% selected engine. Only `fezzik` is wired at 0.4.0; `pe` (v0.5.0) and `pc`
%%%% (v0.6.0) are named in the engine() type and reserved — new/1 errors clearly
%%%% if they are selected, so nothing is silently dropped.
-module(lfmt).

-include("lfmt.hrl").

-export([new/1, format/1, format/2]).
-export_type([opts/0, engine/0]).

-type engine() :: fezzik | pe | pc.
-opaque opts() :: #lfmt_opts{}.

%% new/1: build + validate an opts handle. This is a constructor — it returns the
%% handle directly and *raises* on bad input (bad input is a programmer error):
%%   default engine          -> fezzik
%%   reserved engine (pe|pc)  -> error({engine_not_available, E})
%%   unknown engine           -> error({unknown_engine, E})
%%   unknown option key       -> error({unknown_option, K})  (no option is dropped)
-spec new(map()) -> opts().
new(Map) when is_map(Map) ->
    validate(maps:fold(fun set_opt/3, #lfmt_opts{}, Map)).

set_opt(engine, E, Opts) -> Opts#lfmt_opts{engine = E};
set_opt(K, _V, _Opts)    -> error({unknown_option, K}).

validate(#lfmt_opts{engine = fezzik} = Opts) ->
    Opts;
validate(#lfmt_opts{engine = E}) when E =:= pe; E =:= pc ->
    error({engine_not_available, E});
validate(#lfmt_opts{engine = E}) ->
    error({unknown_engine, E}).

%% format/2: format Source with the engine selected in the handle.
-spec format(opts(), unicode:chardata()) -> {ok, iolist()} | {error, term()}.
format(#lfmt_opts{engine = E} = Opts, Source) ->
    (engine_module(E)):format(Opts, Source).

%% format/1: format Source with the default engine (fezzik).
-spec format(unicode:chardata()) -> {ok, iolist()} | {error, term()}.
format(Source) ->
    format(new(#{}), Source).

%% engine_module/1: map an engine atom to its backend module. Only fezzik is
%% mapped at 0.4.0; the fallback keeps the function total over engine() (pe|pc
%% never reach here — new/1 rejects them — but the opaque boundary needs it).
-spec engine_module(engine()) -> module().
engine_module(fezzik) -> lfmt_fezzik;
engine_module(E)      -> error({engine_not_available, E}).
