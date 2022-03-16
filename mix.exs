defmodule Membrane.Opus.Plugin.Mixfile do
  use Mix.Project

  @version "0.11.0"
  @github_url "https://github.com/membraneframework/membrane_opus_plugin"

  def project do
    [
      app: :membrane_opus_plugin,
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Membrane Opus encoder and decoder",
      package: package(),

      # docs
      name: "Membrane Opus plugin",
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
      {:bunch, "~> 1.3"},
      {:membrane_core, "~> 0.9.0"},
      {:membrane_opus_format, "~> 0.3.0"},
      {:membrane_raw_audio_format, "~> 0.8.0"},
      {:unifex, "~> 0.7.0"},
      {:membrane_common_c, "~> 0.11.0"},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:membrane_file_plugin, "~> 0.9.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      },
      files: ["lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs", "bundlex.exs", "c_src"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.Opus]
    ]
  end
end
