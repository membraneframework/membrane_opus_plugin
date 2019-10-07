#pragma once

#include <membrane/membrane.h>
#define MEMBRANE_LOG_TAG "Membrane.Element.Opus.DecoderNative"
#include <membrane/log.h>
#include "stdint.h"

typedef struct _DecoderState UnifexNifState;
typedef UnifexNifState State;

struct _DecoderState
{
  //TODO
};

#include "_generated/decoder.h"
