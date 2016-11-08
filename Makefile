ERL_INCLUDE_PATH=/usr/local/Cellar/erlang/19.0.2/lib/erlang/usr/include/
OPUS_INCLUDE_PATH=/usr/local/Cellar/opus/1.1.3/include/
OPUS_LIB_PATH=/usr/local/Cellar/opus/1.1.3/lib/

linux: unix

darwin: unix

unix: priv/membrane_element_opus_decoder.so priv/membrane_element_opus_encoder.so

priv/membrane_element_opus_encoder.so: c_src/encoder.c
	cc -fPIC -I../deps/membrane_common_c/include -I./deps/membrane_common_c/include -I$(ERL_INCLUDE_PATH) -I$(OPUS_INCLUDE_PATH) -L$(OPUS_LIB_PATH) -lopus -dynamiclib -undefined dynamic_lookup -o membrane_element_opus_encoder.so c_src/util.c c_src/encoder.c

priv/membrane_element_opus_decoder.so: c_src/decoder.c
	cc -fPIC -I../deps/membrane_common_c/include -I./deps/membrane_common_c/include -I$(ERL_INCLUDE_PATH) -I$(OPUS_INCLUDE_PATH) -L$(OPUS_LIB_PATH) -lopus -dynamiclib -undefined dynamic_lookup -o membrane_element_opus_decoder.so c_src/util.c c_src/decoder.c
