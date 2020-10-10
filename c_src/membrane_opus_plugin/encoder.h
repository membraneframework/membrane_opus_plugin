#pragma once

#define MEMBRANE_LOG_TAG "Membrane.Opus.EncoderNative"
#define MAX_FRAME_SIZE 4000
#include <membrane/log.h>
#include <opus/opus.h>

typedef struct _EncoderState UnifexNifState;
typedef UnifexNifState State;

struct _EncoderState {
  struct OpusEncoder *encoder;
};

#include "_generated/encoder.h"
