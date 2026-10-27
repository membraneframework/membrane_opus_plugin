#pragma once

#include <opus/opus.h>
#include <unifex/unifex.h>

typedef struct State State;

struct State {
  struct OpusEncoder *encoder;
  unsigned char *buffer;
  int channels;
};

#include "_generated/encoder.h"
