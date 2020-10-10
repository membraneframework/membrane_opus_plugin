#include "encoder.h"

// Based on https://opus-codec.org/docs/opus_api-1.1.3/

UNIFEX_TERM create(UnifexEnv *env, int input_rate, int channels, int application) {
  State *state = unifex_alloc_state(env);
  int error = 0;
  state->encoder = opus_encoder_create(input_rate, channels, application, &error);
  state->channels = channels;
  state->input_rate = input_rate;

  if (error != OPUS_OK) {
    unifex_release_state(env, state);
    return unifex_raise(env, (char *)opus_strerror(error));
  }

  UNIFEX_TERM res = create_result(env, state);
  return res;
}

UNIFEX_TERM encode_packet(UnifexEnv *env, UnifexNifState *state,
                          UnifexPayload *in_payload) {
  char *error = NULL;

  unsigned output_size = state->channels * sizeof(opus_int16);
  UnifexPayload *out_payload =
      unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, output_size);

  int encoded_samples_per_channel =
      opus_encode(state->encoder, (opus_int16 *)in_payload->data, in_payload->size,
                  out_payload->data, out_payload->size);
  if (encoded_samples_per_channel < 0) {
    error = (char *)opus_strerror(encoded_samples_per_channel);
    goto encode_packet_error;
  }

  return encode_packet_result(env, out_payload);
encode_packet_error:
  return unifex_raise(env, error);
}

UNIFEX_TERM destroy(UnifexEnv *env, UnifexNifState *state) {
  opus_encoder_destroy(state->encoder);

  unifex_release_state(env, state);
  return destroy_result(env);
}

void handle_destroy_state(UnifexEnv *env, UnifexNifState *state) {
  UNIFEX_UNUSED(env);
  free(state->encoder);
}
