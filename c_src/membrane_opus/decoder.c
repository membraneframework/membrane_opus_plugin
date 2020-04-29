#include "decoder.h"

// Based on https://opus-codec.org/docs/opus_api-1.1.3/

UNIFEX_TERM create(UnifexEnv *env, int sample_rate, int channels) {
  State *state = unifex_alloc_state(env);
  int error = 0;
  state->decoder = opus_decoder_create(sample_rate, channels, &error);
  state->channels = channels;
  state->sample_rate = sample_rate;

  if (error != OPUS_OK) {
    unifex_release_state(env, state);
    return create_result_error(env, (char *)opus_strerror(error));
  }

  UNIFEX_TERM res = create_result_ok(env, state);
  return res;
}

UNIFEX_TERM decode_packet(UnifexEnv *env, UnifexNifState *state,
                          UnifexPayload *in_payload) {
  char *error = NULL;

  int samples_per_channel = opus_packet_get_nb_samples(
      in_payload->data, in_payload->size, state->sample_rate);
  if (samples_per_channel < 0) {
    error = (char *)opus_strerror(samples_per_channel);
    goto decode_packet_error;
  }

  int channels = opus_packet_get_nb_channels(in_payload->data);
  if (channels < 0) {
    error = (char *)opus_strerror(channels);
    goto decode_packet_error;
  }
  if (channels != state->channels) {
    error = "invalid_number_of_channels";
    goto decode_packet_error;
  }

  unsigned output_size =
      samples_per_channel * state->channels * sizeof(opus_int16);
  UnifexPayload *out_payload =
      unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, output_size);

  int decoded_samples_per_channel =
      opus_decode(state->decoder, in_payload->data, in_payload->size,
                  (opus_int16 *)out_payload->data, out_payload->size, 0);
  if (decoded_samples_per_channel < 0) {
    error = (char *)opus_strerror(decoded_samples_per_channel);
    goto decode_packet_error;
  }
  if (decoded_samples_per_channel * state->channels * sizeof(opus_int16) !=
      output_size) {
    error = "invalid_decoded_output_size";
    goto decode_packet_error;
  }

  return decode_packet_result_ok(env, out_payload);
decode_packet_error:
  return decode_packet_result_error(env, error);
}

UNIFEX_TERM destroy(UnifexEnv *env, UnifexNifState *state) {
  opus_decoder_destroy(state->decoder);

  unifex_release_state(env, state);
  return destroy_result(env);
}

void handle_destroy_state(UnifexEnv *env, UnifexNifState *state) {
  UNIFEX_UNUSED(env);
  free(state->decoder);
}
