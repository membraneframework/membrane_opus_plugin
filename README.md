# Membrane Opus plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_opus_plugin.svg)](https://hex.pm/packages/membrane_opus_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_opus_plugin/)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_opus_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_opus_plugin)

Opus encoder and decoder.

It is a part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

The package can be installed by adding `membrane_opus_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
	{:membrane_opus_plugin, "~> 0.15.0"}
  ]
end
```

This package depends on [libopus](http://opus-codec.org/docs/) library.

### Ubuntu
```
sudo apt-get install libopus-dev
```

### Arch/Manjaro
```
pacman -S opus
```

### MacOS
```
brew install opus
```

## Usage example

### Encoder 
Encode sample raw file and save it as an opus file:

```elixir
defmodule Membrane.ReleaseTest.Pipeline do
  use Membrane.Pipeline

  alias Membrane.RawAudio

  @impl true
  def handle_init(_) do
    children = [
      source: %Membrane.File.Source{
        location: "/tmp/input.raw"
      },
      encoder: %Membrane.Opus.Encoder{
        application: :audio,
        input_caps: %RawAudio{
          channels: 2,
          sample_format: :s16le,
          sample_rate: 48_000
        }
      },
      parser: %Membrane.Opus.Parser{delimitation: :delimit},
      sink: %Membrane.File.Sink{
        location: "/tmp/output.opus"
      }
    ]

    links = [
      link(:source)
      |> to(:encoder)
      |> to(:parser)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
```

Opus audio generally needs to be packaged in an [Ogg container](https://xiph.org/ogg/) in order to be played by a
media player. See `Membrane.Ogg.Payloader` in the [Membrane Ogg Plugin](https://github.com/membraneframework/membrane_ogg_plugin).


### Decoder
Decode sample opus file and save it as raw file: 
```elixir
defmodule Membrane.ReleaseTest.Pipeline2 do
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    children = [
      source: %Membrane.File.Source{
        location: "/tmp/input.opus"
      },
      parser: Membrane.Opus.Parser,
      opus: Membrane.Opus.Decoder,
      sink: %Membrane.File.Sink{
        location: "/tmp/output.raw"
      }
    ]

    links = [
      link(:source)
      |> to(:parser)
      |> to(:opus)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
```

For more information please refer to `Membrane.Opus.Encoder`/`Membrane.Opus.Decoder` module documentation or our tests.

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_opus_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_opus_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
