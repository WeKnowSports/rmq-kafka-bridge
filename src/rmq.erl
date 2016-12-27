-module(rmq).

-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("logger.hrl").

%% -define(DEV_URI,"amqp://messagebus:messagebus@rabbitmqphy/messagebus_master").


%% API
-export([start_link/1, stop/1]).

%% 
-export([subscribe/1, subscribe/2, subscribe/3, unsubscribe/1, publish/4]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, 
        { subscriber :: pid() | undefined,
          rmq_params = #{} :: raw_rmq:rmq_params(),
          uri = [] :: list()}).

%%%===================================================================
%%% API
%%%===================================================================


start_link(Args) ->
    gen_server:start_link(?MODULE, [Args], []).

subscribe(#{connection := URI, exchange := Exchange, routing_key := RK}) ->
    {ok, Pid} = ?MODULE:start_link(URI),
    ok = ?MODULE:subscribe(Pid, Exchange, RK),
    {ok, Pid}.

subscribe(Pid, Exchange) ->
    subscribe(Pid, Exchange, <<"*">>).

subscribe(Pid, Exchange, RK) ->
    gen_server:call(Pid, {subscribe, Exchange, RK}).

publish(Pid, Exchange, RK, Payload) ->
    gen_server:cast(Pid, {publish, Exchange, RK, Payload}).

unsubscribe(Pid) ->
    gen_server:call(Pid, unsubscribe).

stop(Pid) ->
    gen_server:stop(Pid).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

-spec init([string()]) -> {ok, #state{}}.

init([URI]) ->
    self() ! {connect, URI},
    {ok, #state{}}.


handle_call({subscribe, Exchange, Rk}, {SubscriberPid, _Tag} = _From, #state{rmq_params = RmqParams} = State) ->
    {ok, RmqParams1} = rmq_raw:subscribe(RmqParams#{exchange => Exchange, routing_key => Rk}),
    {reply, ok, State#state{rmq_params = RmqParams1, subscriber = SubscriberPid}};

handle_call(unsubscribe, _From, #state{rmq_params = RmqParams} = State) ->
    {ok, RmqParams1} = rmq_raw:unsubscribe(RmqParams),
    {reply, ok, State#state{rmq_params = RmqParams1}};

handle_call(_Request, _From, State) ->
    ?ERROR("Unexpected call ~p", [_Request]),
    {reply, ok, State}.


handle_cast({publish, Exchange, RK, Payload}, #state{rmq_params = RmqParams} = State) ->
    rmq_raw:publish(RmqParams#{exchange => Exchange, routing_key => RK, payload => Payload}),
    {noreply, State};

handle_cast(_Msg, State) ->
    ?ERROR("Unexpected cast ~p", [_Msg]),
    {noreply, State}.


handle_info({connect, URI}, State) ->
    {ok, RmqParams}= rmq_raw:connect(URI),
    {noreply, State#state{rmq_params = RmqParams}};

%% Deliver messages from RMQ to subscriber
handle_info( {#'basic.deliver'{}, #'amqp_msg'{payload = Payload} = _Message}, #state{subscriber = Subscriber} = State)
  when is_pid(Subscriber) ->
    Subscriber ! {new_event, Payload},
    {noreply, State};

handle_info({'basic.consume_ok', _Tag}, State) ->
    {noreply, State};

handle_info({'basic.cancel_ok', _Tag}, State) ->
    {noreply, State};

handle_info(_Info, State) ->
    ?ERROR("Unexpected info ~p", [_Info]),
    {noreply, State}.


terminate(_Reason, #state{rmq_params = RmqParams}) ->
    {ok, #{}} = rmq_raw:close(RmqParams),
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


