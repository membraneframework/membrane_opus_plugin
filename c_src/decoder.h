/**
 * Membrane Element: Opus - Erlang native interface for libopus-based decoder
 *
 * All Rights Reserved, (c) 2016 Marcin Lewandowski
 */

#ifndef __OPUS_DECODER_H__
#define __OPUS_DECODER_H__

#include <stdio.h>
#include <string.h>
#include <erl_nif.h>
#include <opus/opus.h>
#include <membrane/membrane.h>
#include "util.h"


#define MEMBRANE_LOG_TAG "Membrane.Element.Opus.DecoderNative"
#define OPUS_FRAME_MAX_DURATION 120
#define BYTES_PER_OUTPUT_SAMPLE 2

typedef struct _DecoderHandle DecoderHandle;

struct _DecoderHandle
{
  int                   channels;
  size_t                sample_rate;
  OpusDecoder           *decoder;
};

#endif
