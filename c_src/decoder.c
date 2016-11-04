/**
 * Membrane Element: Opus - Erlang native interface for libopus-based decoder
 *
 * All Rights Reserved, (c) 2016 Marcin Lewandowski
 */

#include <stdio.h>
#include <string.h>
#include <erl_nif.h>
#include <opus/opus.h>
#include <membrane/membrane.h>
#include "util.h"

#define MEMBRANE_LOG_TAG "Membrane.Element.Opus.DecoderNative"


ErlNifResourceType *RES_OPUS_DECODER_TYPE;


void res_opus_decoder_destructor(ErlNifEnv *env, void *decoder) {
  MEMBRANE_DEBUG("Destroying OpusDecoder %p", decoder);
  opus_decoder_destroy((OpusDecoder *) decoder);
}


int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
  int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
  RES_OPUS_DECODER_TYPE =
    enif_open_resource_type(env, NULL, "OpusDecoder", res_opus_decoder_destructor, flags, NULL);

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
  OpusDecoder* enc;
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



  // Create decoder
  OpusDecoder *decoder = enif_alloc_resource(RES_OPUS_DECODER_TYPE, opus_decoder_get_size(channels));
  MEMBRANE_DEBUG("Creating OpusDecoder %p", decoder);
  error = opus_decoder_init(decoder, sample_rate, channels);
  if(error != OPUS_OK) {
    enif_release_resource(decoder);
    return membrane_util_make_error(env, make_error_from_opus_error(env, "create", error));
  }

  // Wrap decoder into Erlang Resource
  ERL_NIF_TERM decoder_term = enif_make_resource(env, decoder);
  enif_release_resource(decoder);

  return membrane_util_make_ok_tuple(env, decoder_term);
}


static ErlNifFunc nif_funcs[] =
{
  {"create", 2, export_create},
};

ERL_NIF_INIT(Elixir.Membrane.Element.Opus.DecoderNative, nif_funcs, load, NULL, NULL, NULL)
