defmodule Membrane.Element.Opus.Mixfile do
  use Mix.Project

  def project do
    [app: :membrane_element_opus,
     compilers: ["membrane.compile.c"] ++ Mix.compilers,
     version: "0.0.1",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     description: "Membrane Multimedia Framework (Opus Element)",
     maintainers: ["Marcin Lewandowski"],
     licenses: ["LGPL"],
     name: "Membrane Element: Opus",
     source_url: "https://bitbucket.org/radiokit/membrane-element-opus",
     preferred_cli_env: [espec: :test],
     deps: deps]
  end


  def application do
    [applications: [
      :membrane_core
    ], mod: {Membrane.Element.Opus, []}]
  end


  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib",]


  defp deps do
    [
      {:membrane_core, git: "git@bitbucket.org:radiokit/membrane-core.git"},
      {:membrane_common_c, git: "git@bitbucket.org:radiokit/membrane-common-c.git"},
    ]
  end
end
