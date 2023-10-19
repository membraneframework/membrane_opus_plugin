defmodule Membrane.Opus.Plugin.Mixfile do
  use Mix.Project

  @version "0.18.1"
  @github_url "https://github.com/membraneframework/membrane_opus_plugin"

  def project do
    [
      app: :membrane_opus_plugin,
      version: @version,
      elixir: "~> 1.13",
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # hex
      description: "Membrane Opus encoder and decoder",
      package: package(),

      # docs
      name: "Membrane Opus plugin",
      source_url: @github_url,
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
      {:membrane_core, "~> 0.12.3"},
      {:membrane_opus_format, "~> 0.3.0"},
      {:membrane_raw_audio_format, "~> 0.11.0"},
      {:unifex, "~> 1.0"},
      {:membrane_common_c, "~> 0.15.0"},
      {:bundlex, "~> 1.2"},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:membrane_file_plugin, "~> 0.13.0", only: :test},
      {:membrane_raw_audio_parser_plugin, "~> 0.3.0", only: :test}
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling]
    ]

    if System.get_env("CI") == "true" do
      # Store PLTs in cacheable directory for CI
      [plt_local_path: "priv/plts", plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membrane.stream"
      },
      files: ["lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs", "bundlex.exs", "c_src"],
      exclude_patterns: [~r"c_src/.*/_generated.*"]
    ]
  end

  defp docs do
    [
      main: "readme",
      formatters: ["html"],
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.Opus]
    ]
  end
end
