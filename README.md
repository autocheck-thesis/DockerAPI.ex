DockerAPI
=========

Add `ex_dockerapi` do your Mix deps.

```elixir
client = DockerAPI.connect()

DockerAPI.Misc.info(client)

DockerAPI.Images.create("busybox", "latest", client)

container = %{"Image": "busybox:latest", "Cmd": ["/bin/sleep", "360"]}
DockerAPI.Containers.create("busy1", container, client) |> DockerAPI.Containers.start()
DockerAPI.Containers.create("busy2", container, client) |> DockerAPI.Containers.start()

DockerAPI.Containers.list(client) |> Enum.map(&(DockerAPI.Containers.inspect(&1, client)))

["busy1", "busy2"] |> Enum.map(fn(container_name) ->
  DockerAPI.Containers.stop(container_name, client)
  DockerAPI.Containers.remove(container_name, client)
end)
```
