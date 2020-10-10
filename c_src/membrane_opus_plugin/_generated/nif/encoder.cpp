#include "encoder.h"

UNIFEX_TERM create_result(UnifexEnv* env, UnifexState* state) {
  return unifex_make_resource(env, state);
}

UNIFEX_TERM encode_packet_result_ok(UnifexEnv* env, UnifexPayload * payload) {
  return ({
      const ERL_NIF_TERM terms[] = {
        enif_make_atom(env, "ok"),
unifex_payload_to_term(env, payload)
      };
      enif_make_tuple_from_array(env, terms, 2);
    });
}

UNIFEX_TERM encode_packet_result_error(UnifexEnv* env, const  char* reason) {
  return ({
      const ERL_NIF_TERM terms[] = {
        enif_make_atom(env, "error"),
enif_make_atom(env, reason)
      };
      enif_make_tuple_from_array(env, terms, 2);
    });
}

UNIFEX_TERM destroy_result(UnifexEnv* env) {
  return enif_make_atom(env, "ok");
}



static int unifex_load_nif(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  UNIFEX_UNUSED(load_info);
  UNIFEX_UNUSED(priv_data);

  ErlNifResourceFlags flags = (ErlNifResourceFlags) (ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER);

  

  UNIFEX_PAYLOAD_GUARD_RESOURCE_TYPE =
    enif_open_resource_type(env, NULL, "UnifexPayloadGuard", (ErlNifResourceDtor*) unifex_payload_guard_destructor, flags, NULL);

  return 0;
}



static ERL_NIF_TERM export_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
  UNIFEX_UNUSED(argc);
  ERL_NIF_TERM result;
  
  UnifexEnv *unifex_env = env;
  int input_rate;
int channels;
int application;
int frame_size;

  




  if(!enif_get_int(env, argv[0], &input_rate)) {
  result = unifex_raise_args_error(env, "input_rate", ":int");
  goto exit_export_create;
}

if(!enif_get_int(env, argv[1], &channels)) {
  result = unifex_raise_args_error(env, "channels", ":int");
  goto exit_export_create;
}

if(!enif_get_int(env, argv[2], &application)) {
  result = unifex_raise_args_error(env, "application", ":int");
  goto exit_export_create;
}

if(!enif_get_int(env, argv[3], &frame_size)) {
  result = unifex_raise_args_error(env, "frame_size", ":int");
  goto exit_export_create;
}


  result = create(unifex_env, input_rate, channels, application, frame_size);
  goto exit_export_create;
exit_export_create:
  
  return result;
}

static ERL_NIF_TERM export_encode_packet(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
  UNIFEX_UNUSED(argc);
  ERL_NIF_TERM result;
  
  UnifexEnv *unifex_env = env;
  UnifexState* state;
UnifexPayload * payload;

  
payload = (UnifexPayload *) unifex_alloc(sizeof (UnifexPayload));

  if(!enif_get_resource(env, argv[0], STATE_RESOURCE_TYPE, (void **)&state)) {
  result = unifex_raise_args_error(env, "state", ":state");
  goto exit_export_encode_packet;
}

if(!unifex_payload_from_term(env, argv[1], payload)) {
  result = unifex_raise_args_error(env, "payload", ":payload");
  goto exit_export_encode_packet;
}


  result = encode_packet(unifex_env, state, payload);
  goto exit_export_encode_packet;
exit_export_encode_packet:
  unifex_payload_release_ptr(&payload);
  return result;
}

static ERL_NIF_TERM export_destroy(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
  UNIFEX_UNUSED(argc);
  ERL_NIF_TERM result;
  
  UnifexEnv *unifex_env = env;
  UnifexState* state;

  

  if(!enif_get_resource(env, argv[0], STATE_RESOURCE_TYPE, (void **)&state)) {
  result = unifex_raise_args_error(env, "state", ":state");
  goto exit_export_destroy;
}


  result = destroy(unifex_env, state);
  goto exit_export_destroy;
exit_export_destroy:
  
  return result;
}

static ErlNifFunc nif_funcs[] =
{
  {"unifex_create", 4, export_create, 0},
{"unifex_encode_packet", 2, export_encode_packet, 0},
{"unifex_destroy", 1, export_destroy, 0}
};

ERL_NIF_INIT(Elixir.Membrane.Opus.Encoder.Native.Nif, nif_funcs, unifex_load_nif, NULL, NULL, NULL)

