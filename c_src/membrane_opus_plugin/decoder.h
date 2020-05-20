#pragma once

#define MEMBRANE_LOG_TAG "Membrane.Opus.DecoderNative"
#include <membrane/log.h>
#include <opus/opus.h>

#include "stdint.h"

typedef struct _DecoderState UnifexNifState;
typedef UnifexNifState State;

struct _DecoderState {
  int channels;
  size_t sample_rate;
  OpusDecoder *decoder;
};

#include "_generated/decoder.h"
