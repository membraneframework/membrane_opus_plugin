#pragma once

#define MEMBRANE_LOG_TAG "Membrane.Opus.EncoderNative"
#include <membrane/log.h>
#include <opus/opus.h>

typedef struct _EncoderState UnifexNifState;
typedef UnifexNifState State;

struct _EncoderState {
  struct OpusEncoder *encoder;
  unsigned char *buffer;
};

#include "_generated/encoder.h"
