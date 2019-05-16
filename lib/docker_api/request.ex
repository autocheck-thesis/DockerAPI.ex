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

    if :ets.whereis(:request_headers) == :undefined do
      :ets.new(:request_headers, [:set, :named_table])
    end

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

      %HTTPoison.AsyncHeaders{id: ^id, headers: headers} ->
        # IO.inspect(headers, label: "HEADERS: ")
        HTTPoison.stream_next(resp)
        :ets.insert(:request_headers, {id, headers})
        {[], resp}

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        HTTPoison.stream_next(resp)
        # :erlang.garbage_collect()
        [{_, headers}] = :ets.lookup(:request_headers, id)
        {[decode_body(chunk, headers)], resp}

      %HTTPoison.AsyncEnd{id: ^id} ->
        if emit_end do
          {[:end], {:end, resp}}
        else
          {:halt, resp}
        end
    after
      60_000 -> raise "receive timeout"
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
      case decode_body(body, headers) do
        %{"message" => message} -> message
        message -> message
      end

    raise DockerAPI.RequestError, message: message, request: request
  end

  defp body_parser(%HTTPoison.Response{headers: headers, body: body}) do
    decode_body(body, headers)
  end

  defp decode_body(body, headers) do
    if {"Content-Type", "application/json"} in headers do
      case Poison.decode(body) do
        {:ok, body} -> body
        body -> body
      end
    else
      case body do
        # The format is a Header and a Payload (frame).
        #
        # The header contains the information which the stream writes (stdout or stderr). It also contains the size of the associated frame encoded in the last four bytes (uint32).
        #
        # It is encoded on the first eight bytes like this:
        #
        # header := [8]byte{STREAM_TYPE, 0, 0, 0, SIZE1, SIZE2, SIZE3, SIZE4}
        # STREAM_TYPE can be:
        #
        # 0: stdin (is written on stdout)
        # 1: stdout
        # 2: stderr
        # SIZE1, SIZE2, SIZE3, SIZE4 are the four bytes of the uint32 size encoded as big endian.
        <<stream_type, 0, 0, 0, _size1, _size2, _size3, _size4>> <> payload ->
          case stream_type do
            2 -> {:stderr, payload}
            _ -> {:stdio, payload}
          end

        body ->
          {:stdio, body}
      end
    end
  end
end
