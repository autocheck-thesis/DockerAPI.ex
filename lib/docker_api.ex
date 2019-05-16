defmodule DockerAPI do
  @moduledoc """
  ```elixir
  client = DockerAPI.connect()

  DockerAPI.Images.create("busybox", "latest", client)

  container = %{"Image": "busybox:latest", "Cmd": ["/bin/sleep", "360"]}
  DockerAPI.Containers.create("busy1", container, client) |> DockerAPI.Containers.start(client)
  DockerAPI.Containers.create("busy2", container, client) |> DockerAPI.Containers.start(client)

  DockerAPI.Containers.list(client) |> Enum.map()(&(DockerAPI.Containers.inspect(&1, client)))

  ["busy1", "busy2"] |> Enum.map()(fn(container_name) ->
    DockerAPI.Containers.stop(container_name, client)
    DockerAPI.Containers.remove(container_name, client)
  end)
  ```
  """

  defmodule Client do
    # @moduledoc false
    defstruct ssl_options: [], server: "https://127.0.0.1:2376"
    @type t :: %__MODULE__{server: String.t(), ssl_options: keyword()}
  end

  defmodule RequestError do
    defexception [:message, :request]
  end

  @doc """
  Creates a new connection.

  Tries to guess based on the DOCKER_HOST, DOCKER_TLS_VERIFY and DOCKER_CERT_PATH environment variables.
  """
  @spec connect() :: Client.t()
  def connect do
    host_env = System.get_env("DOCKER_HOST")

    case System.get_env("DOCKER_TLS_VERIFY") do
      "1" ->
        cert_path_env = System.get_env("DOCKER_CERT_PATH")

        %Client{
          server: uri_to_string(URI.parse(host_env)),
          ssl_options: [
            certfile: to_char_list(cert_path_env <> "/cert.pem"),
            keyfile: to_char_list(cert_path_env <> "/key.pem")
          ]
        }

      _ ->
        %Client{server: uri_to_string(URI.parse(host_env), false)}
    end
  end

  @doc """
  Creates a new connection.
  """
  @spec connect(String.t()) :: Client.t()
  def connect(server) do
    %Client{server: server, ssl_options: []}
  end

  @doc """
  Creates a new SSL connection.
  """
  @spec connect(String.t(), String.t(), String.t()) :: Client.t()
  def connect(server, certfile_path, keyfile_path) do
    %Client{
      server: server,
      ssl_options: [
        certfile: certfile_path,
        keyfile: keyfile_path
      ]
    }
  end

  defp uri_to_string(uri, ssl_enabled \\ true) do
    if ssl_enabled == true do
      uri = %{uri | scheme: "https"}
    else
      uri = %{uri | scheme: "http"}
    end

    "#{uri.scheme}://#{uri.host}:#{uri.port}"
  end
end
