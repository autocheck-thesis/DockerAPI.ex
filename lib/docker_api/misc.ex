defmodule DockerAPI.Misc do
  alias DockerAPI.Request, as: R

  @doc """
  Info on the Docker host
  """
  @spec info(DockerAPI.Client.t) :: Map.t
  def info(client) do
    R.get(client, "/info")
  end

  @doc """
  Version information of the Docker host
  """
  @spec version(DockerAPI.Client.t) :: Map.t
  def version(client) do
    R.get(client, "/version")
  end

  @doc """
  Ping the Docker host
  """
  @spec ping(DockerAPI.Client.t) :: :ok
  def ping(client) do
    nil = R.get(client, "/_ping")
    :ok
  end

  # def build(_client), do: throw :not_implemented_yet
  # def auth(_client), do: throw :not_implemented_yet
  # def commit(_client), do: throw :not_implemented_yet
  # def events(_client), do: throw :not_implemented_yet
  # def get_image(_client, _image \\ :all), do: throw :not_implemented_yet
  # def load(_client), do: throw :not_implemented_yet
  #
  # def exec_create(_client), do: throw :not_implemented_yet
  # def exec_start(_client), do: throw :not_implemented_yet
  # def exec_resize(_client), do: throw :not_implemented_yet

end
