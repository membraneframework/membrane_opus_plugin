/**
 * Membrane Element: Opus - Erlang native interface for libopus-based
 *
 * Helpful routines for both encoder and decoder.
 *
 * All Rights Reserved, (c) 2016 Marcin Lewandowski
 */


#ifndef __MEMBRANE_ELEMENT_OPUS_UTIL_H__
#define __MEMBRANE_ELEMENT_OPUS_UTIL_H__

#include <erl_nif.h>
#include <opus/opus.h>
#include <membrane/membrane.h>

ERL_NIF_TERM opus_error_to_atom(ErlNifEnv* env, int error);
ERL_NIF_TERM make_error_from_opus_error(ErlNifEnv* env, const char* func, int error);

#endif
