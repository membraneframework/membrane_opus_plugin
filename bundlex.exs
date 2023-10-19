defmodule Membrane.Opus.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives(Bundlex.platform())
    ]
  end

  defp get_opus_url() do
    url_prefix =
      "https://github.com/membraneframework-precompiled/precompiled_opus/releases/latest/download/opus"

    case Bundlex.get_target() do
      %{os: "linux"} ->
        {:precompiled, "#{url_prefix}_linux.tar.gz"}

      %{architecture: "x86_64", os: "darwin" <> _rest_of_os_name} ->
        {:precompiled, "#{url_prefix}_macos_intel.tar.gz"}

      %{architecture: "aarch64", os: "darwin" <> _rest_of_os_name} ->
        {:precompiled, "#{url_prefix}_macos_arm.tar.gz"}

      _other ->
        nil
    end
  end

  def natives(_platform) do
    [
      decoder: [
        sources: ["decoder.c"],
        interface: :nif,
        preprocessor: Unifex,
        os_deps: [{provider(), "opus"}]
      ],
      encoder: [
        deps: [membrane_common_c: :membrane],
        sources: ["encoder.c"],
        interface: :nif,
        preprocessor: Unifex,
        os_deps: [{provider(), "opus"}]
      ]
    ]
  end

  defp provider() do
    Application.get_env(:membrane_opus_plugin, :use_local_natives)
    |> case do
      nil -> [get_opus_url(), :pkg_config]
      true -> :pkg_config
    end
  end
end
