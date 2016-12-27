{cgate,
 [{kafka_config, 
   #{kafka_client => kafka_test_client,
     host_port => [{"kafka-test", 9092}],
     topics => [#{key => <<"1">>,
                  partition => 0,
                  topic => <<"test">>
                 }]}},
  {rmq_config, {"amqp://user:password@rmq-test/messagebus_test", <<"test.exchange">>}},
  {channels, [
              {channel_test,
               #{from => {rmq, subscribe,
                          [#{connection => "amqp://user:password@rmq-test/messagebus_test",
                             exchange => <<"test.exchange">>,
                             routing_key => <<"#">>}]}
                ,
                 from_decoder => {converter, msgpack_decoder}
                ,
                 to_encoder => {converter, json_encoder}
                ,
                to => {kafka, publish,
                       [#{host_port => [{"kafka-test", 9092}],
                          kafka_client => kafka_client_1,
                          topics => [#{key => <<"test">>,
                                       partition => 0,
                                       topic => <<"topic_test">>}]}]}
               }
             }
            ]
 }]}.
