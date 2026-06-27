%%%% Shared definitions for the split lfmt_fezzik engine.
-define(WIDTH, 80).  %% column limit (§2.1)

-type width() :: non_neg_integer() | infinity.
-type head_class() :: {specform, non_neg_integer()} | defform | funcall | list_head.
