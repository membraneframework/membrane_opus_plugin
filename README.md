# Membrane Opus plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_opus_plugin.svg)](https://hex.pm/packages/membrane_opus_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_opus_plugin/)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_opus_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_opus_plugin)

Opus encoder and decoder.

It is a part of [Membrane Multimedia Framework](https://membrane.stream).

## Installation

The package can be installed by adding `membrane_opus_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_opus_plugin, "~> 0.20.6"}
  ]
end
```

This package depends on [libopus](http://opus-codec.org/docs/) library. The precompiled builds will be pulled and linked automatically. However, should there be any problems, consider installing it manually.

### Manual instalation of dependencies

#### Ubuntu
```
sudo apt-get install libopus-dev
```

#### Arch/Manjaro
```
pacman -S opus
```

#### MacOS
```
brew install opus
```

#### MacOS M1/M2 (Apple silicon)

On Apple M1/M2 chips, one needs to export variables:
```
export C_INCLUDE_PATH=$C_INCLUDE_PATH:$(brew --cellar)/opus/1.3.1/include
export LIBRARY_PATH=$LIBRARY_PATH:$(brew --cellar)/opus/1.3.1/lib
```
On different local setups, directory and version names may differ.

## Usage

### Encoder

The pipeline encodes a sample raw file and saves it as an opus file:

```elixir
defmodule Membrane.ReleaseTest.Pipeline do
  use Membrane.Pipeline
  alias Membrane.RawAudio

  @input_filename "/tmp/input.raw"
  @output_filename "/tmp/output.opus"

  @impl true
  def handle_init(_ctx, _options) do
    structure =
      child(:source, %Membrane.File.Source{
        location: @input_filename
      })
      |> child(:encoder, %Membrane.Opus.Encoder{
        application: :audio,
        input_stream_format: %RawAudio{
          channels: 2,
          sample_format: :s16le,
          sample_rate: 48_000
        }
      })
      |> child(:parser, %Membrane.Opus.Parser{delimitation: :delimit})
      |> child(:sink, %Membrane.File.Sink{
        location: @output_filename
      })

    {[spec: structure], %{}}
  end
end
```

Opus audio generally needs to be packaged in an [Ogg container](https://xiph.org/ogg/) in order to be played by a
media player. See `Membrane.Ogg.Payloader` in the [Membrane Ogg Plugin](https://github.com/membraneframework/membrane_ogg_plugin).


### Decoder

The pipeline parses, decodes a sample opus file and then saves it as a raw file:

```elixir
defmodule Membrane.ReleaseTest.Pipeline2 do
  use Membrane.Pipeline

  @input_filename "/tmp/input.raw"
  @output_filename "/tmp/output.opus"

  @impl true
  def handle_init(_ctx, _options) do
    structure =
      child(:source, %Membrane.File.Source{
        location: @input_filename
      })
      |> child(:parser, Membrane.Opus.Parser)
      |> child(:opus, Membrane.Opus.Decoder)
      |> child(:sink, %Membrane.File.Sink{
        location: @output_filename
      })

    {[spec: structure], %{}}
  end
end
```

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_opus_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_opus_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
