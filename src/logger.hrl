%%% Error logger helpers

-define(ERROR(Format, Args), logger:error(?FILE, ?LINE, Format, Args)).

-define(INFO(Format, Args), logger:info(?FILE, ?LINE, Format, Args)).
