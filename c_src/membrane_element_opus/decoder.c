#include "decoder.h"

UNIFEX_TERM create(UnifexEnv *env, int sample_rate, int channels)
{
  State *state = unifex_alloc_state(env);
  int error = 0;
  state->decoder = opus_decoder_create(sample_rate, channels, &error);
  state->channels = channels;
  state->sample_rate = sample_rate;

  if (error != OPUS_OK)
  {
    unifex_release_state(env, state);
    return create_result_error(env, (char *)opus_strerror(error));
  }

  UNIFEX_TERM res = create_result_ok(env, state);
  return res;
}

UNIFEX_TERM destroy(UnifexEnv *env, UnifexNifState *state)
{
  opus_decoder_destroy(state->decoder);

  unifex_release_state(env, state);
  return destroy_result(env);
}

UNIFEX_TERM decode_packet(UnifexEnv *env, UnifexNifState *state,
                          UnifexPayload *payload, int use_fec, int duration)
{
  int packet_size = duration * state->sample_rate / 1000;
  int use_plc = (payload->size == 0);

  opus_int32 output = packet_size * state->channels * sizeof(opus_int16);

  opus_int16 *tmp = unifex_alloc(output);
  int result = opus_decode(state->decoder, use_plc ? NULL : payload->data,
                           payload->size, tmp, packet_size, use_fec);

  UnifexPayload *result_payload =
      unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, result * 2 * 2);

  result_payload->size = result;
  memcpy(result_payload->data, tmp, output);

  if (result < 0)
    return decode_packet_result_error(env, (char *)opus_strerror(result));

  return decode_packet_result_ok(env, result_payload);
}

UNIFEX_TERM get_last_packet_duration(UnifexEnv *env, UnifexNifState *state)
{
  opus_int32 result = 0;
  opus_decoder_ctl(state->decoder, OPUS_GET_LAST_PACKET_DURATION(&result));
  // result is now the number of samples of last packet
  int result_ms = 1000 * result / state->sample_rate;

  return get_last_packet_duration_result(env, result_ms);
}

void handle_destroy_state(UnifexEnv *env, UnifexNifState *state)
{
  UNIFEX_UNUSED(env);
  free(state->decoder);
}
