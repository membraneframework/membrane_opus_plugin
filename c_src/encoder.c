/**
 * Membrane Element: Opus - Erlang native interface for libopus-based encoder
 *
 * All Rights Reserved, (c) 2016 Marcin Lewandowski
 */

#include <stdio.h>
#include <string.h>
#include <erl_nif.h>
#include <opus/opus.h>
#include <membrane/membrane.h>
#include "util.h"

#define MEMBRANE_LOG_TAG "Membrane.Element.Opus.EncoderNative"


#define APPLICATION_ATOM_LEN                 20  // one of voip, audio, restricted_lowdelay, so 19+1 bytes max
#define APPLICATION_ATOM_VOIP                "voip"
#define APPLICATION_ATOM_AUDIO               "audio"
#define APPLICATION_ATOM_RESTRICTED_LOWDELAY "restricted_lowdelay"

ErlNifResourceType *RES_OPUS_ENCODER_TYPE;


void res_opus_encoder_destructor(ErlNifEnv *env, void *encoder) {
  MEMBRANE_DEBUG("Destroying OpusEncoder %p", encoder);
  opus_encoder_destroy((OpusEncoder *) encoder);
}


int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
  int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
  RES_OPUS_ENCODER_TYPE =
    enif_open_resource_type(env, NULL, "OpusEncoder", res_opus_encoder_destructor, flags, NULL);

  return 0;
}


/**
 * Creates Opus encoder.
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
 * On encoder initialization error, returns `{:error, {:create, reason}}`.
 */
static ERL_NIF_TERM export_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  OpusEncoder* enc;
  int          error;
  int          channels;
  int          sample_rate;
  char         application_atom[APPLICATION_ATOM_LEN];
  int          application;


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


  // Get application arg
  if(!enif_get_atom(env, argv[2], (char *) application_atom, APPLICATION_ATOM_LEN, ERL_NIF_LATIN1)) {
    return membrane_util_make_error_args(env, "application", "Passed application is not an atom");
  }

  if(strcmp(application_atom, APPLICATION_ATOM_VOIP) == 0) {
    application = OPUS_APPLICATION_VOIP;

  } else if(strcmp(application_atom, APPLICATION_ATOM_AUDIO) == 0) {
    application = OPUS_APPLICATION_AUDIO;

  } else if(strcmp(application_atom, APPLICATION_ATOM_RESTRICTED_LOWDELAY) == 0) {
    application = OPUS_APPLICATION_RESTRICTED_LOWDELAY;

  } else {
    return membrane_util_make_error_args(env, "application", "Passed sample rate must be one of :voip, :audio or :restricted_lowdelay");
  }


  // Create encoder
  OpusEncoder *encoder = enif_alloc_resource(RES_OPUS_ENCODER_TYPE, opus_encoder_get_size(channels));
  MEMBRANE_DEBUG("Creating OpusEncoder %p", encoder);
  error = opus_encoder_init(encoder, sample_rate, channels, application);
  if(error != OPUS_OK) {
    enif_release_resource(encoder);
    return membrane_util_make_error(env, make_error_from_opus_error(env, "create", error));
  }

  // Wrap encoder into Erlang Resource
  ERL_NIF_TERM encoder_term = enif_make_resource(env, encoder);
  enif_release_resource(encoder);

  return membrane_util_make_ok_tuple(env, encoder_term);
}


/**
 * Sets bitrate of given Opus encoder.
 *
 * Expects 2 arguments:
 *
 * - encoder resource
 * - bitrate (integer) in bits per second in range <500, 512000>.
 *
 * On success, returns `:ok`.
 *
 * On bad arguments passed, returns `{:error, {:args, field, description}}`.
 *
 * On encode error, returns `{:error, {:set_bitrate, reason}}`.
 */
static ERL_NIF_TERM export_set_bitrate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  OpusEncoder *encoder;
  int bitrate;
  int error;


  // Get encoder arg
  if(!enif_get_resource(env, argv[0], RES_OPUS_ENCODER_TYPE, (void **) &encoder)) {
    return membrane_util_make_error_args(env, "encoder", "Passed encoder is not valid resource");
  }



  // Get bitrate arg
  if(!enif_get_int(env, argv[1], &bitrate)) {
    return membrane_util_make_error_args(env, "bitrate", "Passed bitrate is out of integer range or is not an integer");
  }

  if(bitrate < 500 || bitrate > 512000) {
    return membrane_util_make_error_args(env, "bitrate", "Passed bitrate must be betwen 500 and 512000");
  }


  // Set the bitrate
  MEMBRANE_DEBUG("Setting bitrate on OpusEncoder %p to %d", encoder, bitrate);

  error = opus_encoder_ctl(encoder, OPUS_SET_BITRATE(bitrate));
  if(error != OPUS_OK) {
    return make_error_from_opus_error(env, "set_bitrate", error);
  }

  return membrane_util_make_ok(env);
}


/**
 * Gets bitrate of given Opus encoder.
 *
 * Expects 2 arguments:
 *
 * - encoder resource
 *
 * On success, returns `:ok`.
 *
 * On bad arguments passed, returns `{:error, {:args, field, description}}`.
 *
 * On encode error, returns `{:error, {:set_bitrate, reason}}`.
 */
static ERL_NIF_TERM export_get_bitrate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  OpusEncoder *encoder;
  int bitrate;
  int error;


  // Get encoder arg
  if(!enif_get_resource(env, argv[0], RES_OPUS_ENCODER_TYPE, (void **) &encoder)) {
    return membrane_util_make_error_args(env, "encoder", "Passed encoder is not valid resource");
  }



  // Get the bitrate
  MEMBRANE_DEBUG("Getting bitrate from OpusEncoder %p", encoder);

  error = opus_encoder_ctl(encoder, OPUS_GET_BITRATE(&bitrate));
  if(error != OPUS_OK) {
    return make_error_from_opus_error(env, "get_bitrate", error);
  }

  return membrane_util_make_ok_tuple(env, enif_make_int(env, bitrate));
}


/**
 * Encodes chunk of input signal that uses S16LE format.
 *
 * Expects 3 arguments:
 *
 * - encoder resource
 * - input signal (bitstring), containing PCM data (interleaved if 2 channels).
 *   length is frame_size*channels*2
 * - frame size (integer), Number of samples per channel in the input signal.
 *   This must be an Opus frame size for the encoder's sampling rate. For
 *   example, at 48 kHz the permitted values are 120, 240, 480, 960, 1920, and
 *   2880. Passing in a duration of less than 10 ms (480 samples at 48 kHz) will
 *   prevent the encoder from using the LPC or hybrid modes.
 *
 * Constraints for input signal and frame size are not validated for performance
 * reasons - it's programmer's fault to break them.
 *
 * On success, returns `{:ok, data}`.
 *
 * On bad arguments passed, returns `{:error, {:args, field, description}}`.
 *
 * On encode error, returns `{:error, {:encode, reason}}`.
 */
static ERL_NIF_TERM export_encode_int(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  OpusEncoder *encoder;
  int error;
  int frame_size;
  int sample_rate;
  ErlNifBinary input_signal_binary;


  // Get encoder arg
  if(!enif_get_resource(env, argv[0], RES_OPUS_ENCODER_TYPE, (void **) &encoder)) {
    return membrane_util_make_error_args(env, "encoder", "Passed encoder is not valid resource");
  }


  // Get input signal arg
  if(!enif_inspect_binary(env, argv[1], &input_signal_binary)) {
    return membrane_util_make_error_args(env, "encoder", "Passed input_signal is not valid binary");
  }

  // Get frame size arg
  if(!enif_get_int(env, argv[2], &frame_size)) {
    return membrane_util_make_error_args(env, "frame_size", "Passed frame size is out of integer range or is not an integer");
  }


  // Allocate temporary storage for the output, it is not going to be larger
  // than input signal for sure.
  unsigned char *encoded_signal_data_temp = malloc(input_signal_binary.size);

  // Encode
  opus_int32 encoded_size = opus_encode(encoder, (const opus_int16 *) input_signal_binary.data, frame_size, encoded_signal_data_temp, input_signal_binary.size);
  if(encoded_size < 0) {
    free(encoded_signal_data_temp);
    return make_error_from_opus_error(env, "encode", encoded_size);
  }

  // Prepare return value
  ERL_NIF_TERM encoded_signal_term;
  unsigned char *encoded_signal_data = enif_make_new_binary(env, encoded_size, &encoded_signal_term);
  memcpy(encoded_signal_data, encoded_signal_data_temp, encoded_size);
  free(encoded_signal_data_temp);

  return membrane_util_make_ok_tuple(env, encoded_signal_term);
}



static ErlNifFunc nif_funcs[] =
{
  {"create", 3, export_create},
  {"set_bitrate", 2, export_set_bitrate},
  {"get_bitrate", 1, export_get_bitrate},
  {"encode_int", 3, export_encode_int}
};

ERL_NIF_INIT(Elixir.Membrane.Element.Opus.EncoderNative, nif_funcs, load, NULL, NULL, NULL)
