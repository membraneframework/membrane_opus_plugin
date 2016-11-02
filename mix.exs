defmodule Mix.Tasks.Compile.Native do
  def run(_args) do
    {result, _errcode} = System.cmd("make", [], stderr_to_stdout: true)
    IO.binwrite(result)
  end
end


defmodule Membrane.Element.Opus.Mixfile do
  use Mix.Project

  def project do
    [app: :membrane_element_opus,
     compilers: [:native] ++ Mix.compilers,
     version: "0.0.1",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     description: "Membrane Multimedia Framework (Opus Element)",
     maintainers: ["Marcin Lewandowski"],
     licenses: ["LGPL"],
     name: "Membrane Element: Opus",
     source_url: "https://github.com/radiokit/membrane-element-opus",
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
      {:membrane_core, path: "/Users/mspanc/aktivitis/radiokit/membrane-core"}
    ]
  end
end
