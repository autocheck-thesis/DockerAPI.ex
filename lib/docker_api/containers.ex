defmodule DockerAPI.Containers do
  alias DockerAPI.Request, as: R

  @doc """
  List all containers

  See [API Docs](https://docs.docker.com/reference/api/docker_remote_api_v1.20/#list-containers) for
  information on the body.
  """
  @spec list(DockerAPI.Client.t()) :: List.t()
  def list(client) do
    R.get(client, "/containers/json?all=true")
  end

  @doc """
  Create and start a container with a randomly generated name

  See [API Docs](https://docs.docker.com/reference/api/docker_remote_api_v1.20/#create-a-container) for
  map() keys.
  """
  @spec run(map(), DockerAPI.Client.t()) :: map()
  def run(container, client) do
    result = create(container, client)
    start(result, client)
    DockerAPI.Containers.inspect(result, client)
  end

  @doc """
  Create and start a container with a specific name.

  See [API Docs](https://docs.docker.com/reference/api/docker_remote_api_v1.20/#create-a-container) for
  map() keys.
  """
  @spec run(String.t(), map(), DockerAPI.Client.t()) :: map()
  def run(name, container, client) do
    result = create(name, container, client)
    start(result, client)
    DockerAPI.Containers.inspect(result, client)
  end

  @doc """
  Create a container with a randomly generated name

  See [API Docs](https://docs.docker.com/reference/api/docker_remote_api_v1.20/#create-a-container) for
  map() keys.
  """
  @spec create(map(), DockerAPI.Client.t()) :: map()
  def create(container, client) do
    R.post(client, "/containers/create", Poison.encode!(container))
  end

  @doc """
  Create a container with a specific name.

  See [API Docs](https://docs.docker.com/reference/api/docker_remote_api_v1.20/#create-a-container) for
  map() keys.
  """
  @spec create(String.t(), map(), DockerAPI.Client.t()) :: map()
  def create(name, container, client) do
    R.post(client, "/containers/create?name=" <> name, Poison.encode!(container))
  end

  @doc """
  Inspects a specific container

  Return low-level information on the container.

  See [API Docs](https://docs.docker.com/reference/api/docker_remote_api_v1.20/#inspect-a-container) for
  information on the body.
  """
  @spec inspect(String.t() | map(), DockerAPI.Client.t()) :: map()
  def inspect(container, client) when is_map(container),
    do: DockerAPI.Containers.inspect(container["Id"], client)

  def inspect(container, client) do
    R.get(client, "/containers/#{container}/json")
  end

  @doc """
  List processes running inside the container

  See [API Docs](https://docs.docker.com/reference/api/docker_remote_api_v1.20/#create-a-container) for
  information on the body.
  """
  @spec top(String.t() | map(), DockerAPI.Client.t()) :: map()
  def top(container, client) when is_map(container), do: top(container["Id"], client)

  def top(container, client) do
    R.get(client, "/containers/#{container}/top")
  end

  @spec logs(String.t() | map(), DockerAPI.Client.t()) :: Enumerable.t()
  def logs(container, client) when is_map(container), do: logs(container["Id"], client)

  def logs(container, client) do
    query_params = %{stderr: true, stdout: true, follow: true, timestamp: false}
    url = "/containers/#{container}/logs?" <> URI.encode_query(query_params)
    R.stream_request(client, :get, url)
  end

  @spec attach(String.t() | map(), DockerAPI.Client.t()) :: Enumerable.t()
  def attach(container, client) when is_map(container), do: attach(container["Id"], client)

  def attach(container, client) do
    query_params = %{stream: true, stdout: true, stderr: true}
    url = "/containers/#{container}/attach?" <> URI.encode_query(query_params)
    R.stream_request(client, :post, url)
  end

  # def changes(_client), do: throw :not_implemented_yet
  # def export(_client), do: throw :not_implemented_yet
  # def stats(_client), do: throw :not_implemented_yet
  # def resize(_client), do: throw :not_implemented_yet

  @doc """
  Start a container in a stopped state
  """
  @spec start(String.t() | map(), DockerAPI.Client.t()) :: map()
  def start(container, client) when is_map(container), do: start(container["Id"], client)

  def start(container, client) do
    R.post(client, "/containers/#{container}/start")
  end

  @doc """
  stop a container in a running state
  """
  @spec stop(String.t() | map(), DockerAPI.Client.t()) :: map()
  def stop(container, client) when is_map(container), do: stop(container["Id"], client)

  def stop(container, client) do
    R.post(client, "/containers/#{container}/stop")
  end

  @doc """
  Restart a running container
  """
  @spec restart(String.t() | map(), DockerAPI.Client.t()) :: map()
  def restart(container, client) when is_map(container), do: restart(container["Id"], client)

  def restart(container, client) do
    R.post(client, "/containers/#{container}/restart")
  end

  @doc """
  Kill a running container
  """
  @spec kill(String.t() | map(), DockerAPI.Client.t()) :: map()
  def kill(container, client) when is_map(container), do: kill(container["Id"], client)

  def kill(container, client) do
    R.post(client, "/containers/#{container}/kill")
  end

  @doc """
  Rename the container id to a new_name
  """
  @spec rename(String.t() | map(), String.t(), DockerAPI.Client.t()) :: map()
  def rename(container, new_name, client) when is_map(container),
    do: rename(container["Id"], new_name, client)

  def rename(container, new_name, client) do
    R.post(client, "/containers/#{container}/rename?name=" <> new_name)
  end

  @doc """
  Pause the container
  """
  @spec pause(String.t() | map(), DockerAPI.Client.t()) :: map()
  def pause(container, client) when is_map(container), do: pause(container["Id"], client)

  def pause(container, client) do
    R.post(client, "/containers/#{container}/pause")
  end

  @doc """
  Unpause the container
  """
  @spec unpause(String.t() | map(), DockerAPI.Client.t()) :: map()
  def unpause(container, client) when is_map(container), do: unpause(container["Id"], client)

  def unpause(container, client) do
    R.post(client, "/containers/#{container}/unpause")
  end

  # def attach_ws(_client), do: throw :not_implemented_yet
  # def wait(_client), do: throw :not_implemented_yet

  @doc """
  Remove the container id from the filesystem

  Optionally force kill the  container if it is running
  """
  @spec remove(String.t() | map(), boolean(), DockerAPI.Client.t()) :: map()
  def remove(container, force \\ false, client)

  def remove(container, force, client) when is_map(container),
    do: remove(container["Id"], force, client)

  def remove(container, force, client) do
    R.delete(client, "/containers/#{container}?force=#{force}")
  end

  # def archive(_client), do: throw :not_implemented_yet
end
