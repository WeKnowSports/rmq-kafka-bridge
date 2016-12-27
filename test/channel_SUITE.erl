-module(channel_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

-define(current_function_name(), element(2, element(2, process_info(self(), current_function)))).
-define(MSG, #{<<"message">> => <<"Common Test Message">>}).


suite() ->
    [{timetrap,{seconds,30}}].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(cgate),
    Cgate = ct:get_config(cgate),
    Cgate ++ Config.

end_per_suite(_Config) ->
    ok.


init_per_testcase(Channel, Config) ->
    Channels = ?config(channels, Config),
    ChannelConfig = ?config(Channel, Channels),
    {ok, _Pid} = channel:start_link(Channel, ChannelConfig),
    {RMQ_URI, _} = ?config(rmq_config, Config),
    {ok, Rmq} = rmq:start_link(RMQ_URI),
    
    %% Start Kafka Client
    #{to := {kafka, publish, [#{host_port := Hosts, 
                                kafka_client := Client,
                                topics := [#{topic := Topic}]} ]}}  = ChannelConfig,


    brod:start_client(Hosts, Client),
    brod:start_producer(Client, Topic, []),
    ct:sleep({seconds, 2}),
    [{rmq, Rmq} | Config].

end_per_testcase(Channel, Config) ->
    gen_server:stop(Channel),
    Rmq = ?config(rmq, Config),
    rmq:stop(Rmq),
    ok.

%%%% HELPERS %%%%

gen_message() ->
    Msg = [
        {<<"MessageID">>, rand:uniform(1000)},
        {<<"CorrelationID">>, rand:uniform(1000)}
    ],
    {Msg, msgpack:pack(Msg, [{map_format, jsx}])}.


%%%% GROUPS %%%%


groups() ->
    [{group_of_channels, [parallel, {repeat_until_all_ok, 1}], [channel_test]}].


all() -> 
    [{group, group_of_channels}].


%%% TEST CASES %%%


channel_test(Config) ->
    Channel = ?current_function_name(),
    Channels = ?config(channels, Config),
    ChannelConfig = ?config(Channel, Channels),
    #{from := {rmq, subscribe, [From]}}  = ChannelConfig,
    #{to := {kafka, publish, [To]}}  = ChannelConfig,

    #{exchange := Exchange, routing_key := Rk} = From, 
    #{host_port := Hosts, kafka_client := Client, topics := [TopicConfig]} = To,

    #{topic := Topic, partition := Partition, key := _Key} = TopicConfig,

    Rmq = ?config(rmq, Config),
    %% ct:pal(info, "send test message to ~p ~p ", [Rmq, From]),

    {OrigMsg, BinMsg} = gen_message(),

    ok = rmq:publish(Rmq, Exchange, Rk, BinMsg),
    ct:sleep({seconds, 3}),
    {ok, _Pid} = kafka:subscribe_latest(Hosts, Client, Topic, Partition, self()),

    receive
        {new_event,  ReceivedMsg} ->
            SentMsg = maps:from_list(OrigMsg),
            RecvMsg = jsx:decode(ReceivedMsg, [return_maps]),
            SentMsg = RecvMsg,
            ok;
        Msg ->
            ct:fail("Incorrect message from kafka ~p", [Msg])
    after 2000 ->
            ct:fail("Timed out on waiting message from kafka")
    end ,
    Config.



