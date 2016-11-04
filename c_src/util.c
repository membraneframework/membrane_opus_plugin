/**
 * Membrane Element: Opus - Erlang native interface for libopus-based
 * Common routines.
 *
 * All Rights Reserved, (c) 2016 Marcin Lewandowski
 */


#include "util.h"


/**
 * Converts given Opus error code into atom.
 */
ERL_NIF_TERM opus_error_to_atom(ErlNifEnv* env, int error) {
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
ERL_NIF_TERM make_error_from_opus_error(ErlNifEnv* env, const char* func, int error) {
  ERL_NIF_TERM tuple[2] = {
    enif_make_atom(env, func),
    opus_error_to_atom(env, error)
  };

  return membrane_util_make_error(env, enif_make_tuple_from_array(env, tuple, 2));
}
