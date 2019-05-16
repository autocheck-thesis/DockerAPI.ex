defmodule DockerAPI.Request do
  @moduledoc false
  @default_headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]

  def get(client, path, headers \\ @default_headers), do: request(client, :get, path, "", headers)

  def delete(client, path, headers \\ @default_headers),
    do: request(client, :delete, path, "", headers)

  def post(client, path, body \\ "{}", headers \\ @default_headers),
    do: request(client, :post, path, body, headers)

  def request(client, method, path, body \\ "", headers \\ @default_headers, options \\ []) do
    url = client.server <> path

    options =
      Keyword.merge(options,
        hackney: [ssl_options: client.ssl_options]
      )

    {:ok, raw_reply} = HTTPoison.request(method, url, body, headers, options)
    # IO.inspect(raw_reply)
    raw_reply |> body_parser
  end

  def stream_request(client, method, path, body \\ "", headers \\ @default_headers, options \\ []) do
    url = client.server <> path

    options =
      Keyword.merge(options,
        hackney: [ssl_options: client.ssl_options],
        recv_timeout: 60_000,
        stream_to: self(),
        async: :once
      )

    Stream.resource(
      fn -> HTTPoison.request!(method, url, body, headers, options) end,
      fn
        %HTTPoison.AsyncResponse{} = resp ->
          handle_async_resp(resp, true)

        # last accumulator when emitting :end
        {:end, resp} ->
          {:halt, resp}
      end,
      fn %HTTPoison.AsyncResponse{id: id} ->
        :hackney.stop_async(id)
      end
    )
  end

  defp handle_async_resp(%HTTPoison.AsyncResponse{id: id} = resp, emit_end) do
    receive do
      %HTTPoison.AsyncStatus{id: ^id, code: _code} ->
        # IO.inspect(code, label: "STATUS: ")
        HTTPoison.stream_next(resp)
        {[], resp}

      %HTTPoison.AsyncHeaders{id: ^id, headers: _headers} ->
        # IO.inspect(headers, label: "HEADERS: ")
        HTTPoison.stream_next(resp)
        {[], resp}

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        HTTPoison.stream_next(resp)
        # :erlang.garbage_collect()
        {[chunk], resp}

      %HTTPoison.AsyncEnd{id: ^id} ->
        if emit_end do
          {[:end], {:end, resp}}
        else
          {:halt, resp}
        end
    after
      5_000 -> raise "receive timeout"
    end
  end

  defp body_parser(%HTTPoison.Response{body: "", status_code: status_code})
       when status_code < 400,
       do: :ok

  defp body_parser(%HTTPoison.Response{
         headers: headers,
         body: body,
         status_code: status_code,
         request: request
       })
       when status_code >= 400 do
    message =
      case try_parse_json(body, headers) do
        %{"message" => message} -> message
        message -> message
      end

    raise DockerAPI.RequestError, message: message, request: request
  end

  defp body_parser(%HTTPoison.Response{headers: headers, body: body}) do
    try_parse_json(body, headers)
  end

  defp try_parse_json(body, headers) do
    if {"Content-Type", "application/json"} in headers do
      Poison.decode!(body)
    else
      IO.inspect("Body was not json")
      body
    end
  end
end
