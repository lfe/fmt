%%%% Shared options record for the lfmt multi-engine public API.
%%%%
%%%% `engine` is the only field at 0.4.0 — and it is the *real* dispatch selector
%%%% consumed by lfmt:format/2, so the record carries no hollow options. Further
%%%% fields (width, indent, …) are added only when an engine actually reads them.
-record(lfmt_opts, {engine = fezzik :: lfmt:engine()}).
