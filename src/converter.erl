-module(converter).
-author("eugene").

-include("logger.hrl").

%% API
-export([identity/1, json_encoder/1, msgpack_decoder/1]).

-spec msgpack_decoder(binary()) -> {ok, term()} | {error, decoder_error}.
msgpack_decoder(Msg) when is_binary(Msg) ->
    try
        {ok, _} = msgpack:unpack(Msg, [{unpack_str, as_binary}])
    catch _:_ ->
        ?ERROR("Can't decode messagepack binary: ~p", [Msg]),
        {error, decoder_error}
    end.

-spec json_encoder(term()) -> {ok, binary()} | {error, encoder_error}.
json_encoder(Msg) ->
    try
        {ok, jsx:encode(Msg)}
    catch _:_ ->
        ?ERROR("Can't encode message to json: ~p", [Msg]),
        {error, encoder_error}
    end.

-spec identity(term()) -> {ok, term()}.
identity(Msg) ->
    {ok, Msg}.
