-module(rmq_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

suite() ->
    [{timetrap,{seconds,30}}].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(cgate),
    Cgate = ct:get_config(cgate),
    RmqConfig = ?config(rmq_config, Cgate),
    {Uri, Exchange} = RmqConfig,
    [{rmq_uri, Uri}, {rmq_exchange, Exchange}] ++ Config.

end_per_suite(_Config) ->
    application:stop(cgate).

groups() ->
    [].

all() -> 
    [connect_test, subscribe_unsubscribe_test, pub_sub_test, fast_subscribe_test].

connect_test(Config) ->
    DEV_URI = ?config(rmq_uri, Config),
    {ok, Rmq} = rmq:start_link(DEV_URI),
    ok = rmq:stop(Rmq),
    Config.

subscribe_unsubscribe_test(Config) ->
    DEV_URI = ?config(rmq_uri, Config),
    DEV_Exchange = ?config(rmq_exchange, Config),
    {ok, Rmq} = rmq:start_link(DEV_URI),
    ok = rmq:subscribe(Rmq, DEV_Exchange),
    ok = rmq:unsubscribe(Rmq),
    ok = rmq:stop(Rmq),
    Config.


pub_sub_test(Config) ->
    DEV_URI = ?config(rmq_uri, Config),
    DEV_Exchange = ?config(rmq_exchange, Config),
    {ok, Rmq} = rmq:start_link(DEV_URI),
    ok = rmq:subscribe(Rmq, DEV_Exchange),
    ok = rmq:publish(Rmq, DEV_Exchange, <<"*">>, <<"test message">>),
    receive 
        {new_event, <<"test message">>} -> ok;
        Err -> ct:pal(error, "Unexpected rmq message ~p", [Err])
    after 
        5000 ->
            ct:pal("timeout", [])
    end,
    ok = rmq:unsubscribe(Rmq),
    ok = rmq:stop(Rmq),
    Config.


fast_subscribe_test(Config) ->
    DEV_URI = ?config(rmq_uri, Config),
    DEV_Exchange = ?config(rmq_exchange, Config),
    Args = [#{connection => DEV_URI,
              exchange => DEV_Exchange,
              routing_key => <<"*">>}],
    {ok, Rmq} = erlang:apply(rmq, subscribe, Args),
    ok = rmq:publish(Rmq, DEV_Exchange, <<"*">>, <<"test message">>),
    receive 
        {new_event, <<"test message">>} -> ok;
        Err -> ct:fail("Unexpected rmq message ~p", [Err])
    after 
        5000 ->
            ct:fail("REceive message timeout")
    end,
    ok = rmq:stop(Rmq),
    Config.
