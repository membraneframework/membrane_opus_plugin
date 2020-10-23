#pragma once

#define MEMBRANE_LOG_TAG "Membrane.Opus.EncoderNative"
#include <membrane/log.h>
#include <opus/opus.h>
#include <unifex/unifex.h>

typedef struct State State;

struct State {
  struct OpusEncoder *encoder;
  unsigned char *buffer;
};

#include "_generated/encoder.h"
