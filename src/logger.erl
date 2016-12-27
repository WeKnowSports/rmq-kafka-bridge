-module(logger).

-export([error/4, info/4]).

error(File, Line, Format, Args) ->
    OutFormat = "~s : ~p : " ++ Format,
    OutArgs = [File, Line] ++ Args,
    error_logger:error_msg(OutFormat, OutArgs).

info(File, Line, Format, Args) ->
    OutFormat = "~s : ~p : " ++ Format,
    OutArgs = [File, Line] ++ Args,
    error_logger:info_msg(OutFormat, OutArgs).

