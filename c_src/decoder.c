/**
 * Membrane Element: Opus - Erlang native interface for libopus-based decoder
 *
 * All Rights Reserved, (c) 2016 Marcin Lewandowski
 */

#include "decoder.h"
#define UNUSED(x) (void)(x)

ErlNifResourceType *RES_OPUS_DECODER_HANDLE_TYPE;


void res_opus_decoder_handle_destructor(ErlNifEnv *env, void *data) {
  UNUSED(env);

  MEMBRANE_DEBUG("Destroying DecoderHandle %p", data);
}


int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
  UNUSED(priv_data);
  UNUSED(load_info);
    
  int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
  RES_OPUS_DECODER_HANDLE_TYPE =
    enif_open_resource_type(env, NULL, "OpusDecoder", res_opus_decoder_handle_destructor, flags, NULL);

  return 0;
}



/**
 * Creates Opus decoder.
 *
 * Expects 3 arguments:
 *
 * - sample rate (integer, one of 8000, 12000, 16000, 24000, or 48000)
 * - channels (integer, 1 or 2)
 * - application (atom, one of `:voip`, `:audio` or `:restricted_lowdelay`).
 *
 * On success, returns `{:ok, resource}`.
 *
 * On bad arguments passed, returns `{:error, {:args, field, description}}`.
 *
 * On decoder initialization error, returns `{:error, {:create, reason}}`.
 */
static ERL_NIF_TERM export_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  UNUSED(argc);
  int          error;
  int          channels;
  int          sample_rate;


  // Get sample rate arg
  if(!enif_get_int(env, argv[0], &sample_rate)) {
    return membrane_util_make_error_args(env, "sample_rate", "Passed sample rate is out of integer range or is not an integer");
  }

  if(sample_rate != 8000 && sample_rate != 12000 && sample_rate != 16000 && sample_rate != 24000 && sample_rate != 48000) {
    return membrane_util_make_error_args(env, "sample_rate", "Passed sample rate must be one of 8000, 12000, 16000, 24000, or 48000");
  }


  // Get channels arg
  if(!enif_get_int(env, argv[1], &channels)) {
    return membrane_util_make_error_args(env, "channels", "Passed channels is out of integer range or is not an integer");
  }

  if(channels != 1 && channels != 2) {
    return membrane_util_make_error_args(env, "channels", "Passed channels must be one of 1 or 2");
  }



  // Create DecoderHandle
  DecoderHandle* handle = enif_alloc_resource(RES_OPUS_DECODER_HANDLE_TYPE, sizeof(DecoderHandle));
  handle->decoder = malloc(opus_decoder_get_size(channels));
  handle->channels = channels;
  handle->sample_rate = sample_rate;

  // Create decoder
  MEMBRANE_DEBUG("Creating OpusDecoder %p, sample rate = %d Hz, channels = %d", handle->decoder, sample_rate, channels);
  error = opus_decoder_init(handle->decoder, sample_rate, channels);
  if(error != OPUS_OK) {
    free(handle->decoder);
    enif_release_resource(handle);
    return membrane_util_make_error(env, make_error_from_opus_error(env, "create", error));
  }

  // Wrap decoder into Erlang Resource
  ERL_NIF_TERM handle_term = enif_make_resource(env, handle);
  enif_release_resource(handle);

  return membrane_util_make_ok_tuple(env, handle_term);
}


/**
 * Decodes chunk of input payload.
 *
 * Expects 3 arguments:
 *
 * - decoder_handle resource
 * - input payload (bitstring), pass nil to indicate data loss
 * - whether to decode FEC (0 - false, 1 - true)
 * - duration of audio to decode in milliseconds
 *
 * On success, returns `{:ok, data}`.
 *
 * On bad arguments passed, returns `{:error, {:args, field, description}}`.
 *
 * On decode error, returns `{:error, {:decode, reason}}`.
 */
static ERL_NIF_TERM export_decode_int(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  UNUSED(argc);
  DecoderHandle *handle;
  ErlNifBinary input_payload_binary;
  int use_fec;
  int frame_duration;

  // Get decoder arg
  if(!enif_get_resource(env, argv[0], RES_OPUS_DECODER_HANDLE_TYPE, (void **) &handle)) {
    return membrane_util_make_error_args(env, "decoder_handle", "Passed decoder_handle is not valid resource");
  }


  // Get input signal arg
  if(!enif_inspect_binary(env, argv[1], &input_payload_binary)) {
    return membrane_util_make_error_args(env, "input_payload", "Passed input_payload is not valid binary");
  }


  // Get use_fec arg
  if(!enif_get_int(env, argv[2], &use_fec)) {
    return membrane_util_make_error_args(env, "use_fec", "Passed use_fec in not valid integer");
  }


  // Get frame_duration arg
  if(!enif_get_int(env, argv[3], &frame_duration)) {
    return membrane_util_make_error_args(env, "frame_duration", "Passed frame_duration in not valid integer");
  }


  // Allocate temporary storage for the output.
  size_t output_samples, output_bytes;
  output_samples = (handle->sample_rate * frame_duration) / 1000;
  output_bytes = output_samples * BYTES_PER_OUTPUT_SAMPLE * handle->channels;

  opus_int16 *decoded_signal_data_temp = malloc(output_bytes);


  // Decode
  int use_plc = (input_payload_binary.size == 0);

  int decoded_samples = opus_decode(handle->decoder, use_plc ? NULL : input_payload_binary.data, input_payload_binary.size, decoded_signal_data_temp, output_samples, use_fec);

  if(decoded_samples < 0) {
    free(decoded_signal_data_temp);
    return make_error_from_opus_error(env, "decode", decoded_samples);
  }

  if ((unsigned int)decoded_samples != output_samples) {
    free(decoded_signal_data_temp);
    return membrane_util_make_error(env, enif_make_atom(env, "invalid_frame_size"));
  }


  // Prepare return value
  ERL_NIF_TERM decoded_signal_term;
  unsigned char *decoded_signal_data = enif_make_new_binary(env, output_bytes, &decoded_signal_term);
  memcpy(decoded_signal_data, decoded_signal_data_temp, output_bytes);
  free(decoded_signal_data_temp);

  return membrane_util_make_ok_tuple(env, decoded_signal_term);
}


static ErlNifFunc nif_funcs[] =
{
  {"create", 2, export_create, 0},
  {"decode_int", 4, export_decode_int, 0}
};

ERL_NIF_INIT(Elixir.Membrane.Element.Opus.DecoderNative, nif_funcs, load, NULL, NULL, NULL)
