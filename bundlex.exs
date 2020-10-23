defmodule Membrane.Opus.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives(Bundlex.platform())
    ]
  end

  def natives(_platform) do
    [
      decoder: [
        deps: [membrane_common_c: :membrane, unifex: :unifex],
        sources: ["decoder.c"],
        libs: ["opus"],
        interface: :nif,
        preprocessor: Unifex
      ],
      encoder: [
        deps: [membrane_common_c: :membrane, unifex: :unifex],
        sources: ["encoder.c"],
        libs: ["opus"],
        interface: :nif,
        preprocessor: Unifex
      ]
    ]
  end
end
