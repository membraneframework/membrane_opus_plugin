defmodule Membrane.Element.Opus.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane-element-opus"

  def project do
    [
      app: :membrane_element_opus,
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Opus Element for Membrane Multimedia Framework",
      package: package(),

      # docs
      name: "Membrane Element: Opus",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org",
      docs: docs()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:membrane_core, "~> 0.5.0"},
      {:membrane_element_ffmpeg_swresample, "~> 0.3.0"},
      {:membrane_element_portaudio, "~> 0.3.0"},
      {:membrane_common_c, "~> 0.3.0"},
      {:membrane_caps_rtp, "~> 0.1"},
      {:membrane_caps_audio_raw, "~> 0.2"},
      {:membrane_caps_audio_opus, github: "membraneframework/membrane-caps-audio-opus"},
      {:bunch, "~> 1.2"},
      {:unifex, "~> 0.2.3"},
      {:dialyxir, "~> 1.0.0-rc.7", only: :dev, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.Element.Opus]
    ]
  end
end
