defmodule DockerAPI.Request do
  @moduledoc false
  @default_headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]

  @timeout 3600_000

  alias DockerAPI.Client

  @spec get(Client.t(), binary(), List.t()) :: any | no_return()
  def get(client, path, headers \\ @default_headers), do: request(client, :get, path, "", headers)

  @spec delete(Client.t(), binary(), List.t()) :: any | no_return()
  def delete(client, path, headers \\ @default_headers),
    do: request(client, :delete, path, "", headers)

  @spec post(Client.t(), binary(), binary(), List.t()) :: any | no_return()
  def post(client, path, body \\ "{}", headers \\ @default_headers),
    do: request(client, :post, path, body, headers)

  @spec request(Client.t(), atom(), binary(), binary(), List.t(), List.t()) :: any | no_return()
  def request(client, method, path, body \\ "", headers \\ @default_headers, options \\ []) do
    url = client.server <> path

    options =
      Keyword.merge(options,
        hackney: [ssl_options: client.ssl_options],
        recv_timeout: @timeout
      )

    raw_reply = HTTPoison.request!(method, url, body, headers, options)
    raw_reply |> body_parser
  end

  @spec stream_request(Client.t(), atom(), binary(), binary(), List.t(), List.t()) ::
          Enumerable.t()
  def stream_request(client, method, path, body \\ "", headers \\ @default_headers, options \\ []) do
    url = client.server <> path

    options =
      Keyword.merge(options,
        hackney: [ssl_options: client.ssl_options],
        recv_timeout: @timeout,
        stream_to: self(),
        async: :once
      )

    Stream.resource(
      fn -> HTTPoison.request(method, url, body, headers, options) end,
      fn
        # First response
        {:ok, %HTTPoison.AsyncResponse{} = resp} ->
          handle_async_resp(resp)

        # Succeeding response
        {%HTTPoison.AsyncResponse{} = resp, headers} ->
          handle_async_resp(resp, headers)

        {:end, resp} ->
          {:halt, resp}

        {:error, resp} ->
          {:halt, resp}
      end,
      fn %HTTPoison.AsyncResponse{id: id} ->
        :hackney.stop_async(id)
      end
    )
  end

  @spec handle_async_resp(HTTPoison.AsyncResponse.t(), [any()]) ::
          {[any()], {HTTPoison.AsyncResponse.t(), [any()]}}
          | {[:end], {:end, HTTPoison.AsyncResponse.t()}}
          | {[HTTPoison.Error.t()], {:error, HTTPoison.AsyncResponse.t()}}
          | {[:timeout], {:timeout, HTTPoison.AsyncResponse.t()}}
  defp handle_async_resp(%HTTPoison.AsyncResponse{} = resp, headers \\ []) do
    receive do
      %HTTPoison.AsyncStatus{} ->
        case HTTPoison.stream_next(resp) do
          {:ok, _} -> {[], {resp, headers}}
          {:error, _} = error -> {[error], {:error, resp}}
        end

      %HTTPoison.AsyncHeaders{headers: headers} ->
        case HTTPoison.stream_next(resp) do
          {:ok, _} -> {[], {resp, headers}}
          {:error, _} = error -> {[error], {:error, resp}}
        end

      %HTTPoison.AsyncChunk{chunk: chunk} ->
        case HTTPoison.stream_next(resp) do
          {:ok, _} -> {[decode_body(chunk, headers)], {resp, headers}}
          {:error, _} = error -> {[error], {:error, resp}}
        end

      %HTTPoison.AsyncEnd{} ->
        {[:end], {:end, resp}}
    after
      @timeout -> {[{:error, :timeout}], {:error, resp}}
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
