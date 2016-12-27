-module(kafka).

-include("logger.hrl").
-include_lib("brod/include/brod.hrl").

%% API
-export([publish/1, subscribe_latest/5]).

%%%===================================================================
%%% API
%%%===================================================================

-type topic() :: #{key := binary(), 
                  partition := binary(),
                  topic := binary()}.

-spec publish(#{kafka_client := atom(), topics := [topic()]}) -> {ok, fun()}. 

publish(#{kafka_client := Client, topics := Topics = [_|_]}) 

  when is_atom(Client) ->

    {ok, fun(Value)->
        [ send(Client, T , Value) || T <- Topics ]
    end}.

-spec subscribe_latest(Hosts :: [{string(), pos_integer()}], 
                       Client :: atom(), 
                       Topic :: binary(), 
                       Partition :: pos_integer(), 
                       Caller :: pid()) 
                      -> {ok, pid()}.

subscribe_latest(Hosts, Client, Topic, Partition, Caller) 

  when is_atom(Client)
       andalso is_binary(Topic) 
       andalso Partition >= 0 
       andalso is_pid(Caller) ->

    Callback =
        fun(_RPartition, #kafka_message{key = _Key, value = Message} = Raw, State) ->
                ?INFO("~p", [Raw]),
                State ! {new_event, Message},
                {ok, ack, State}
        end,
    {ok, [Offset]} = brod:get_offsets(Hosts, Topic, Partition),
    brod_topic_subscriber:start_link(Client, 
                                     Topic, 
                                     [Partition],
                                     [{begin_offset, Offset - 1}], 
                                     [],
                                     Callback, 
                                     Caller).
    


%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

-spec send(Client :: atom(), topic(), Value :: binary()) -> ok | error.

send(Client, #{key := Key, partition := Partition, topic := Topic}, Value ) 

  when is_atom(Client)
       orelse is_binary(Key) 
       orelse is_binary(Partition) 
       orelse is_binary(Topic)
       orelse is_binary(Value) ->

    brod:produce_sync(Client,Topic, Partition, Key, Value);

send(Client, Args, Value) ->
    ?ERROR("Can't send to Kafka ~p", [{Client, Args, Value}]),
    error.


%%%===================================================================
%%% Internal functions
%%%===================================================================


