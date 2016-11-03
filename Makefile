ERL_INCLUDE_PATH=/usr/local/Cellar/erlang/19.0.2/lib/erlang/usr/include/
OPUS_INCLUDE_PATH=/usr/local/Cellar/opus/1.1.3/include/
OPUS_LIB_PATH=/usr/local/Cellar/opus/1.1.3/lib/

all: priv/encoder.so

priv/encoder.so: c_src/encoder.c
	cc -fPIC -I$(ERL_INCLUDE_PATH) -I$(OPUS_INCLUDE_PATH) -L$(OPUS_LIB_PATH) -lopus -dynamiclib -undefined dynamic_lookup -o encoder.so c_src/encoder.c
