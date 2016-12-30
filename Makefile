ERL_INCLUDE_PATH_DARWIN=/usr/local/Cellar/erlang/19.2/lib/erlang/usr/include/
OPUS_INCLUDE_PATH_DARWIN=/usr/local/Cellar/opus/1.1.3/include/
OPUS_LIB_PATH_DARWIN=/usr/local/Cellar/opus/1.1.3/lib/

ERL_INCLUDE_PATH_WINDOWS="c:\\Program Files\\erl8.0\\erts-8.0\\include"
OPUS_INCLUDE_PATH_WINDOWS=".\\ext\\include"
OPUS_LIB_PATH_WINDOWS=".\\ext\\windows\\64"

windows: windows_decoder windows_encoder
darwin: darwin_decoder darwin_encoder

darwin_encoder: c_src/encoder.c
	cc -fPIC -I../membrane_common_c/include -I./deps/membrane_common_c/include -I$(ERL_INCLUDE_PATH_DARWIN) -I$(OPUS_INCLUDE_PATH_DARWIN) -L$(OPUS_LIB_PATH_DARWIN) -lopus -dynamiclib -undefined dynamic_lookup -o membrane_element_opus_encoder.so c_src/util.c c_src/encoder.c

darwin_decoder: c_src/decoder.c
	cc -fPIC -I../membrane_common_c/include -I./deps/membrane_common_c/include -I$(ERL_INCLUDE_PATH_DARWIN) -I$(OPUS_INCLUDE_PATH_DARWIN) -L$(OPUS_LIB_PATH_DARWIN) -lopus -dynamiclib -undefined dynamic_lookup -o membrane_element_opus_decoder.so c_src/util.c c_src/decoder.c

windows_encoder: c_src/encoder.c
  cl /LD /I ..\\membrane_common_c\\include /I .\\deps\\membrane_common_c\\include /I $(ERL_INCLUDE_PATH_WINDOWS) /I $(OPUS_INCLUDE_PATH_WINDOWS) c_src/encoder.c c_src/util.c opus.lib celt.lib silk_common.lib silk_float.lib /link /LIBPATH:$(OPUS_LIB_PATH_WINDOWS) /OUT:membrane_element_opus_encoder.dll

windows_decoder: c_src/decoder.c
  cl /LD /I ..\\membrane_common_c\\include /I .\\deps\\membrane_common_c\\include /I $(ERL_INCLUDE_PATH_WINDOWS) /I $(OPUS_INCLUDE_PATH_WINDOWS) c_src/decoder.c c_src/util.c opus.lib celt.lib silk_common.lib silk_float.lib /link /LIBPATH:$(OPUS_LIB_PATH_WINDOWS) /OUT:membrane_element_opus_decoder.dll
