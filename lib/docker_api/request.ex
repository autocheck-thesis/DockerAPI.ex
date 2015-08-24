defmodule DockerAPI.Request do
  @moduledoc false
  @default_headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]

  def get(client, path), do: request(client, :get, path)
  def delete(client, path), do: request(client, :delete, path)
  def post(client, path, body \\ "{}"), do: request(client, :post, path, body)

  def request(client, method, path, body \\ "", headers \\ @default_headers, options \\ []) do
    url = client.server<>"/v1.19"<>path
    options = Keyword.put(options, :hackney, [ssl_options: client.ssl_options])
    {:ok, raw_reply} = HTTPoison.request(method, url, body, headers, options)
    raw_reply |> body_parser
  end

  def body_parser(%{body: "", status: status_code}) when status_code < 400, do: :ok
  def body_parser(%{body: body, status: status_code}) when status_code >= 400 do
    raise DockerAPI.RequestError, message: body
  end
  def body_parser(%{headers: [{"Content-Type", "application/json"}|_]} = response) do
    try do
      Poison.decode!(response.body)
    rescue
      # TODO - Handle streamed JSON.
      Poison.SyntaxError -> :ok
    end
  end
  def body_parser(_), do: :undefined
end
