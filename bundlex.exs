defmodule Membrane.Element.Opus.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      nifs: nifs(Bundlex.platform())
    ]
  end

  def nifs(_platform) do
    [
      decoder: [
        deps: [membrane_common_c: :membrane, unifex: :unifex],
        sources: [
          "_generated/decoder.c",
          "decoder.c"
        ],
        libs: ["opus"]
      ],
      encoder: [
        deps: [membrane_common_c: :membrane, unifex: :unifex],
        sources: [
          "_generated/encoder.c",
          "encoder.c"
        ],
        libs: ["opus"]
      ]
    ]
  end
end
