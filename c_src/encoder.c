/**
 * Membrane Element: Opus - Erlang native interface for libopus-based encoder
 *
 * All Rights Reserved, (c) 2016 Marcin Lewandowski
 */

#include <stdio.h>
#include <string.h>
#include <erl_nif.h>
#include <opus/opus.h>

#define MEMBRANE_LOG_TAG "Membrane.Element.Opus.EncoderNative"


// ===== START COMMON =====
// TODO to be extracted to a separate helper lib

// FIXME
#define MEMBRANE_DEBUG(message, ...) fprintf(stderr, "[%s] " message "\n", MEMBRANE_LOG_TAG, ##__VA_ARGS__);


/**
 * Builds `{:error, reason}`.
 */
static ERL_NIF_TERM membrane_util_make_error(ErlNifEnv* env, ERL_NIF_TERM reason) {
  ERL_NIF_TERM tuple[2] = {
    enif_make_atom(env, "error"),
    reason
  };

  return enif_make_tuple_from_array(env, tuple, 2);
}


/**
 * Builds `{:ok, arg}`.
 */
static ERL_NIF_TERM membrane_util_make_ok_tuple(ErlNifEnv* env, ERL_NIF_TERM arg) {
  ERL_NIF_TERM tuple[2] = {
    enif_make_atom(env, "ok"),
    arg
  };

  return enif_make_tuple_from_array(env, tuple, 2);
}


/**
 * Builds `:ok`.
 */
static ERL_NIF_TERM membrane_util_make_ok(ErlNifEnv* env) {
  return enif_make_atom(env, "ok");
}


/**
 * Builds `:todo`.
 */
static ERL_NIF_TERM membrane_util_make_todo(ErlNifEnv* env) {
  return enif_make_atom(env, "todo");
}


/**
 * Builds `{:error, {:args, field, description}}` for returning when
 * certain constructor-style functions get invalid arguments.
 */
static ERL_NIF_TERM membrane_util_make_error_args(ErlNifEnv* env, const char* field, const char *description) {
  ERL_NIF_TERM tuple[3] = {
    enif_make_atom(env, "args"),
    enif_make_atom(env, field),
    enif_make_string(env, description, ERL_NIF_LATIN1)
  };

  return membrane_util_make_error(env, enif_make_tuple_from_array(env, tuple, 3));
}

// ===== END COMMON =====



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
 * Converts given Opus error code into atom.
 */
static ERL_NIF_TERM opus_error_to_atom(ErlNifEnv* env, int error) {
  switch(error) {
    case OPUS_ALLOC_FAIL:       return enif_make_atom(env, "alloc_fail");
    case OPUS_BAD_ARG:          return enif_make_atom(env, "bad_arg");
    case OPUS_BUFFER_TOO_SMALL: return enif_make_atom(env, "buffer_too_small");
    case OPUS_INTERNAL_ERROR:   return enif_make_atom(env, "internal_error");
    case OPUS_INVALID_PACKET:   return enif_make_atom(env, "invalid_packet");
    case OPUS_INVALID_STATE:    return enif_make_atom(env, "invalid_state");
    case OPUS_UNIMPLEMENTED:    return enif_make_atom(env, "unimplemented");
    default:                    return enif_make_atom(env, "unknown");
  }
}


/**
 * Builds `{:error, {function, error}` based on given opus error.
 */
static ERL_NIF_TERM make_error_from_opus_error(ErlNifEnv* env, const char* func, int error) {
  ERL_NIF_TERM tuple[2] = {
    enif_make_atom(env, func),
    opus_error_to_atom(env, error)
  };

  return membrane_util_make_error(env, enif_make_tuple_from_array(env, tuple, 2));
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
  OpusEncoder **encoder_res;
  OpusEncoder *encoder;
  int bitrate;
  int error;


  // Get encoder arg
  if(!enif_get_resource(env, argv[0], RES_OPUS_ENCODER_TYPE, (void *) encoder_res)) {
    return membrane_util_make_error_args(env, "encoder", "Passed encoder is not valid resource");
  }

  encoder = *encoder_res;


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
  OpusEncoder **encoder_res;
  OpusEncoder *encoder;
  int bitrate;
  int error;


  // Get encoder arg
  if(!enif_get_resource(env, argv[0], RES_OPUS_ENCODER_TYPE, (void *) encoder_res)) {
    return membrane_util_make_error_args(env, "encoder", "Passed encoder is not valid resource");
  }

  encoder = *encoder_res;


  // Get the bitrate
  MEMBRANE_DEBUG("Getting bitrate from OpusEncoder %p", encoder);

  error = opus_encoder_ctl(encoder, OPUS_GET_BITRATE(&bitrate));
  if(error != OPUS_OK) {
    return make_error_from_opus_error(env, "get_bitrate", error);
  }

  return membrane_util_make_ok_tuple(env, enif_make_int(env, bitrate));
}


/**
 * Encodes chunk of input signal.
 *
 * Expects 3 arguments:
 *
 * - encoder resource
 * - input signal (bitstring), containing PCM data (interleaved if 2 channels).
 *   length is frame_size*channels*sizeof(opus_int16)
 * - frame size (integer), Number of samples per channel in the input signal.
 *   This must be an Opus frame size for the encoder's sampling rate. For
 *   example, at 48 kHz the permitted values are 120, 240, 480, 960, 1920, and
 *   2880. Passing in a duration of less than 10 ms (480 samples at 48 kHz) will
 *   prevent the encoder from using the LPC or hybrid modes.
 *
 * On success, returns `{:ok, data}`.
 *
 * On bad arguments passed, returns `{:error, {:args, field, description}}`.
 *
 * On encode error, returns `{:error, {:encode, reason}}`.
 */
static ERL_NIF_TERM export_encode(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  return membrane_util_make_todo(env);
}



static ErlNifFunc nif_funcs[] =
{
  {"create", 3, export_create},
  {"set_bitrate", 2, export_set_bitrate},
  {"get_bitrate", 1, export_get_bitrate},
  {"encode", 3, export_encode}
};

ERL_NIF_INIT(Elixir.Membrane.Element.Opus.EncoderNative, nif_funcs, load, NULL, NULL, NULL)
