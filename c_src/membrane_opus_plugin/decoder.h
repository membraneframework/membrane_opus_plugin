#pragma once

#include <opus/opus.h>
#include <unifex/unifex.h>

#include "stdint.h"

typedef struct State State;

struct State {
  int channels;
  size_t sample_rate;
  OpusDecoder *decoder;
};

#include "_generated/decoder.h"
