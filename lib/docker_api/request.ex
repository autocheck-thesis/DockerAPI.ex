defmodule DockerAPI.Request do
  @moduledoc false
  @default_headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]

  def get(client, path, headers \\ []), do: request(client, :get, path, "", headers)
  def delete(client, path, headers \\ []), do: request(client, :delete, path, "", headers)
  def post(client, path, body \\ "{}", headers \\ []), do: request(client, :post, path, body, headers)

  def request(client, method, path, body \\ "", headers \\ @default_headers, options \\ []) do
    url = client.server<>"/v1.19"<>path
    options = Keyword.merge(options, [:hackney, [ssl_options: client.ssl_options]])
    {:ok, raw_reply} = HTTPoison.request(method, url, body, headers, options)
    raw_reply |> body_parser
  end

  def stream_request(client, method, path, body \\ "", headers \\ @default_headers, options \\ []) do
    url = client.server<>"/v1.19"<>path
    task = Task.async(fn ->
      options = Keyword.merge(options, [
        hackney: [ssl_options: client.ssl_options],
        recv_timeout: 60_000,
        stream_to: self
      ])
      {:ok, %HTTPoison.AsyncResponse{}} = HTTPoison.request(method, url, body, headers, options)
      stream_loop(nil, [])
    end)
    Task.await(task, :infinity)
  end

  def stream_loop(status, acc) do
    receive do
      %HTTPoison.AsyncStatus{code: new_status} ->
        stream_loop(new_status, acc)
      %HTTPoison.AsyncHeaders{} ->
        stream_loop(status, acc)
      %HTTPoison.AsyncChunk{chunk: chunk} ->
        stream_loop(status, [Poison.decode!(chunk)|acc])
      %HTTPoison.AsyncEnd{} ->
        {status, Enum.reverse(acc)}
      %HTTPoison.Error{reason: reason} ->
        {:error, reason}
    after
      30_000 ->
        {:error, :timeout}
    end
  end


  def body_parser(%{body: "", status: status_code}) when status_code < 400, do: :ok
  def body_parser(%{body: body, status: status_code}) when status_code >= 400 do
    raise DockerAPI.RequestError, message: body
  end
  def body_parser(%{headers: headers, body: body}) do
    if {"Content-Type", "application/json"} in headers do
      Poison.decode!(body)
    else
      nil
    end
  end

end
