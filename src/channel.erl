-module(channel).

-behaviour(gen_server).

-include("logger.hrl").

%% API
-export([start_link/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {args, to, from, to_encoder, from_decoder}).

%%%===================================================================
%%% API
%%%===================================================================

start_link(ChannelName, Args) ->
    gen_server:start_link({local, ChannelName}, ?MODULE, [Args], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================


init([Args]) ->
    self() ! connect,
    {ok, #state{args = Args}}.


handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.


handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info(connect, #state{args = #{to := {ModuleTo, FunctionTo, ArgsTo},
                                     to_encoder := Encoder,
                                     from_decoder := Decoder,
                                     from := {ModuleFrom, FunctionFrom, ArgsFrom}}} = State) ->
    {ok, To} = erlang:apply(ModuleTo, FunctionTo, ArgsTo),
    {ok, From} = erlang:apply(ModuleFrom, FunctionFrom, ArgsFrom),
    Name = erlang:process_info(self(), registered_name),
    ?INFO("channel ~p ready for processing", [Name]),
    {noreply, State#state{from = From, to = To, to_encoder = Encoder, from_decoder = Decoder}};

handle_info({new_event, Msg},
                        #state{
                            to = To,
                            from_decoder = {DecoderModule, Decoder},
                            to_encoder = {EncoderModule, Encoder}
                        } = State) ->
    ?INFO("received ~p -> ~p ", [Msg, To]),
    {ok, DecodedMsg} = DecoderModule:Decoder(Msg),
    {ok, EncodedMsg} = EncoderModule:Encoder(DecodedMsg),
    _R = To(EncodedMsg),
    {noreply, State};

handle_info(_Info, State) ->
    Name = erlang:process_info(self(), registered_name),
    ?ERROR("Unexpected in ~p INFO: ~p~nState: ~p", [Name, _Info, State]),
    {noreply, State}.


terminate(Reason, #state{from = From, args = #{from := {ModuleFrom, _, _}}}) ->
    ModuleFrom:stop(From),
    Name = erlang:process_info(self(), registered_name),
    ?INFO("Channel ~p turned off ~p", [Reason, Name]),
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
