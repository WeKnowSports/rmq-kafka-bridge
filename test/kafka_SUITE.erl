-module(kafka_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("brod/include/brod.hrl").
-compile(export_all).

-define(VALUE, <<"Test message">>).

all() -> [produce_test].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(cgate),
    Cgate = ct:get_config(cgate),
    KafkaConfig = ?config(kafka_config, Cgate),
    ct:pal(info, "Kafka config: ~p", [KafkaConfig]),
    #{kafka_client := Client, host_port := Hosts, topics := [TopicConfig]} = KafkaConfig,
    ok = brod:start_client(Hosts, Client),
    #{topic := Topic} = TopicConfig,
    ok = brod:start_producer(Client, Topic, _ProducerConfig = []),
    Args = [{client, Client}, {config, KafkaConfig}, {hosts, Hosts}],
    Args ++ Config.

end_per_suite(Config) ->
    Config.

produce_test(Config) ->
    TopicConfig = ?config(config, Config),
    Client = ?config(client, Config),
    Hosts = ?config(hosts, Config),
    #{topics := [#{topic := Topic, partition := Partition, key := _Key}]} = TopicConfig,
    {ok, Pub} = kafka:publish(TopicConfig),
    Pub(?VALUE),
    {ok, _Pid} = kafka:subscribe_latest(Hosts, Client, Topic, Partition, self()),

    receive
        {new_event, ?VALUE} ->
            ok
    after 3000 ->
            ct:fail("Timed out on waiting message from kafka")
    end ,

    Config.
