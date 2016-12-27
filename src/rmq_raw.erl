-module(rmq_raw).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("logger.hrl").

%% API
-export([connect/1, subscribe/1, unsubscribe/1, close/1, close_queue/1, publish/1]).


%%%============
%%% Types
%%%============

-type connection() :: pid().
-type channel() :: pid().
-type queue() :: binary().
-type tag() :: binary().
-type exchange() :: binary().
-type routing_key() :: binary().

-type rmq_params() :: #{connection => connection(),
                        channel => channel(),
                        queue => queue(),
                        tag => tag(),
                        exchange => exchange(),
                        routing_key => routing_key()}.

-export_type([rmq_params/0]).

%%%===================================================================
%%% API
%%%===================================================================

-spec connect(maybe_improper_list()) -> {'ok', #{'channel':=_, 'connection':=_, 'params':=_}}.

connect(Uri) when is_list(Uri) ->
    {ok, Params} = amqp_uri:parse(Uri),
    {ok, Connection} = amqp_connection:start(Params),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    {ok, #{params => Params, connection => Connection, channel => Channel }}.


-spec subscribe(rmq_params()) -> {ok, rmq_params()}.

subscribe(#{ channel := Channel, exchange := Exchange, routing_key := RoutingKey} = Params) 
  when is_pid(Channel) 
       andalso is_binary(Exchange)
       andalso is_binary(RoutingKey) ->

    %% Create Queue

    #'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel, #'queue.declare'{}),

    %% Bind Queue to exchange with RK

    Binding = #'queue.bind'{queue       = Queue,
                            exchange    = Exchange,
                            routing_key = RoutingKey},
    #'queue.bind_ok'{} = amqp_channel:call(Channel, Binding),

    %% Subscribe queue

    Sub = #'basic.consume'{queue = Queue}, 
    #'basic.consume_ok'{consumer_tag = Tag} = amqp_channel:call(Channel, Sub),
    {ok, Params#{tag => Tag, queue => Queue}}.



-spec unsubscribe(rmq_params()) -> {ok, rmq_params()}.

unsubscribe(#{channel := Channel, tag := Tag} = Params) ->
    amqp_channel:call(Channel, #'basic.cancel'{consumer_tag = Tag}),
    {ok, maps:remove(tag, Params)}.


-spec close(rmq_params()) -> {ok, #{}} | {error, {noproc, term()}}.

close(#{channel := Channel, connection := Connection} = Params) ->
    
    {ok, _Params} = close_queue(Params),

    %% Close channel and connection

    {ok, _} = run_when_pid(fun amqp_channel:close/1, Channel),
    {ok, _} = run_when_pid(fun amqp_connection:close/1, Connection),
    {ok, #{}}.


-spec close_queue(rmq_params()) -> {ok, rmq_params()}.
                                                            
close_queue(#{channel := Channel, queue := Queue, exchange := Exchange, routing_key := RoutingKey} = Params) 
  when is_pid(Channel) 
       andalso Queue =/= undefined 
       andalso Exchange =/= undefined 
       andalso RoutingKey =/= undefined ->

    %% Unbind queue from exchange
    
    Binding = #'queue.unbind'{queue       = Queue,
                              exchange    = Exchange,
                              routing_key = RoutingKey},
    #'queue.unbind_ok'{} = amqp_channel:call(Channel, Binding),

    %% Delete the Queue

    Delete = #'queue.delete'{queue = Queue},
    #'queue.delete_ok'{} = amqp_channel:call(Channel, Delete),

    P1 = maps:remove(queue, Params),
    P2 = maps:remove(exchange, P1),
    P3 = maps:remove(routing_key, P2),
    {ok, P3};
close_queue(Params) ->
%    ?ERROR("Can't delete queue ~p", [Params]),
    {ok, Params}.


-spec publish(#{channel => channel(), connection => connection(), exchange => exchange(), routing_key => routing_key(), payload => binary()}) -> ok. 

publish(#{channel := Channel, payload := Payload, exchange := Exchange, routing_key := RoutingKey}) 
  when is_pid(Channel) 
       andalso is_binary(Payload)
       andalso is_binary(Exchange)
       andalso is_binary(RoutingKey) ->

    Publish = #'basic.publish'{exchange = Exchange, routing_key = RoutingKey},
    amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),
    ok.
    
%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec run_when_pid(fun(), pid()) -> {ok, term()} | {error, {noproc, term()}}.
                                    

run_when_pid(Fn, Pid) when is_pid(Pid) ->
    {ok, Fn(Pid)};
run_when_pid(_Fn, Pid) ->
    ?ERROR("Channel not a pid: ~p", [Pid]),
    {error, {noproc, Pid}}.
