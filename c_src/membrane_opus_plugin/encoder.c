#include "encoder.h"
#include <unistd.h>

// Based on https://opus-codec.org/docs/opus_api-1.3.1

#define MAX_PACKET 1500

static char *get_error(int err_code) {
  switch (err_code) {
    case OPUS_BAD_ARG:
      return "Bad argument";
    case OPUS_BUFFER_TOO_SMALL:
      return "Not enough bytes allocated in the buffer";
    case OPUS_INTERNAL_ERROR:
      return "An internal error was detected";
    case OPUS_UNIMPLEMENTED:
      return "Invalid/unsupported request number";
    case OPUS_INVALID_STATE:
      return "Encoder structure is invalid or already freed";
    case OPUS_ALLOC_FAIL:
      return "Memory allocation has failed";
    default:
      return "Unknown error";
  }
}

UNIFEX_TERM create(UnifexEnv *env, int input_rate, int channels, int application) {
  State *state = unifex_alloc_state(env);
  state->buffer = calloc(MAX_PACKET, sizeof(unsigned char));

  int error = 0;
  state->encoder = opus_encoder_create(input_rate, channels, application, &error);
  if (error != OPUS_OK) {
    unifex_release_state(env, state);
    return unifex_raise(env, (char *)opus_strerror(error));
  }

  UNIFEX_TERM res = create_result(env, state);
  unifex_release_state(env, state);
  return res;
}

UNIFEX_TERM encode_packet(UnifexEnv *env, State *state,
                          UnifexPayload *in_payload, int frame_size) {
  int encoded_size_or_error = opus_encode(
    state->encoder, (opus_int16 *)in_payload->data,
    frame_size, state->buffer, MAX_PACKET
  );

  if (encoded_size_or_error < 0) {
    return encode_packet_result_error(env, get_error(encoded_size_or_error));
  }

  UnifexPayload out_payload;
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, encoded_size_or_error, &out_payload);
  memcpy(out_payload.data, state->buffer, encoded_size_or_error);

  UNIFEX_TERM res = encode_packet_result_ok(env, &out_payload);
  unifex_payload_release(&out_payload);
  return res;
}

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);
  if (state->encoder != NULL) {
    opus_encoder_destroy(state->encoder);
  }
  if (state->buffer != NULL) {
    free(state->buffer);
  }
}
