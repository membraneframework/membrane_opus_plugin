defmodule Membrane.Opus.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives(Bundlex.get_target())
    ]
  end

  def natives(_platform) do
    [
      decoder: [
        sources: ["decoder.c"],
        os_deps: [
          opus: [
            {:precompiled,
             Membrane.PrecompiledDependencyProvider.get_dependency_url(:opus, version: "1.5.2")},
            :pkg_config
          ]
        ],
        interface: :nif,
        preprocessor: Unifex
      ],
      encoder: [
        deps: [membrane_common_c: :membrane],
        sources: ["encoder.c"],
        os_deps: [
          opus: [
            {:precompiled,
             Membrane.PrecompiledDependencyProvider.get_dependency_url(:opus, version: "1.5.2")},
            :pkg_config
          ]
        ],
        interface: :nif,
        preprocessor: Unifex
      ]
    ]
  end
end
