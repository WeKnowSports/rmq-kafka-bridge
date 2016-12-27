-module(cgate_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    ChanSup = #{id => channel_sup,
                start => {channel_sup, start_link, []},
                type => supervisor},
    Procs = [ChanSup],
    {ok, {{one_for_one, 1000, 1000}, Procs}}.
