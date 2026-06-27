%%%% lfmt_engine: the backend contract every formatter engine implements.
%%%%
%%%% An engine module takes a validated opts handle + a source and returns the
%%%% tagged {ok, iolist()} | {error, term()} result. lfmt:format/2 dispatches to
%%%% the engine named by the handle. Implementations: lfmt_fezzik (0.4.0);
%%%% lfmt_pe (v0.5.0) and lfmt_pc (v0.6.0) slot in behind this same contract.
-module(lfmt_engine).

-callback format(lfmt:opts(), unicode:chardata()) ->
    {ok, iolist()} | {error, term()}.
