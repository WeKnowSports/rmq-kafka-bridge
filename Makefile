PROJECT = cgate
PROJECT_DESCRIPTION = Cgate RMQ -> Kafka bridge 
PROJECT_VERSION = 0.1.0

ERLC_OPTS = +debug_info +warn_missing_spec +bin_opt_info

DEPS = amqp_client supervisor3 kafka_protocol brod msgpack jsx

CT_OPTS = -config test/test.spec

include erlang.mk
