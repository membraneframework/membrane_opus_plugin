ERL_INCLUDE_PATH=/usr/local/Cellar/erlang/19.0.2/lib/erlang/usr/include/

all: priv/encoder.so

priv/encoder.so: c_src/encoder.c
	cc -fPIC -I$(ERL_INCLUDE_PATH) -dynamiclib -undefined dynamic_lookup -o encoder.so c_src/encoder.c
