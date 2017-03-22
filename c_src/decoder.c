/**
 * Membrane Element: Opus - Erlang native interface for libopus-based decoder
 *
 * All Rights Reserved, (c) 2016 Marcin Lewandowski
 */

#include "decoder.h"


ErlNifResourceType *RES_OPUS_DECODER_HANDLE_TYPE;


void res_opus_decoder_handle_destructor(ErlNifEnv *env, void *data) {
  DecoderHandle *handle = (DecoderHandle *)data;
  MEMBRANE_DEBUG("Destroying OpusDecoder %p", handle->decoder);
  opus_decoder_destroy(handle->decoder);
}


int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
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
 * - whether to decode FEC (boolean)
 * - duration of the missing frame in milliseconds (or 0 if no frame is missing)
 *
 * On success, returns `{:ok, {data, channels}}`.
 *
 * On bad arguments passed, returns `{:error, {:args, field, description}}`.
 *
 * On decode error, returns `{:error, {:decode, reason}}`.
 */
static ERL_NIF_TERM export_decode_int(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  DecoderHandle *handle;
  ErlNifBinary input_payload_binary;
  int decode_fec;
  int missing_frame_duration;

  // Get decoder arg
  if(!enif_get_resource(env, argv[0], RES_OPUS_DECODER_HANDLE_TYPE, (void **) &handle)) {
    return membrane_util_make_error_args(env, "decoder_handle", "Passed decoder_handle is not valid resource");
  }


  // Get input signal arg
  if(!enif_inspect_binary(env, argv[1], &input_payload_binary)) {
    return membrane_util_make_error_args(env, "input_payload", "Passed input_payload is not valid binary");
  }

  // TODO handle nil


  // Get decode FEC arg
  if(!enif_get_int(env, argv[2], &decode_fec)) {
    return membrane_util_make_error_args(env, "decode_fec", "Passed decode_fec in not valid integer");
  }


  // Get missing_frame_duration arg
  if(!enif_get_int(env, argv[3], &missing_frame_duration)) {
    return membrane_util_make_error_args(env, "missing_frame_duration", "Passed missing_frame_duration in not valid integer");
  }


  // Allocate temporary storage for the output, let's allocate maximum allowed
  // by Opus (for 120ms of data) or exact size of audio that is missing
  size_t output_size;

  if(!missing_frame_duration) {
    output_size = (BYTES_PER_OUTPUT_SAMPLE * handle->channels *
      handle->sample_rate * OPUS_FRAME_MAX_DURATION) / 1000;
  } else {
    output_size = (BYTES_PER_OUTPUT_SAMPLE * handle->channels *
      handle->sample_rate * missing_frame_duration) / 1000;
  }

  opus_int16 *decoded_signal_data_temp = malloc(output_size);


  // Decode
  int channels = handle->channels;
  if(channels < 0) {
    return make_error_from_opus_error(env, "decode", channels);
  }

  int decoded_samples = opus_decode(handle->decoder, input_payload_binary.data, input_payload_binary.size, decoded_signal_data_temp, output_size, decode_fec);
  if(decoded_samples < 0) {
    free(decoded_signal_data_temp);
    return make_error_from_opus_error(env, "decode", decoded_samples);
  }

  // Prepare return value
  ERL_NIF_TERM decoded_signal_term;
  size_t decoded_signal_size = decoded_samples * channels * 2;
  unsigned char *decoded_signal_data = enif_make_new_binary(env, decoded_signal_size, &decoded_signal_term);
  memcpy(decoded_signal_data, decoded_signal_data_temp, decoded_signal_size);
  free(decoded_signal_data_temp);

  ERL_NIF_TERM tuple[2] = {
    decoded_signal_term,
    enif_make_int(env, channels)
  };

  return membrane_util_make_ok_tuple(env, enif_make_tuple_from_array(env, tuple, 2));
}


static ErlNifFunc nif_funcs[] =
{
  {"create", 2, export_create},
  {"decode_int", 4, export_decode_int}
};

ERL_NIF_INIT(Elixir.Membrane.Element.Opus.DecoderNative, nif_funcs, load, NULL, NULL, NULL)
