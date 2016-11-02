#include "erl_nif.h"

static ERL_NIF_TERM world(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return enif_make_string(env, "Hello world!", ERL_NIF_LATIN1);
}

static ErlNifFunc nif_funcs[] =
{
    {"world", 0, world}
};

ERL_NIF_INIT(Elixir.Membrane.Element.Opus.Encoder, nif_funcs, NULL, NULL, NULL, NULL)
