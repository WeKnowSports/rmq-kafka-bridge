-module(channel_sup).
-behaviour(supervisor).

-export([start_link/0, start_channels/0]).

-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_channels() ->
    Procs = gen_channels(),
    [supervisor:start_child(?MODULE, C) || C <- Procs].

init([]) ->
    Procs = [],
    {ok, {{one_for_one, 1000, 1000}, Procs}}.

gen_channels() ->
    {ok, Channels} = application:get_env(cgate, channels),
    [gen_spec(C) || C <- Channels ].

gen_spec({Channel, Args}) ->
    #{id => Channel, 
      start => {channel, start_link, [Channel, Args]},
      type => worker
     }.
